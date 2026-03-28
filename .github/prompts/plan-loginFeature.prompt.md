# Plan: BreezeJP 登录功能实现

## 关键信息

| 项目 | 值 |
|------|------|
| Supabase URL | `https://eecfrzvutrhftwvyebpq.supabase.co` |
| Supabase Anon Key (客户端用) | `sb_publishable_7ExzQJlbMRqWIOuzMzRdQQ_fdtFBGdf` |
| Workers API | `https://api.binary-dracula.com` |
| OAuth 范围 | 仅邮箱密码（Google/Apple 后续） |
| 邮箱确认 | MVP 跳过，Supabase 已关闭 email confirm |
| 首次启动无 Session | 显示 /login 登录页 |
| 登录/注册 UI | 两个独立页面，互相跳转 |

## 现有状态

- pubspec.yaml: **无** supabase_flutter 依赖（已有 dio, shared_preferences, flutter_riverpod, go_router）
- main.dart: 无 Supabase 初始化
- router: initialLocation = `/splash`，无 /login 路由
- DioClient: 单例，有 interceptor 框架，Authorization header 被注释
- ApiEndpoints.baseUrl: 占位符 `https://api.example.com`
- Splash: 初始化完成后直接 `go('/home')`
- SplashState: `isLoading`, `message`, `error`, `isInitialized`（无 hasSession 字段）
- Settings: 仅"记忆算法"设置，无账号区域
- Workers auth.ts: JWT (ES256/JWKS) 验证逻辑**已完整实现**，缺 secrets 配置
- l10n: 使用 ARB 文件 `app_zh.arb`，仅支持中文
- 架构模式: MVVM + Riverpod `NotifierProvider<Controller, State>`

---

## Phase 1: Flutter 客户端

### 步骤 1 — 依赖与初始化

**修改 `pubspec.yaml`**：
```yaml
dependencies:
  supabase_flutter: ^2.8.0
```

**修改 `lib/main.dart`**：
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eecfrzvutrhftwvyebpq.supabase.co',
    anonKey: 'sb_publishable_7ExzQJlbMRqWIOuzMzRdQQ_fdtFBGdf',
  );

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MainApp(),
    ),
  );
}
```

### 步骤 2 — Auth 核心层

**新建 `lib/core/auth/auth_service.dart`**：
- Supabase Auth 薄封装
- `signInWithEmail(email, password)` → `AuthResponse`
- `signUpWithEmail(email, password)` → `AuthResponse`
- `signOut()` → void
- `currentSession` getter → `Session?`
- `currentUser` getter → `User?`
- `onAuthStateChange` → `Stream<AuthState>`

**新建 `lib/core/auth/auth_provider.dart`**：
```dart
// 服务实例
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// 认证状态流（用于全局监听登录/登出事件）
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).onAuthStateChange;
});

// 当前用户（null = 游客）
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authServiceProvider).currentUser;
});

// 是否已登录（便捷 bool）
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
```

### 步骤 3 — 登录页面 Feature

**新建 `lib/features/auth/state/auth_page_state.dart`**：
```dart
class AuthPageState {
  final bool isLoading;
  final String? error;

