import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/word_repository.dart';
import '../../../data/repositories/study_word_repository.dart';
import '../../../data/repositories/study_word_repository_provider.dart';
import '../../../data/repositories/daily_stat_repository.dart';
import '../../../data/repositories/daily_stat_repository_provider.dart';
import '../../../data/repositories/study_log_repository.dart';
import '../../../data/repositories/study_log_repository_provider.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/user_repository_provider.dart';
import '../../../data/models/word_detail.dart';
import '../../../data/models/study_word.dart';
import '../../../data/models/study_log.dart';
import '../../../data/models/daily_stat.dart';
import '../../../services/audio_service.dart';
import '../../../services/audio_service_provider.dart';
import '../../../core/algorithm/algorithm_service.dart';
import '../../../core/algorithm/algorithm_service_provider.dart';
import '../../../core/algorithm/srs_types.dart';
import '../state/learn_state.dart';

/// 学习页面控制器
class LearnController extends Notifier<LearnState> {
  final WordRepository _wordRepository = WordRepository();

  // 当前用户 ID 缓存
  int? _currentUserId;
  // 今日统计缓存
  DailyStat? _todayStat;
  // 学习开始时间（用于计算时长）
  DateTime? _sessionStartTime;
  // 当前单词开始时间
  DateTime? _wordStartTime;

  StudyWordRepository get _studyWordRepository =>
      ref.read(studyWordRepositoryProvider);
  DailyStatRepository get _dailyStatRepository =>
      ref.read(dailyStatRepositoryProvider);
  StudyLogRepository get _studyLogRepository =>
      ref.read(studyLogRepositoryProvider);
  UserRepository get _userRepository => ref.read(userRepositoryProvider);
  AlgorithmService get _algorithmService => ref.read(algorithmServiceProvider);

  @override
  LearnState build() {
    _initAudioListener();
    return LearnState();
  }

  /// 获取音频服务
  AudioService get _audioService => ref.read(audioServiceProvider);

  /// 获取当前用户 ID
  Future<int> _getUserId() async {
    if (_currentUserId != null) return _currentUserId!;
    final users = await _userRepository.getAllUsers();
    if (users.isEmpty) {
      throw Exception('No user found');
    }
    _currentUserId = users.first.id;
    return _currentUserId!;
  }

  /// 初始化今日统计（进入学习页面时调用）
  Future<void> _initTodayStat(int userId) async {
    _todayStat = await _dailyStatRepository.getOrCreateTodayStat(userId);
    logger.info('初始化今日统计: id=${_todayStat!.id}');
  }

