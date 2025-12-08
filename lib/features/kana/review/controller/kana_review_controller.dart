import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/kana_learning_state.dart';
import '../../../../data/models/kana_letter.dart';
import '../../../../data/repositories/active_user_provider.dart';
import '../../../../data/repositories/kana_repository.dart';
import '../../../../data/repositories/kana_repository_provider.dart';
import '../state/kana_review_state.dart';

final kanaReviewControllerProvider =
    NotifierProvider<KanaReviewController, KanaReviewState>(
      KanaReviewController.new,
    );

class KanaReviewController extends Notifier<KanaReviewState> {
  KanaRepository get _repo => ref.read(kanaRepositoryProvider);

  @override
  KanaReviewState build() => const KanaReviewState();

  Future<void> loadReviewList() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final user = await ref.read(activeUserProvider.future);
      final learningStates = await _repo.getDueReviewKana(user.id);
      final items = await _composeReviewItems(learningStates);

      state = state.copyWith(
        isLoading: false,
        reviewList: items,
        currentIndex: 0,
        isFinished: items.isEmpty,
      );
      logger.info('假名复习队列加载成功: ${items.length} 个待复习');
    } catch (e, stackTrace) {
      logger.error('加载假名复习队列失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool get isLastItem =>
      state.currentIndex >= state.reviewList.length - 1 &&
      state.reviewList.isNotEmpty;

  bool get isFirstItem => state.currentIndex <= 0;

  Future<void> next() async {
    if (isLastItem) {
      state = state.copyWith(isFinished: true);
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  Future<void> prev() async {
    if (isFirstItem) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  Future<List<ReviewKanaItem>> _composeReviewItems(
    List<KanaLearningState> learningStates,
  ) async {
    final List<ReviewKanaItem> items = [];

    for (final learningState in learningStates) {
      final KanaLetter? letter = await _repo.getKanaLetterById(
        learningState.kanaId,
      );
      if (letter == null) {
        logger.warning('假名不存在，跳过复习项: kanaId=${learningState.kanaId}');
        continue;
      }
      final audio = await _repo.getKanaAudio(learningState.kanaId);
      items.add(
        ReviewKanaItem(
          kanaLetter: letter,
          learningState: learningState,
          audioFilename: audio?.audioFilename,
        ),
      );
    }

    return items;
  }
}
