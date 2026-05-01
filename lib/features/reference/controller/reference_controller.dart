import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/queries/reference_remote_query.dart';
import '../../../data/queries/reference_remote_query_provider.dart';
import '../reference_models.dart';
import '../state/reference_state.dart';

final referenceControllerProvider =
    NotifierProvider<ReferenceController, ReferenceState>(
      ReferenceController.new,
    );

class ReferenceController extends Notifier<ReferenceState> {
  ReferenceRemoteQuery get _remoteQuery =>
      ref.read(referenceRemoteQueryProvider);

  @override
  ReferenceState build() => const ReferenceState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _remoteQuery.fetchReferenceContent();
      state = state.copyWith(
        isLoading: false,
        numbers: _parseGroups(data['numbers']),
        datesAndMonths: _parseGroups(data['datesAndMonths']),
        time: _parseGroups(data['time']),
        counters: _parseGroups(data['counters']),
      );
    } catch (e, stackTrace) {
      logger.error('加载基础速查失败', e, stackTrace);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<ReferenceGroup> _parseGroups(dynamic value) {
    if (value is! List<dynamic>) {
      return const [];
    }
    return value
        .map(
          (group) =>
              ReferenceGroup.fromJson(Map<String, dynamic>.from(group as Map)),
        )
        .toList();
  }
}
