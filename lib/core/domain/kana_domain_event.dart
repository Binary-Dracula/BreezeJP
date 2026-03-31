sealed class KanaDomainEvent {
  final int userId;
  final int kanaId;
  final DateTime occurredAt;

  const KanaDomainEvent({
    required this.userId,
    required this.kanaId,
    required this.occurredAt,
  });
}

/// 用户完整完成一次描红
final class KanaPracticed extends KanaDomainEvent {
  const KanaPracticed({
    required super.userId,
    required super.kanaId,
    required super.occurredAt,
  });
}

/// 用户将假名标记为已掌握
final class KanaMastered extends KanaDomainEvent {
  const KanaMastered({
    required super.userId,
    required super.kanaId,
    required super.occurredAt,
  });
}

/// 用户取消已掌握（回到 learning）
final class KanaUnmastered extends KanaDomainEvent {
  const KanaUnmastered({
    required super.userId,
    required super.kanaId,
    required super.occurredAt,
  });
}
