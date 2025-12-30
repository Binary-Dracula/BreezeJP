import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/commands/daily_stat_command.dart';
import 'page_duration_tracker.dart';

mixin PageDurationTrackingMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final PageDurationTracker _pageDurationTracker;

  @override
  void initState() {
    super.initState();
    _pageDurationTracker = PageDurationTracker(
      ref.read(dailyStatCommandProvider),
    );
    _pageDurationTracker.onEnter();
  }

  @override
  void dispose() {
    _pageDurationTracker.onExit();
    super.dispose();
  }
}
