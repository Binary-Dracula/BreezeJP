/// 本地同步游标状态（每个云端用户一条）
class SyncState {
  final String syncUserId;
  final String? deviceId;
  final int lastPulledSeq;
  final int? lastPushAt;
  final int? lastSuccessAt;
  final int bootstrapVersion;
  final int createdAt;
  final int updatedAt;

  SyncState({
    required this.syncUserId,
    this.deviceId,
    this.lastPulledSeq = 0,
    this.lastPushAt,
    this.lastSuccessAt,
    this.bootstrapVersion = 1,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  factory SyncState.fromMap(Map<String, dynamic> map) {
    return SyncState(
      syncUserId: map['sync_user_id'] as String,
      deviceId: map['device_id'] as String?,
      lastPulledSeq: map['last_pulled_seq'] as int? ?? 0,
      lastPushAt: map['last_push_at'] as int?,
      lastSuccessAt: map['last_success_at'] as int?,
      bootstrapVersion: map['bootstrap_version'] as int? ?? 1,
      createdAt: map['created_at'] as int?,
      updatedAt: map['updated_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sync_user_id': syncUserId,
      'device_id': deviceId,
      'last_pulled_seq': lastPulledSeq,
      'last_push_at': lastPushAt,
      'last_success_at': lastSuccessAt,
      'bootstrap_version': bootstrapVersion,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  SyncState copyWith({
    String? syncUserId,
    Object? deviceId = _sentinel,
    int? lastPulledSeq,
    Object? lastPushAt = _sentinel,
    Object? lastSuccessAt = _sentinel,
    int? bootstrapVersion,
    int? createdAt,
    int? updatedAt,
  }) {
    return SyncState(
      syncUserId: syncUserId ?? this.syncUserId,
      deviceId: deviceId == _sentinel ? this.deviceId : deviceId as String?,
      lastPulledSeq: lastPulledSeq ?? this.lastPulledSeq,
      lastPushAt: lastPushAt == _sentinel
          ? this.lastPushAt
          : lastPushAt as int?,
      lastSuccessAt: lastSuccessAt == _sentinel
          ? this.lastSuccessAt
          : lastSuccessAt as int?,
      bootstrapVersion: bootstrapVersion ?? this.bootstrapVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const Object _sentinel = Object();
}
