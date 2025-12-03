/// 用户模型
class User {
  final int id;
  final String username;
  final String passwordHash;
  final String? email;
  final String? nickname;
  final String? avatarUrl;

  /// 用户状态：1=active, 0=inactive
  final int status;

  /// JSON 用户偏好设置
  final String? settings;

  /// 语言偏好 zh/en/ja
  final String locale;

  /// 时区 Asia/Shanghai 等
  final String? timezone;

  /// 上次活跃时间戳
  final int? lastActiveAt;

  /// 是否完成引导
  final int onboardingCompleted;

  /// Pro 状态：0=Free, 1=Pro
  final int proStatus;

  final int createdAt;
  final int updatedAt;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    this.email,
    this.nickname,
    this.avatarUrl,
    this.status = 1,
    this.settings,
    this.locale = 'zh',
    this.timezone,
    this.lastActiveAt,
    this.onboardingCompleted = 0,
    this.proStatus = 0,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// 是否为 Pro 用户
  bool get isPro => proStatus == 1;

  /// 是否已完成引导
  bool get hasCompletedOnboarding => onboardingCompleted == 1;

  /// 是否活跃
  bool get isActive => status == 1;

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
      settings: map['settings'] as String?,
      locale: map['locale'] as String? ?? 'zh',
      timezone: map['timezone'] as String?,
      lastActiveAt: map['last_active_at'] as int?,
      onboardingCompleted: map['onboarding_completed'] as int? ?? 0,
      proStatus: map['pro_status'] as int? ?? 0,
      createdAt: map['created_at'] as int?,
      updatedAt: map['updated_at'] as int?,
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
      'settings': settings,
      'locale': locale,
      'timezone': timezone,
      'last_active_at': lastActiveAt,
      'onboarding_completed': onboardingCompleted,
      'pro_status': proStatus,
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

  /// 复制并修改部分字段
  User copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? email,
    String? nickname,
    String? avatarUrl,
    int? status,
    String? settings,
    String? locale,
    String? timezone,
    int? lastActiveAt,
    int? onboardingCompleted,
    int? proStatus,
    int? createdAt,
    int? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      settings: settings ?? this.settings,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      proStatus: proStatus ?? this.proStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
