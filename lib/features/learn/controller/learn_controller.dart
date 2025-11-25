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
import '../../../services/audio_service.dart';
import '../../../services/audio_service_provider.dart';
import '../../../core/algorithm/algorithm_service.dart';
import '../../../core/algorithm/algorithm_service_provider.dart';
import '../../../core/algorithm/srs_types.dart';
import '../state/learn_state.dart';

/// 学习页面控制器
class LearnController extends Notifier<LearnState> {
  final WordRepository _wordRepository = WordRepository();

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
  Future<void> loadWords({
    String? jlptLevel,
    int count = AppConstants.defaultLearnCount,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      logger.info('加载单词列表: jlptLevel=$jlptLevel, count=$count');

      // 获取当前用户 (这里简化处理，假设只有一个用户或默认用户)
      final users = await _userRepository.getAllUsers();
      if (users.isEmpty) {
        throw Exception('No user found');
      }
      final userId = users.first.id;

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
        // 获取新单词 ID 列表
        // 注意：这里需要 WordRepository 提供一个方法来获取用户未学习的单词
        // 暂时使用随机获取未学习单词的逻辑
        // TODO: 优化 WordRepository 以支持排除已学习单词
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
      final studyQueue = [...dueReviews, ...newWords];

      // 4. 获取单词详情
      final wordDetails = <int, WordDetail>{};
      for (final studyWord in studyQueue) {
        final detail = await _wordRepository.getWordDetail(studyWord.wordId);
        if (detail != null) {
          wordDetails[studyWord.wordId] = detail;
        }
      }

      state = state.copyWith(
        studyQueue: studyQueue,
        wordDetails: wordDetails,
        currentIndex: 0,
        isLoading: false,
      );

      logger.info('成功加载 ${studyQueue.length} 个单词');
    } catch (e, stackTrace) {
      logger.error('加载单词失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: l10n.loadFailed(e));
    }
  }

  /// 提交答案
  Future<void> submitAnswer(ReviewRating rating) async {
    final currentStudyWord = state.currentStudyWord;
    if (currentStudyWord == null) return;

    try {
      _stopAllAudio();

      // 1. 计算 SRS 结果
      final now = DateTime.now();
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

      // 使用 FSRS 算法 (TODO: 根据用户设置选择算法)
      final srsOutput = _algorithmService.calculate(
        algorithmType: AlgorithmType.fsrs,
        input: srsInput,
      );

      // 2. 更新/创建 StudyWord
      StudyWord updatedWord;
      if (currentStudyWord.id == 0) {
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
      }

      // 3. 创建 StudyLog
      final log = StudyLog(
        id: 0,
        userId: updatedWord.userId,
        wordId: updatedWord.wordId,
        logType: currentStudyWord.isNew ? LogType.firstLearn : LogType.review,
        rating: rating,
        algorithm: AlgorithmService.getAlgorithmValue(AlgorithmType.fsrs),
        intervalAfter: srsOutput.interval,
        easeFactorAfter: srsOutput.easeFactor,
        fsrsStabilityAfter: srsOutput.stability,
        fsrsDifficultyAfter: srsOutput.difficulty,
        nextReviewAtAfter: srsOutput.nextReviewAt,
        durationMs: 0, // TODO: 记录实际时长
        createdAt: now,
      );
      await _studyLogRepository.createLog(log);

      // 4. 更新 DailyStat
      final todayStat = await _dailyStatRepository.getOrCreateTodayStat(
        updatedWord.userId,
      );
      final updatedStat = todayStat.copyWith(
        learnedWordsCount: currentStudyWord.isNew
            ? todayStat.learnedWordsCount + 1
            : todayStat.learnedWordsCount,
        reviewedWordsCount: !currentStudyWord.isNew
            ? todayStat.reviewedWordsCount + 1
            : todayStat.reviewedWordsCount,
        failedCount: rating == ReviewRating.again
            ? todayStat.failedCount + 1
            : todayStat.failedCount,
        totalStudyTimeMs: todayStat.totalStudyTimeMs + 0, // TODO: 累加时长
        updatedAt: now,
      );
      await _dailyStatRepository.updateDailyStat(updatedStat);

      // 5. 更新队列状态
      // 如果是 Again，可能需要重新加入队列 (这里简化为直接下一个)
      // 实际应用中，Again 的单词通常会在本次学习 session 中再次出现

      // 移动到下一个
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      logger.info('提交答案: $rating, 下一个: ${state.currentIndex + 1}');
    } catch (e, stackTrace) {
      logger.error('提交答案失败', e, stackTrace);
      state = state.copyWith(error: l10n.submitFailed(e));
    }
  }

  /// 下一个单词
  void nextWord() {
    if (state.hasNext) {
      _stopAllAudio();
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      logger.info(
        '切换到下一个单词: ${state.currentIndex + 1}/${state.studyQueue.length}',
      );
    }
  }

  /// 上一个单词
  void previousWord() {
    if (state.hasPrevious) {
      _stopAllAudio();
      state = state.copyWith(currentIndex: state.currentIndex - 1);
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
