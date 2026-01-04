import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/domain_event_bus.dart';
import '../../../../domain/kana/kana_domain_event.dart';
import '../controller/kana_chart_controller.dart';

class KanaChartDomainListener {
  KanaChartDomainListener(this.ref) {
    final bus = DomainEventBus();

    _unsubscribes.add(
      bus.subscribe<KanaPracticed>((_) => _reload()),
    );
    _unsubscribes.add(
      bus.subscribe<KanaMastered>((_) => _reload()),
    );
    _unsubscribes.add(
      bus.subscribe<KanaUnmastered>((_) => _reload()),
    );
  }

  final Ref ref;
  final List<void Function()> _unsubscribes = [];

  void _reload() {
    ref.read(kanaChartControllerProvider.notifier).loadKanaChart();
  }

  void dispose() {
    for (final unsub in _unsubscribes) {
      unsub();
    }
    _unsubscribes.clear();
  }
}
