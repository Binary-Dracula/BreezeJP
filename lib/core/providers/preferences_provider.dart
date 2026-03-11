import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../algorithm/srs_types.dart'; // import AlgorithmType

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final algorithmTypeProvider =
    NotifierProvider<AlgorithmTypeNotifier, AlgorithmType>(() {
      return AlgorithmTypeNotifier();
    });

final firstReviewIntervalProvider =
    NotifierProvider<FirstReviewIntervalNotifier, int>(() {
      return FirstReviewIntervalNotifier();
    });

class FirstReviewIntervalNotifier extends Notifier<int> {
  static const _key = 'first_review_interval_minutes';

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_key) ?? 10; // 默认 10 分钟
  }

  Future<void> setInterval(int minutes) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_key, minutes);
    state = minutes;
  }
}


class AlgorithmTypeNotifier extends Notifier<AlgorithmType> {
  static const _key = 'review_algorithm_type';

  @override
  AlgorithmType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _loadType(prefs);
  }

  static AlgorithmType _loadType(SharedPreferences prefs) {
    final typeIndex = prefs.getInt(_key);
    if (typeIndex != null &&
        typeIndex >= 0 &&
        typeIndex < AlgorithmType.values.length) {
      return AlgorithmType.values[typeIndex];
    }
    return AlgorithmType.sm2; // default
  }

  Future<void> setType(AlgorithmType type) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_key, type.index);
    state = type;
  }
}
