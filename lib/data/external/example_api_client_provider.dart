import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'example_api_client.dart';

final exampleApiClientProvider = Provider<ExampleApiClient>((ref) {
  return ExampleApiClient();
});
