# Splash 功能模块

## 功能说明

Splash 页面是应用启动时的加载页面，负责执行所有预处理任务：

- 数据库初始化（从 assets 复制到应用目录）
- 数据库完整性验证
- 其他初始化任务（可扩展）

## 文件结构

```
splash/
├── controller/
│   └── splash_controller.dart  # 控制器，管理初始化流程
├── pages/
│   └── splash_page.dart        # UI 页面
└── state/
    └── splash_state.dart       # 状态定义
```

## 工作流程

1. 应用启动 → 显示 Splash 页面
2. 自动执行初始化流程：
   - 检查并复制数据库文件
   - 验证数据库内容
   - 显示加载进度
3. 初始化完成 → 自动跳转到主页面
4. 如果失败 → 显示错误信息和重试按钮

## 扩展初始化任务

在 `splash_controller.dart` 的 `initialize()` 方法中添加：

```dart
// 2. 可以在这里添加其他初始化任务
state = state.copyWith(message: '正在加载用户设置...');
await _loadUserSettings();

state = state.copyWith(message: '正在检查更新...');
await _checkForUpdates();
```

## 状态管理

使用 Riverpod 的 `NotifierProvider` 管理状态：

- `isLoading`: 是否正在加载
- `message`: 当前加载信息
- `error`: 错误信息（如果有）
- `isInitialized`: 是否初始化完成
