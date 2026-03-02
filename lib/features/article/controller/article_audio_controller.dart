import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/article/article.dart';
import '../../../data/models/article/article_item.dart';
import '../../../data/queries/article_query_provider.dart';
import '../state/article_state.dart';

// ----------------------------------------------------------------------
// Audio Controller（精简版：仅保留核心播放功能）
// ----------------------------------------------------------------------
class ArticleAudioController extends Notifier<ArticleState> {
  late AudioPlayer _audioPlayer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  ArticleState build() {
    _audioPlayer = AudioPlayer();

    ref.onDispose(() {
      logger.info('[ArticleAudio] onDispose: 释放音频资源');
      _cleanup();
    });

    // 初始状态
    return ArticleState(
      article: Article(
        id: 'placeholder',
        title: '',
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
        article: Article(id: articleId, title: '', items: state.article.items),
      );

      // 通过 ArticleQuery 获取数据
      final articleQuery = ref.read(articleQueryProvider);
      final article = await articleQuery.getArticleById(articleId);

      if (article == null) {
        throw Exception('找不到文章: $articleId');
      }

      state = state.copyWith(article: article);

      // 设置音频源
      await _audioPlayer.setAsset('assets/mock/${article.id}.mp3');
      logger.info('[ArticleAudio] 音频加载成功: ${article.id}');

      // 监听播放状态
      _playerStateSubscription?.cancel();
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((
        playerState,
      ) {
        state = state.copyWith(isPlaying: playerState.playing);

        // 播放完成，重置到初始状态
        if (playerState.processingState == ProcessingState.completed) {
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
            state.loopEndIdx != null) {
          final loopEndMs = items[state.loopEndIdx!].endMs;

          // 如果进度超过了 B 句的结束时间 (加 50ms 容差避免误判)
          if (positionMs >= loopEndMs - 50) {
            final nextCount = state.currentLoopCount + 1;

            if (nextCount >= state.targetLoopCount) {
              // 达到目标次数：暂停，并重置计数器 (允许用户再次点击播放重新开始)
              _audioPlayer.pause();
              _audioPlayer.seek(
                Duration(milliseconds: items[state.loopStartIdx!].startMs),
              );
              state = state.copyWith(currentLoopCount: 0, isPlaying: false);
            } else {
              // 未达到目标次数：递增计数，跳回 A 句开头继续播
              state = state.copyWith(currentLoopCount: nextCount);
              _audioPlayer.seek(
                Duration(milliseconds: items[state.loopStartIdx!].startMs),
              );
            }
          }
        }
      });
    } catch (e, st) {
      logger.error('[ArticleAudio] 初始化失败', e, st);
      state = state.copyWith(
        article: Article(
          id: 'error',
          title: '',
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
        await _audioPlayer.play();
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
        currentLoopCount: 0,
      );

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
