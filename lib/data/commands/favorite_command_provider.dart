import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorite_command.dart';

final favoriteCommandProvider = Provider<FavoriteCommand>((ref) {
  return FavoriteCommand(ref);
});
