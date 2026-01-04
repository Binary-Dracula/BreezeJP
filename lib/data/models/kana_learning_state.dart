import '../../core/constants/learning_status.dart';

/// 五十音学习状态模型（仅状态，不含 SRS 字段）
class KanaLearningState {
  final int id;
  final int userId;
  final int kanaId;

  /// 学习状态：learning / mastered
  final LearningStatus learningStatus;

  /// 创建时间 (Unix 时间戳)
  final int createdAt;

  /// 更新时间 (Unix 时间戳)
  final int updatedAt;

  KanaLearningState({
    required this.id,
    required this.userId,
    required this.kanaId,
    this.learningStatus = LearningStatus.learning,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// 是否处于掌握状态
  bool get isMastered => learningStatus == LearningStatus.mastered;

  /// 是否处于学习中
  bool get isLearning => learningStatus == LearningStatus.learning;

  factory KanaLearningState.fromMap(Map<String, dynamic> map) {
    final statusValue = (map['learning_status'] as int? ?? 0)
        .clamp(0, LearningStatus.values.length - 1)
        .toInt();
    return KanaLearningState(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      kanaId: map['kana_id'] as int,
      learningStatus: LearningStatus.values[statusValue],
      createdAt: map['created_at'] as int?,
      updatedAt: map['updated_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'kana_id': kanaId,
      'learning_status': learningStatus.value,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 用于插入的 Map（不包含 id）
  Map<String, dynamic> toInsertMap() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  /// 创建副本并更新字段
  KanaLearningState copyWith({
    int? id,
    int? userId,
    int? kanaId,
    LearningStatus? learningStatus,
    int? createdAt,
    int? updatedAt,
  }) {
    return KanaLearningState(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kanaId: kanaId ?? this.kanaId,
      learningStatus: learningStatus ?? this.learningStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
