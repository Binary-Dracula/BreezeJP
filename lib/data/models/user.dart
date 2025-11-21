/// 用户模型
class User {
  final int id;
  final String username;
  final String passwordHash;
  final String? email;
  final String? nickname;
  final String? avatarUrl;
  final int status; // 1=正常, 0=禁用
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    this.email,
    this.nickname,
    this.avatarUrl,
    this.status = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从数据库 Map 创建实例
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      email: map['email'] as String?,
      nickname: map['nickname'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      status: map['status'] as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int) * 1000,
      ),
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'email': email,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// 复制并修改部分字段
  User copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? email,
    String? nickname,
    String? avatarUrl,
    int? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