  const AuthPageState({this.isLoading = false, this.error});
  AuthPageState copyWith({bool? isLoading, String? error});
}
```

**新建 `lib/features/auth/controller/auth_controller.dart`**：
```dart
final authControllerProvider = NotifierProvider<AuthController, AuthPageState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthPageState> {
  @override
  AuthPageState build() => const AuthPageState();

  Future<bool> signIn(String email, String password) async {
    // set loading → call authService.signInWithEmail → handle error → return success
  }

  Future<bool> signUp(String email, String password) async {
    // set loading → call authService.signUpWithEmail → handle error → return success
  }
}
```

**新建 `lib/features/auth/pages/login_page.dart`**（独立登录页）：
```
┌──────────────────────────────┐
│         Breeze JP            │  ← appName
│       日语学习助手             │  ← appSubtitle
│                              │
│  ┌──────────────────────┐    │
│  │  📧 邮箱               │    │
│  └──────────────────────┘    │
│  ┌──────────────────────┐    │
│  │  🔒 密码          👁   │    │
│  └──────────────────────┘    │
│                              │
│  ┌──────────────────────┐    │
│  │       登  录          │    │  ← 主按钮（蓝色填充）
│  └──────────────────────┘    │
│                              │
│    没有账号？前往注册 →        │  ← TextButton → go('/register')
│                              │
│    ─────── 或者 ───────      │
│                              │
│    先去逛逛（游客模式）        │  ← TextButton → go('/home')
└──────────────────────────────┘
```

**新建 `lib/features/auth/pages/register_page.dart`**（独立注册页）：
```
┌──────────────────────────────┐
│         创建账号              │
│                              │
│  ┌──────────────────────┐    │
│  │  📧 邮箱               │    │
│  └──────────────────────┘    │
│  ┌──────────────────────┐    │
│  │  🔒 密码          👁   │    │
│  └──────────────────────┘    │
│  ┌──────────────────────┐    │
│  │  🔒 确认密码       👁   │    │
│  └──────────────────────┘    │
│                              │
│  ┌──────────────────────┐    │
│  │       注  册          │    │  ← 主按钮
│  └──────────────────────┘    │
│                              │
│    已有账号？返回登录 ←        │  ← TextButton → go('/login')
└──────────────────────────────┘
```

注册成功 → 自动登录 → `go('/home')`（MVP 无邮件确认）

### 步骤 4 — 路由

**修改 `lib/router/app_router.dart`**：
```dart
// 新增 import
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';

// 新增路由（在 splash 之后）
GoRoute(
  path: '/login',
  name: 'login',
  builder: (context, state) => const LoginPage(),
),
GoRoute(
  path: '/register',
  name: 'register',
  builder: (context, state) => const RegisterPage(),
),
```

### 步骤 5 — Splash 流程改造

**修改 `lib/features/splash/state/splash_state.dart`**：
```dart
// 新增字段
final bool hasSession; // null 之前是未检查状态

