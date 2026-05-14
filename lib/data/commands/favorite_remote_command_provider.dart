import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorite_remote_command.dart';

final favoriteRemoteCommandProvider = Provider<FavoriteRemoteCommand>((ref) {
  return FavoriteRemoteCommand();
});
