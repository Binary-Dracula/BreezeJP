import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/kana_learning_state.dart';

final kanaStateCacheProvider =
    NotifierProvider<KanaStateCacheNotifier, Map<int, KanaLearningState>>(
      KanaStateCacheNotifier.new,
    );

class KanaStateCacheNotifier extends Notifier<Map<int, KanaLearningState>> {
  @override
  Map<int, KanaLearningState> build() => const {};

  void replaceStates(Iterable<KanaLearningState> states) {
    state = {
      for (final learningState in states) learningState.kanaId: learningState,
    };
  }

  void upsertState(KanaLearningState learningState) {
    state = {...state, learningState.kanaId: learningState};
  }

  void clear() {
    state = const {};
  }
}
