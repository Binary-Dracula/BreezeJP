/// 应用状态表模型
/// 仅存储当前活跃用户的 ID
class AppState {
  static const singletonId = 1;

  final int id;
  final int? currentUserId;

  const AppState({this.id = singletonId, this.currentUserId});

  /// 从数据库 Map 创建实例
  factory AppState.fromMap(Map<String, dynamic> map) {
    return AppState(
      id: map['id'] as int? ?? singletonId,
      currentUserId: map['current_user_id'] as int?,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {'id': id, 'current_user_id': currentUserId};
  }

  /// 复制并修改部分字段
  AppState copyWith({int? id, int? currentUserId}) {
    return AppState(
      id: id ?? this.id,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}
