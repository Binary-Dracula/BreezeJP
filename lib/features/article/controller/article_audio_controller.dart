import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../data/models/article/article.dart';
import '../../../data/models/article/article_item.dart';
import '../../../data/queries/article_query_provider.dart';
import '../state/article_state.dart';

// ----------------------------------------------------------------------
// Audio Controller
// ----------------------------------------------------------------------
class ArticleAudioController extends Notifier<ArticleState> {
  late AudioPlayer _audioPlayer;
  late AudioRecorder _audioRecorder;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  Timer? _shadowingLoopTimer;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  String? _lastRecordedPath;

  @override
  ArticleState build() {
    _audioPlayer = AudioPlayer();
    _audioRecorder = AudioRecorder();

    // 监听销毁（当 provider 被 invalidate 时）
    ref.onDispose(() {
      debugPrint('[ArticleAudio] onDispose: 释放音频资源');
      _cleanup();
    });

    // 初始状态
    return ArticleState(
      article: Article(
        id: 'placeholder',
        title: '选择文章中...',
        items: [
          ArticleItem(
            text: '请选择一篇文章开始阅读',
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
    debugPrint('[ArticleAudio] disposeAudio: 页面退出，停止并释放');
    _cleanup();
    // 重新触发 provider 重建，确保下次进入获得全新实例
    ref.invalidateSelf();
  }

  /// 内部清理方法
  void _cleanup() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _shadowingLoopTimer?.cancel();
    _recordingTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
  }

  /// 初始化特定文章
  Future<void> initArticle(String articleId) async {
    try {
      state = state.copyWith(
        article: Article(
          id: articleId,
          title: '加载中...',
          items: state.article.items,
        ),
      );

      // 通过 ArticleQuery 获取数据 (符合架构规范)
      final articleQuery = ref.read(articleQueryProvider);
      final article = await articleQuery.getArticleById(articleId);

      if (article == null) {
        throw Exception('找不到文章: $articleId');
      }

      state = state.copyWith(article: article);

      // 设置音频源（直接使用打包的本地音频）
      await _audioPlayer.setAsset('assets/mock/${article.id}.mp3');
      debugPrint('Audio asset loaded successfully for ${article.id}');

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

      // 监听进度，执行心跳对齐（高光跟踪）
      _positionSubscription?.cancel();
      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        final positionMs = position.inMilliseconds;
        state = state.copyWith(currentPositionMs: positionMs);

        // 寻找当前进度匹配的句子 Index
        final newIndex = _findIndexForPosition(positionMs);

        if (newIndex != -1 && newIndex != state.activeIndex) {
          state = state.copyWith(activeIndex: newIndex);
        }
      });
    } catch (e, st) {
      debugPrint('Audio Init Error: $e');
      debugPrint(st.toString());
      state = state.copyWith(
        article: Article(
          id: 'error',
          title: '加载失败',
          items: [
            ArticleItem(
              text: '发生错误：$e',
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

  // 查找当前时间戳落在哪个句子区间
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

  // --- 状态变更方法 ---

  void toggleFurigana() {
    state = state.copyWith(showFurigana: !state.showFurigana);
  }

  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  void setUserInterruptedScroll(bool interrupted) {
    state = state.copyWith(userInterruptedScroll: interrupted);
  }

  void setActiveIndex(int index) async {
    if (index < 0 || index >= state.article.items.length) return;
    state = state.copyWith(activeIndex: index);

    // 用户主动点击句子时，取消打断状态（视为有意行为）
    if (state.userInterruptedScroll) {
      state = state.copyWith(userInterruptedScroll: false);
    }

    final targetMs = state.article.items[index].startMs;
    try {
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Seek Error: $e');
    }
  }

  void seekToPosition(int targetMs) async {
    try {
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
      final newIndex = _findIndexForPosition(targetMs);
      if (newIndex != -1) {
        state = state.copyWith(activeIndex: newIndex);
        if (state.userInterruptedScroll) {
          state = state.copyWith(userInterruptedScroll: false);
        }
      }
      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Seek Error: $e');
    }
  }

  void togglePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Playback Error: $e');
    }
  }

  void seekToPreviousSentence() {
    final newIndex = state.activeIndex - 1;
    if (newIndex >= 0) {
      setActiveIndex(newIndex);
    } else {
      _audioPlayer.seek(Duration.zero);
    }
  }

  void seekToNextSentence() {
    final newIndex = state.activeIndex + 1;
    if (newIndex < state.article.items.length) {
      setActiveIndex(newIndex);
    }
  }

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

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioPlayer.pause();
        _shadowingLoopTimer?.cancel();

        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/shadowing_record.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        state = state.copyWith(isRecording: true, recordedDurationMs: 0);
        _recordingStartTime = DateTime.now();

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          if (_recordingStartTime != null) {
            final ms = DateTime.now()
                .difference(_recordingStartTime!)
                .inMilliseconds;
            state = state.copyWith(recordedDurationMs: ms);
          }
        });
      }
    } catch (e) {
      debugPrint('Recording Start Error: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      _lastRecordedPath = path;
      state = state.copyWith(isRecording: false);
    } catch (e) {
      debugPrint('Recording Stop Error: $e');
    }
  }
}

// Provider for the ArticleAudioController
final articleAudioProvider =
    NotifierProvider<ArticleAudioController, ArticleState>(
      ArticleAudioController.new,
    );
