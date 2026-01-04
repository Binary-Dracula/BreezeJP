typedef DomainEventHandler<T> = void Function(T event);

class DomainEventBus {
  static final DomainEventBus _instance = DomainEventBus._internal();
  factory DomainEventBus() => _instance;
  DomainEventBus._internal();

  final Map<Type, List<Function>> _handlers = {};

  void Function() subscribe<T>(DomainEventHandler<T> handler) {
    final list = _handlers.putIfAbsent(T, () => []);
    list.add(handler);

    return () {
      final handlers = _handlers[T];
      if (handlers == null) return;
      handlers.remove(handler);
      if (handlers.isEmpty) {
        _handlers.remove(T);
      }
    };
  }

  void publish<T>(T event) {
    final handlers = _handlers[T];
    if (handlers == null) return;
    for (final handler in List<Function>.from(handlers)) {
      (handler as DomainEventHandler<T>)(event);
    }
  }

  void clear() {
    _handlers.clear();
  }
}