  void _initAudioListener() {
    // 监听音频播放状态
    _audioService.player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(
          isPlayingWordAudio: false,
          isPlayingExampleAudio: false,
          playingExampleIndex: null,
        );
      }
    });
  }

  /// 加载单词列表（按 JLPT 等级）
  /// 优先加载待复习的单词，如果不足 count 个，则补充新单词
  /// [append] 为 true 时追加到现有队列（继续学习）
  Future<void> loadWords({
    String? jlptLevel,
    int count = AppConstants.defaultLearnCount,
    bool append = false,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      logger.info('加载单词列表: jlptLevel=$jlptLevel, count=$count, append=$append');

      // 获取当前用户
      final userId = await _getUserId();

      // 初始化今日统计（进入学习页面时）
      if (_todayStat == null) {
        await _initTodayStat(userId);
      }

      // 记录学习开始时间
      _sessionStartTime ??= DateTime.now();

      // 1. 获取待复习单词
      final dueReviews = await _studyWordRepository.getDueReviews(
        userId,
        limit: count,
      );
      logger.info('获取到 ${dueReviews.length} 个待复习单词');

      // 2. 如果不足，获取新单词
      final newWords = <StudyWord>[];
      if (dueReviews.length < count) {
        final newCount = count - dueReviews.length;
        final randomWords = await _wordRepository.getRandomWords(
          count: newCount,
          jlptLevel: jlptLevel,
        );

        // 为新单词创建 StudyWord 对象 (临时对象，尚未存入 DB)
        for (final word in randomWords) {
          // 检查是否已经在 DB 中 (避免重复)
          final existing = await _studyWordRepository.getStudyWord(
            userId,
            word.id,
          );
          if (existing == null) {
            newWords.add(
              StudyWord(
                id: 0, // 临时 ID
                userId: userId,
                wordId: word.id,
                userState: UserWordState.newWord,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          }
        }
        logger.info('获取到 ${newWords.length} 个新单词');
      }

      // 3. 合并队列
      final loadedWords = [...dueReviews, ...newWords];

      // 4. 获取单词详情
      final newWordDetails = <int, WordDetail>{};
      for (final studyWord in loadedWords) {
        final detail = await _wordRepository.getWordDetail(studyWord.wordId);
        if (detail != null) {
          newWordDetails[studyWord.wordId] = detail;
        }
      }

      // 5. 根据 append 决定是替换还是追加
      if (append) {
        // 追加模式：合并到现有队列
        final mergedQueue = [...state.studyQueue, ...loadedWords];
        final mergedDetails = {...state.wordDetails, ...newWordDetails};
        state = state.copyWith(
          studyQueue: mergedQueue,
          wordDetails: mergedDetails,
          isLoading: false,
          hasLoaded: true,
        );
        logger.info('追加加载完成，队列总数: ${mergedQueue.length}');
      } else {
        // 替换模式：重置队列
        state = state.copyWith(
          studyQueue: loadedWords,
          wordDetails: newWordDetails,
          currentIndex: 0,
          isLoading: false,
          hasLoaded: true,
        );
        logger.info('成功加载 ${loadedWords.length} 个单词');
      }

      // 开始计时当前单词
      _wordStartTime = DateTime.now();
    } catch (e, stackTrace) {
      logger.error('加载单词失败', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: l10n.loadFailed(e),
      );
    }
  }

  /// 继续学习（追加加载更多单词）
  Future<void> continueLearn({
    String? jlptLevel,
    int count = AppConstants.defaultLearnCount,
  }) async {
    await loadWords(jlptLevel: jlptLevel, count: count, append: true);
  }

  /// 检查当前批次是否学习完成
  bool get isBatchCompleted {
    return state.currentIndex >= state.studyQueue.length &&
        state.studyQueue.isNotEmpty;
  }

  /// 提交答案
  Future<void> submitAnswer(ReviewRating rating) async {
    final currentStudyWord = state.currentStudyWord;
    if (currentStudyWord == null) return;

    try {
      _stopAllAudio();

      final now = DateTime.now();

      // 计算本单词学习时长
      final wordDurationMs = _wordStartTime != null
          ? now.difference(_wordStartTime!).inMilliseconds
          : 0;

      // 1. 计算 SRS 结果
      double elapsedDays = 0;
      if (currentStudyWord.lastReviewedAt != null) {
        final diff = now.difference(currentStudyWord.lastReviewedAt!);
        elapsedDays = diff.inMinutes / 60.0 / 24.0;
      }

      final srsInput = SRSInput(
        interval: currentStudyWord.interval,
        easeFactor: currentStudyWord.easeFactor,
        stability: currentStudyWord.stability,
        difficulty: currentStudyWord.difficulty,
        reviews: currentStudyWord.totalReviews,
        lapses: currentStudyWord.failCount,
        rating: rating,
        elapsedDays: elapsedDays,
      );

      final srsOutput = _algorithmService.calculate(
        algorithmType: AlgorithmType.fsrs,
        input: srsInput,
      );

      // 2. 更新/创建 StudyWord
      final isNewWord = currentStudyWord.id == 0;
      StudyWord updatedWord;

      if (isNewWord) {
        // 新单词，创建
        final newWord = currentStudyWord.copyWith(
          userState: UserWordState.learning,
          interval: srsOutput.interval,
          easeFactor: srsOutput.easeFactor,
          stability: srsOutput.stability,
          difficulty: srsOutput.difficulty,
          nextReviewAt: srsOutput.nextReviewAt,
          lastReviewedAt: now,
          streak: rating.isCorrect ? 1 : 0,
          totalReviews: 1,
          failCount: rating == ReviewRating.again ? 1 : 0,
          createdAt: now,
          updatedAt: now,
        );
        final id = await _studyWordRepository.createStudyWord(newWord);
        updatedWord = newWord.copyWith(id: id);
        logger.info('创建新学习记录: word_id=${updatedWord.wordId}, id=$id');
      } else {
        // 已有单词，更新
        updatedWord = currentStudyWord.copyWith(
          userState: UserWordState.learning,
          interval: srsOutput.interval,
          easeFactor: srsOutput.easeFactor,
          stability: srsOutput.stability,
          difficulty: srsOutput.difficulty,
          nextReviewAt: srsOutput.nextReviewAt,
          lastReviewedAt: now,
          streak: rating.isCorrect ? (currentStudyWord.streak + 1) : 0,
          totalReviews: currentStudyWord.totalReviews + 1,
          failCount: rating == ReviewRating.again
              ? (currentStudyWord.failCount + 1)
              : currentStudyWord.failCount,
          updatedAt: now,
        );
        await _studyWordRepository.updateStudyWord(updatedWord);
        logger.info('更新学习记录: word_id=${updatedWord.wordId}');
      }

      // 3. 创建 StudyLog
      final log = StudyLog(
        id: 0,
        userId: updatedWord.userId,
        wordId: updatedWord.wordId,
        logType: isNewWord ? LogType.firstLearn : LogType.review,
        rating: rating,
        algorithm: AlgorithmService.getAlgorithmValue(AlgorithmType.fsrs),
        intervalAfter: srsOutput.interval,
        easeFactorAfter: srsOutput.easeFactor,
        fsrsStabilityAfter: srsOutput.stability,
        fsrsDifficultyAfter: srsOutput.difficulty,
        nextReviewAtAfter: srsOutput.nextReviewAt,
        durationMs: wordDurationMs,
        createdAt: now,
      );
      await _studyLogRepository.createLog(log);
      logger.info(
        '创建学习日志: type=${log.logType.description}, duration=${wordDurationMs}ms',
      );

      // 4. 更新 DailyStat（使用缓存的统计对象）
      if (_todayStat != null) {
        _todayStat = _todayStat!.copyWith(
          learnedWordsCount: isNewWord
              ? _todayStat!.learnedWordsCount + 1
              : _todayStat!.learnedWordsCount,
          reviewedWordsCount: !isNewWord
              ? _todayStat!.reviewedWordsCount + 1
              : _todayStat!.reviewedWordsCount,
          failedCount: rating == ReviewRating.again
              ? _todayStat!.failedCount + 1
              : _todayStat!.failedCount,
          totalStudyTimeMs: _todayStat!.totalStudyTimeMs + wordDurationMs,
          updatedAt: now,
        );
        await _dailyStatRepository.updateDailyStat(_todayStat!);
        logger.info(
          '更新今日统计: learned=${_todayStat!.learnedWordsCount}, reviewed=${_todayStat!.reviewedWordsCount}',
        );
      }

      // 5. 更新队列中的 StudyWord（更新 id）
      if (isNewWord) {
        final updatedQueue = List<StudyWord>.from(state.studyQueue);
        updatedQueue[state.currentIndex] = updatedWord;
        state = state.copyWith(studyQueue: updatedQueue);
      }

      // 6. 移动到下一个，重置单词计时和复习阶段
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        reviewPhase: ReviewPhase.question, // 重置为提问阶段
      );
      _wordStartTime = DateTime.now();

      logger.info(
        '提交答案: $rating, 进度: ${state.currentIndex}/${state.studyQueue.length}',
      );
    } catch (e, stackTrace) {
      logger.error('提交答案失败', e, stackTrace);
      state = state.copyWith(error: l10n.submitFailed(e));
    }
  }

  /// 结束学习会话，保存最终统计并重置状态
  Future<void> endSession() async {
    if (_sessionStartTime != null && _todayStat != null) {
      final sessionDuration = DateTime.now()
          .difference(_sessionStartTime!)
          .inMilliseconds;
      logger.info('学习会话结束，总时长: ${sessionDuration}ms');
    }

    // 重置会话状态
    _sessionStartTime = null;
    _wordStartTime = null;
    _todayStat = null;
    _currentUserId = null;

    // 重置 UI 状态，避免下次进入时短暂显示完成页面
    state = LearnState();
  }

  /// 显示答案（复习模式：从提问阶段切换到回答阶段）
  void showAnswer() {
    if (state.currentMode == StudyMode.review &&
        state.reviewPhase == ReviewPhase.question) {
      state = state.copyWith(reviewPhase: ReviewPhase.answer);
      // 自动播放单词音频
      playWordAudio();
      logger.info('显示答案');
    }
  }

  /// 下一个单词
  void nextWord() {
    if (state.hasNext) {
      _stopAllAudio();
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        reviewPhase: ReviewPhase.question, // 重置为提问阶段
      );
      logger.info(
        '切换到下一个单词: ${state.currentIndex + 1}/${state.studyQueue.length}',
      );
    }
  }

  /// 上一个单词
  void previousWord() {
    if (state.hasPrevious) {
      _stopAllAudio();
      state = state.copyWith(
        currentIndex: state.currentIndex - 1,
        reviewPhase: ReviewPhase.question, // 重置为提问阶段
      );
      logger.info(
        '切换到上一个单词: ${state.currentIndex + 1}/${state.studyQueue.length}',
      );
    }
  }

  /// 播放单词音频
  Future<void> playWordAudio() async {
    try {
      final currentWord = state.currentWord;
      if (currentWord == null || currentWord.audios.isEmpty) {
        logger.warning('没有可播放的单词音频');
        return;
      }

      // 停止当前播放
      if (state.isPlayingWordAudio || state.isPlayingExampleAudio) {
        await _audioService.stop();
        state = state.copyWith(
          isPlayingWordAudio: false,
          isPlayingExampleAudio: false,
          playingExampleIndex: null,
        );
        return;
      }

      // 播放第一个音频
      final audio = currentWord.audios.first;
      state = state.copyWith(isPlayingWordAudio: true);
      await _audioService.playWordAudio(audio);
      logger.info('播放单词音频: ${currentWord.word.word}');
    } catch (e, stackTrace) {
      logger.error('播放单词音频失败', e, stackTrace);
      state = state.copyWith(
        isPlayingWordAudio: false,
        error: l10n.playAudioFailed(e),
      );
    }
  }

  /// 播放例句音频
  Future<void> playExampleAudio(int exampleIndex) async {
    try {
      final currentWord = state.currentWord;
      if (currentWord == null || exampleIndex >= currentWord.examples.length) {
        return;
      }

      final example = currentWord.examples[exampleIndex];
      if (example.audio == null) {
        logger.warning('没有可播放的例句音频');
        return;
      }

      // 如果正在播放同一个例句，则停止
      if (state.isPlayingExampleAudio &&
          state.playingExampleIndex == exampleIndex) {
        await _audioService.stop();
        state = state.copyWith(
          isPlayingExampleAudio: false,
          playingExampleIndex: null,
        );
        return;
      }

      // 停止当前播放
      if (state.isPlayingWordAudio || state.isPlayingExampleAudio) {
        await _audioService.stop();
      }

      // 播放例句音频
      state = state.copyWith(
        isPlayingWordAudio: false,
        isPlayingExampleAudio: true,
        playingExampleIndex: exampleIndex,
      );
      await _audioService.playExampleAudio(example.audio!);
      logger.info('播放例句音频: 例句 ${exampleIndex + 1}');
    } catch (e, stackTrace) {
      logger.error('播放例句音频失败', e, stackTrace);
      state = state.copyWith(
        isPlayingExampleAudio: false,
        playingExampleIndex: null,
        error: l10n.playAudioFailed(e),
      );
    }
  }

  /// 停止所有音频
  void _stopAllAudio() {
    _audioService.stop();
    state = state.copyWith(
      isPlayingWordAudio: false,
      isPlayingExampleAudio: false,
      playingExampleIndex: null,
    );
  }
}

/// Provider for LearnController
final learnControllerProvider = NotifierProvider<LearnController, LearnState>(
  () {
    return LearnController();
  },
);