const SplashState({
  // ...existing...
  this.hasSession = false,
});
```

**修改 `lib/features/splash/controller/splash_controller.dart`**：
```dart
// 在 initialize() 末尾，bootstrap 成功后：
final session = Supabase.instance.client.auth.currentSession;
state = state.copyWith(
  isLoading: false,
  message: l10n.splashInitComplete,
  isInitialized: true,
  hasSession: session != null,
);
```

**修改 `lib/features/splash/pages/splash_page.dart`**：
```dart
// ref.listen 改为：
ref.listen(splashControllerProvider, (previous, next) {
  if (next.isInitialized) {
    context.go(next.hasSession ? '/home' : '/login');
  }
});
```

### 步骤 6 — 网络层接入 JWT

**修改 `lib/core/network/api_endpoints.dart`**：
```dart
static const String baseUrl = 'https://api.binary-dracula.com';
```

**修改 `lib/core/network/dio_client.dart`**：
```dart
onRequest: (options, handler) {
  // 注入 JWT token（如果已登录）
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    options.headers['Authorization'] = 'Bearer ${session.accessToken}';
  }
  // ...existing logging...
  handler.next(options);
},
```

### 步骤 7 — Settings 页面扩展

**修改 `lib/features/settings/pages/settings_page.dart`**：

在现有"系统偏好"section 上方，新增"账号"section：

**已登录状态**：
```
┌──────────────────────────────┐
│  👤  账号                     │
│  📧  user@example.com        │
│                              │
│  [ 退出登录 ]                 │  ← 调用 signOut() → go('/login')
└──────────────────────────────┘
```

**游客状态**：
```
┌──────────────────────────────┐
│  👤  账号                     │
│  🚶  游客模式                 │
│  登录后可使用云端功能          │
│                              │
│  [ 前往登录 ]                 │  ← go('/login')
└──────────────────────────────┘
```

---

## Phase 2: Backend Workers 配置

Workers auth.ts 代码已完整，仅需配置 secrets：

```bash
cd backend/workers
wrangler secret put SUPABASE_SERVICE_KEY   # 输入 sb_secret_... 
wrangler secret put JWT_SECRET             # 从 Supabase Dashboard → Settings → API → JWT Secret
wrangler deploy
```

---

## 文件变更总览

| 文件 | 操作 | 说明 |
|------|------|------|
| `pubspec.yaml` | 修改 | 添加 supabase_flutter |
| `lib/main.dart` | 修改 | Supabase.initialize() |
| `lib/core/auth/auth_service.dart` | **新建** | Auth 薄封装 |
| `lib/core/auth/auth_provider.dart` | **新建** | Riverpod providers |
| `lib/features/auth/state/auth_page_state.dart` | **新建** | 页面状态 |
| `lib/features/auth/controller/auth_controller.dart` | **新建** | 控制器 |
| `lib/features/auth/pages/login_page.dart` | **新建** | 登录页 |
| `lib/features/auth/pages/register_page.dart` | **新建** | 注册页 |
| `lib/router/app_router.dart` | 修改 | 添加 /login, /register 路由 |
| `lib/features/splash/state/splash_state.dart` | 修改 | 添加 hasSession 字段 |
| `lib/features/splash/controller/splash_controller.dart` | 修改 | 检查 session 分流 |
| `lib/features/splash/pages/splash_page.dart` | 修改 | 导航逻辑 |
| `lib/core/network/api_endpoints.dart` | 修改 | baseUrl → api.binary-dracula.com |
| `lib/core/network/dio_client.dart` | 修改 | JWT 拦截器 |
| `lib/features/settings/pages/settings_page.dart` | 修改 | 账号区域 + 退出 |
| `lib/l10n/app_zh.arb` | 修改 | 新增登录相关 i18n 字符串 |

**合计**：6 新建 + 10 修改 = 16 文件

---

## l10n 新增字符串

```json
"authLogin": "登录",
"authRegister": "注册",
"authEmail": "邮箱",
"authPassword": "密码",
"authConfirmPassword": "确认密码",
"authNoAccount": "没有账号？前往注册",
"authHasAccount": "已有账号？返回登录",
"authGuestMode": "先去逛逛（游客模式）",
"authOr": "或者",
"authCreateAccount": "创建账号",
"authLoginFailed": "登录失败: {error}",
"authRegisterFailed": "注册失败: {error}",
"authPasswordMismatch": "两次密码不一致",
"settingsAccount": "账号",
"settingsGuestMode": "游客模式",
"settingsGuestHint": "登录后可使用云端功能",
"settingsGoLogin": "前往登录",
"settingsLogout": "退出登录"
```

---

## Verification

1. `flutter pub get` 无依赖冲突
2. Splash → 无 session → `/login` 登录页
3. 点"先去逛逛" → `/home` 游客模式
4. 点"前往注册" → `/register` 注册页
5. 注册 → 自动登录 → `/home`（无邮件确认）
6. 杀进程重启 → Splash 检测 session → 直接 `/home`
7. Settings 已登录 → 显示邮箱 + 退出按钮
8. Settings 游客 → 显示"游客模式" + "前往登录"
9. 退出登录 → `/login`
10. DioClient 请求自动携带 Bearer token

---

## 决策边界

- **本次包含**：邮箱密码登录/注册、游客模式、Splash 分流、JWT 注入、Settings 账号区域
- **本次不包含**：Google/Apple OAuth、邮件确认流程、NhkSyncService 远程数据源、article 列表云端拦截弹窗（下阶段做）、用户学习数据同步
- **安全**：Flutter 仅使用 anon key（publishable），service key 仅在 Workers 端通过 wrangler secret 配置
