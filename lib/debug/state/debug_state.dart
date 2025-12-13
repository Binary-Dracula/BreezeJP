import 'package:flutter/foundation.dart';

@immutable
class DebugState {
  final List<DebugTestItem> testItems;

  const DebugState({this.testItems = const []});

  DebugState copyWith({List<DebugTestItem>? testItems}) {
    return DebugState(testItems: testItems ?? this.testItems);
  }
}

@immutable
class DebugTestItem {
  final String key;
  final String title;
  final String description;
  final String route;

  const DebugTestItem({
    required this.key,
    required this.title,
    required this.description,
    required this.route,
  });
}
