import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/article/article_detail.dart';
import '../../../data/models/article/article_item.dart';
import '../../../data/queries/article_remote_query_provider.dart';
import '../state/article_state.dart';

// ----------------------------------------------------------------------
// Audio Controller（精简版：仅保留核心播放功能）
// ----------------------------------------------------------------------

/// AB 循环每轮之间的停顿时长（毫秒），方便后期调整
const int kLoopPauseMs = 2000;

class ArticleAudioController extends Notifier<ArticleState> {
  late AudioPlayer _audioPlayer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  /// AB 循环间隔停顿的计时器
  Timer? _loopPauseTimer;

  /// 是否正处于循环间隔停顿中（防止 positionStream 重复触发）
  bool _isLoopPausing = false;

  @override
  ArticleState build() {
    _audioPlayer = AudioPlayer();

    ref.onDispose(() {
      logger.info('[ArticleAudio] onDispose: 释放音频资源');
      _cleanup();
    });

    // 初始状态
    return ArticleState(
      article: ArticleDetail(
        id: 'placeholder',
        title: '',
        cleanTitle: '',
        publishedAt: '',
        audioUrl: '',
        durationMs: 0,
        sentenceCount: 0,
        isArchived: false,
        items: [
          ArticleItem(
            text: '',
            translation: '',
            startMs: 0,
            endMs: 1000,
            index: 0,
          ),
        ],
      ),
    );
  }

  /// 页面退出时主动调用：停止播放并释放资源
  void disposeAudio() {
    logger.info('[ArticleAudio] disposeAudio: 页面退出，停止并释放');
    _cleanup();
    ref.invalidateSelf();
  }

  /// 内部清理方法
  void _cleanup() {
    _loopPauseTimer?.cancel();
    _loopPauseTimer = null;
    _isLoopPausing = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _audioPlayer.stop();
    _audioPlayer.dispose();
  }

