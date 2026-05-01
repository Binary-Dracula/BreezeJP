import 'package:flutter_riverpod/flutter_riverpod.dart';

final favoriteRefreshProvider = NotifierProvider<FavoriteRefreshNotifier, int>(
  FavoriteRefreshNotifier.new,
);

class FavoriteRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state++;
  }
}
