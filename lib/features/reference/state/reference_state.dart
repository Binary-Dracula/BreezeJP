import 'package:flutter/foundation.dart';

import '../reference_models.dart';

@immutable
class ReferenceState {
  const ReferenceState({
    this.isLoading = false,
    this.error,
    this.numbers = const [],
    this.datesAndMonths = const [],
    this.time = const [],
    this.counters = const [],
  });

  final bool isLoading;
  final String? error;
  final List<ReferenceGroup> numbers;
  final List<ReferenceGroup> datesAndMonths;
  final List<ReferenceGroup> time;
  final List<ReferenceGroup> counters;

  ReferenceState copyWith({
    bool? isLoading,
    Object? error = _unset,
    List<ReferenceGroup>? numbers,
    List<ReferenceGroup>? datesAndMonths,
    List<ReferenceGroup>? time,
    List<ReferenceGroup>? counters,
  }) {
    return ReferenceState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      numbers: numbers ?? this.numbers,
      datesAndMonths: datesAndMonths ?? this.datesAndMonths,
      time: time ?? this.time,
      counters: counters ?? this.counters,
    );
  }

  static const Object _unset = Object();
}
