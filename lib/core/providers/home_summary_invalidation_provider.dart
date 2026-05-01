import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeSummaryInvalidationProvider =
    NotifierProvider<HomeSummaryInvalidationNotifier, int>(
      HomeSummaryInvalidationNotifier.new,
    );

class HomeSummaryInvalidationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markStale() {
    state = state + 1;
  }
}
