/// 本地待同步变更队列项
class SyncOutboxItem {
  final int id;
  final String syncUserId;
  final String mutationId;
  final String entityType;
  final String entityKey;
  final String operation;
  final String payload;
  final int? baseVersion;
  final String status;
  final int retryCount;
  final int? nextRetryAt;
  final String? lastError;
  final int createdAt;
  final int updatedAt;

  SyncOutboxItem({
    required this.id,
    required this.syncUserId,
    required this.mutationId,
    required this.entityType,
    required this.entityKey,
    required this.operation,
    required this.payload,
    this.baseVersion,
    this.status = 'pending',
    this.retryCount = 0,
    this.nextRetryAt,
    this.lastError,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  factory SyncOutboxItem.fromMap(Map<String, dynamic> map) {
    return SyncOutboxItem(
      id: map['id'] as int,
      syncUserId: map['sync_user_id'] as String,
      mutationId: map['mutation_id'] as String,
      entityType: map['entity_type'] as String,
      entityKey: map['entity_key'] as String,
      operation: map['operation'] as String,
      payload: map['payload'] as String,
      baseVersion: map['base_version'] as int?,
      status: map['status'] as String? ?? 'pending',
      retryCount: map['retry_count'] as int? ?? 0,
      nextRetryAt: map['next_retry_at'] as int?,
      lastError: map['last_error'] as String?,
      createdAt: map['created_at'] as int?,
      updatedAt: map['updated_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_user_id': syncUserId,
      'mutation_id': mutationId,
      'entity_type': entityType,
      'entity_key': entityKey,
      'operation': operation,
      'payload': payload,
      'base_version': baseVersion,
      'status': status,
      'retry_count': retryCount,
      'next_retry_at': nextRetryAt,
      'last_error': lastError,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  SyncOutboxItem copyWith({
    int? id,
    String? syncUserId,
    String? mutationId,
    String? entityType,
    String? entityKey,
    String? operation,
    String? payload,
    Object? baseVersion = _sentinel,
    String? status,
    int? retryCount,
    Object? nextRetryAt = _sentinel,
    Object? lastError = _sentinel,
    int? createdAt,
    int? updatedAt,
  }) {
    return SyncOutboxItem(
      id: id ?? this.id,
      syncUserId: syncUserId ?? this.syncUserId,
      mutationId: mutationId ?? this.mutationId,
      entityType: entityType ?? this.entityType,
      entityKey: entityKey ?? this.entityKey,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      baseVersion: baseVersion == _sentinel
          ? this.baseVersion
          : baseVersion as int?,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt == _sentinel
          ? this.nextRetryAt
          : nextRetryAt as int?,
      lastError: lastError == _sentinel ? this.lastError : lastError as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _sentinel = Object();
}
