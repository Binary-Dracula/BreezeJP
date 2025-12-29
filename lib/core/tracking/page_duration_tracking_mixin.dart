import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'page_duration_tracker.dart';

mixin PageDurationTrackingMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final PageDurationTracker _pageDurationTracker;

  @override
  void initState() {
    super.initState();
    _pageDurationTracker = PageDurationTracker(ref);
    _pageDurationTracker.onEnter();
  }

  @override
  void dispose() {
    _pageDurationTracker.onExit();
    super.dispose();
  }
}