  /// 初始化特定文章
  Future<void> initArticle(String articleId) async {
    try {
      state = state.copyWith(
        article: ArticleDetail(
          id: articleId,
          title: '',
          cleanTitle: '',
          publishedAt: '',
          audioUrl: '',
          durationMs: 0,
          sentenceCount: 0,
          isArchived: false,
          items: state.article.items,
        ),
      );

      final article = await ref
          .read(articleRemoteQueryProvider)
          .fetchArticleDetail(articleId);

      state = state.copyWith(article: article);

      // 使用带 JWT 认证的远程音频 URL
      final jwt =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final audioUrl =
          '${ApiEndpoints.baseUrl}${ApiEndpoints.replaceParams(ApiEndpoints.audio, {'id': article.id})}';
      await _audioPlayer.setUrl(
        audioUrl,
        headers: {'Authorization': 'Bearer $jwt'},
      );
      logger.info('[ArticleAudio] 音频加载成功: ${article.id}');

      // 监听播放状态
      _playerStateSubscription?.cancel();
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((
        playerState,
      ) {
        state = state.copyWith(isPlaying: playerState.playing);

        // 播放完成，重置到初始状态（abLoop 模式由 positionStream 自行拦截，不在此处干预）
        if (playerState.processingState == ProcessingState.completed &&
            state.currentMode != ArticleMode.abLoop) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
          state = state.copyWith(
            activeIndex: -1,
            currentPositionMs: 0,
            isPlaying: false,
          );
        }
      });

      // 监听进度，执行心跳对齐（高光跟踪）和 AB 循环边界拦截
      _positionSubscription?.cancel();
      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        final positionMs = position.inMilliseconds;
        state = state.copyWith(currentPositionMs: positionMs);

        final items = state.article.items;
        if (items.isEmpty) return;

        // --- 常规匹配：寻找 positionMs 落在哪个句子区间 ---
        final newIndex = _findIndexForPosition(positionMs);
        if (newIndex != -1 && newIndex != state.activeIndex) {
          state = state.copyWith(activeIndex: newIndex);
        }

        // --- AB 循环拦截逻辑 ---
        if (state.currentMode == ArticleMode.abLoop &&
            state.loopStartIdx != null &&
            state.loopEndIdx != null &&
            !_isLoopPausing) {
          final loopEndMs = items[state.loopEndIdx!].endMs;

          // 如果进度已到达或超过 B 句的结束时间
          if (positionMs >= loopEndMs) {
            final nextCount = state.currentLoopCount + 1;

            if (nextCount > state.targetLoopCount) {
              // 达到目标次数：停止循环（先封锁 positionStream 防止竞态）
              _isLoopPausing = true;
              _audioPlayer.pause();
              _audioPlayer.seek(
                Duration(milliseconds: items[state.loopStartIdx!].startMs),
              );
              // 复位为 1/N，表示已完成并就绪，再次点播放即从第 1 轮开始
              // （完成态由 _isLoopPausing==true 且 _loopPauseTimer==null 标识，与计数无关）
              state = state.copyWith(currentLoopCount: 1, isPlaying: false);
            } else {
              // 未达到目标次数：先暂停，等待间隔后再跳回 A 句开头继续播
              _audioPlayer.pause();
              state = state.copyWith(
                currentLoopCount: nextCount,
                isPlaying: false,
              );
              _isLoopPausing = true;
              _loopPauseTimer?.cancel();
              _loopPauseTimer = Timer(Duration(milliseconds: kLoopPauseMs), () {
                _loopPauseTimer = null; // 自清零，用于区分「定时器仍挂起」与「循环已完成」
                _isLoopPausing = false;
                // 再次检查是否仍然处于 abLoop 模式（用户可能在等待期间切换了模式）
                if (state.currentMode == ArticleMode.abLoop &&
                    state.loopStartIdx != null) {
                  _audioPlayer.seek(
                    Duration(
                      milliseconds:
                          state.article.items[state.loopStartIdx!].startMs,
                    ),
                  );
                  _audioPlayer.play();
                }
              });
            }
          }
        }
      });
    } catch (e, st) {
      logger.error('[ArticleAudio] 初始化失败', e, st);
      state = state.copyWith(
        article: ArticleDetail(
          id: 'error',
          title: '',
          cleanTitle: '',
          publishedAt: '',
          audioUrl: '',
          durationMs: 0,
          sentenceCount: 0,
          isArchived: false,
          items: [
            ArticleItem(
              text: '$e',
              translation: '',
              startMs: 0,
              endMs: 9999,
              index: 0,
            ),
          ],
        ),
      );
    }
  }

  /// 查找当前时间戳落在哪个句子区间
  int _findIndexForPosition(int positionMs) {
    final items = state.article.items;
    if (items.isEmpty) return -1;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (positionMs >= item.startMs && positionMs < item.endMs) {
        return i;
      }
    }
    return -1;
  }

  /// 暂停音频播放（供长按等交互调用）
  void pauseAudio() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    }
  }

  /// 切换播放/暂停
  void togglePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        // abLoop 模式下的「系统暂停」状态（轮间等待 或 循环已完成）：
        // _isLoopPausing == true 意味着 positionStream 拦截被封锁，
        // 直接 play() 会导致音频越过 B 句边界脱离循环，必须特殊处理。
        if (state.currentMode == ArticleMode.abLoop &&
            state.loopStartIdx != null &&
            state.loopEndIdx != null &&
            _isLoopPausing) {
          // _loopPauseTimer != null → 定时器仍挂起（轮间等待）
          // _loopPauseTimer == null → 定时器已触发完毕（循环已完成 N/N）
          final isCompleted = _loopPauseTimer == null;
          _loopPauseTimer?.cancel();
          _loopPauseTimer = null;
          _isLoopPausing = false;

          if (isCompleted) {
            // 循环已完成态：计数在完成时已复位为 1，此处无需重复赋值，直接从 A 开始播
          }
          // 轮间等待：保留当前计数，继续播完最后一轮

          await _audioPlayer.seek(
            Duration(
              milliseconds: state.article.items[state.loopStartIdx!].startMs,
            ),
          );
          await _audioPlayer.play();
        } else {
          // 普通恢复：normal 模式，或 abLoop 用户手动暂停后继续
          await _audioPlayer.play();
        }
      }
    } catch (e, st) {
      logger.error('[ArticleAudio] 播放切换失败', e, st);
    }
  }

  /// 跳转到指定毫秒位置
  void seekToPosition(int targetMs) async {
    try {
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
      final newIndex = _findIndexForPosition(targetMs);
      if (newIndex != -1) {
        state = state.copyWith(activeIndex: newIndex);
      }
      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
    } catch (e, st) {
      logger.error('[ArticleAudio] Seek 失败', e, st);
    }
  }

  /// 切换交互模式并在切换时执行完全重置 (Hard Reset)
  void setMode(ArticleMode newMode) async {
    if (state.currentMode == newMode) return;

    // 取消任何正在进行的循环停顿计时
    _loopPauseTimer?.cancel();
    _loopPauseTimer = null;
    _isLoopPausing = false;

    // 强制暂停音频
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    }
    // 进度回退到文章开头
    await _audioPlayer.seek(Duration.zero);

    // 清空所有状态
    state = state.copyWith(
      currentMode: newMode,
      activeIndex: -1,
      currentPositionMs: 0,
      isPlaying: false,
      loopStartIdx: null,
      loopEndIdx: null,
      currentLoopCount: 0,
      userInterruptedScroll: false,
    );
  }

  /// 设置目标循环次数 (1-10)
  void setTargetLoopCount(int count) {
    if (count < 1 || count > 10) return;
    state = state.copyWith(targetLoopCount: count);
  }

  /// 点击句子时的统一路由逻辑
  void onSentenceTap(int index) async {
    if (index < 0 || index >= state.article.items.length) return;

    if (state.currentMode == ArticleMode.normal) {
      // Normal 模式：直接跳转播放
      _seekAndPlayIndex(index);
    } else if (state.currentMode == ArticleMode.abLoop) {
      // AB Loop 模式：选择 A/B 句
      _handleAbSelection(index);
    }
  }

  /// 内部方法：执行实际的跳转和播放
  void _seekAndPlayIndex(int index) async {
    state = state.copyWith(activeIndex: index);
    final targetMs = state.article.items[index].startMs;
    try {
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
    } catch (e, st) {
      logger.error('[ArticleAudio] _seekAndPlayIndex Seek 失败', e, st);
    }
  }

  /// 内部方法：处理 A/B 选择逻辑
  void _handleAbSelection(int index) {
    // 情况 1: 都有 (A 和 B 已就绪) -> 直接中断循环，清空全场，设该句为新 A
    if (state.loopStartIdx != null && state.loopEndIdx != null) {
      if (_audioPlayer.playing) _audioPlayer.pause();
      _loopPauseTimer?.cancel();
      _loopPauseTimer = null;
      _isLoopPausing = false;
      state = state.copyWith(
        loopStartIdx: index,
        loopEndIdx: null,
        currentLoopCount: 0,
        isPlaying: false,
      );
      return;
    }

    // 情况 2: 无 A (初始状态) -> 选为 A
    if (state.loopStartIdx == null) {
      state = state.copyWith(loopStartIdx: index);
      return;
    }

    // 情况 3: 有 A 无 B -> 选为 B，并开始循环播放
    if (state.loopEndIdx == null) {
      int start = state.loopStartIdx!;
      int end = index;

      // 自动纠偏：确保 A 始终 <= B
      if (start > end) {
        final temp = start;
        start = end;
        end = temp;
      }

      state = state.copyWith(
        loopStartIdx: start,
        loopEndIdx: end,
        currentLoopCount: 1, // 第 1 轮开始，显示 1/N
      );

      // 清理上一轮遗留的定时器和暂停锁
      _loopPauseTimer?.cancel();
      _loopPauseTimer = null;
      _isLoopPausing = false;
      // 开始这第一轮的循环播放 (跳到 A句开头)
      _seekAndPlayIndex(start);
    }
  }

  /// 设置当前活跃句子并跳转音频 (保留旧方法名以兼容其他调用，如上/下一句)
  void setActiveIndex(int index) async {
    if (state.currentMode == ArticleMode.abLoop) {
      // 在 AB 循环模式下，外部可能也会调用 setActiveIndex（例如底部控制栏），
      // 为了安全，强制干预为 onSentenceTap 的选取行为或忽略。
      // 作为备用，不作独立处理
      return;
    }
    _seekAndPlayIndex(index);
  }

  /// 设置用户是否打断了自动滚动
  void setUserInterruptedScroll(bool interrupted) {
    state = state.copyWith(userInterruptedScroll: interrupted);
  }

  /// 切换显示模式（四态轮转：全部 → 仅假名 → 仅翻译 → 全隐藏）
  void toggleDisplayMode() {
    final nextMode = switch (state.displayMode) {
      ArticleDisplayMode.all => ArticleDisplayMode.furiganaOnly,
      ArticleDisplayMode.furiganaOnly => ArticleDisplayMode.translationOnly,
      ArticleDisplayMode.translationOnly => ArticleDisplayMode.none,
      ArticleDisplayMode.none => ArticleDisplayMode.all,
    };
    state = state.copyWith(displayMode: nextMode);
  }

  /// 切换播放速度
  void toggleSpeed() {
    double nextSpeed = 1.0;
    if (state.currentSpeed == 0.75) {
      nextSpeed = 1.0;
    } else if (state.currentSpeed == 1.0) {
      nextSpeed = 1.25;
    } else if (state.currentSpeed == 1.25) {
      nextSpeed = 1.5;
    } else if (state.currentSpeed == 1.5) {
      nextSpeed = 0.75;
    }
    _audioPlayer.setSpeed(nextSpeed);
    state = state.copyWith(currentSpeed: nextSpeed);
  }
}

// Provider
final articleAudioProvider =
    NotifierProvider<ArticleAudioController, ArticleState>(
      ArticleAudioController.new,
    );
