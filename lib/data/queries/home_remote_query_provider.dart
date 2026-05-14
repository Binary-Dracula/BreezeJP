import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_remote_query.dart';

final homeRemoteQueryProvider = Provider<HomeRemoteQuery>((ref) {
  return HomeRemoteQuery();
});
