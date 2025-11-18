# Logger 快速参考

## 导入

```dart
import 'package:breeze_jp/core/utils/app_logger.dart';
```

## 基础用法

```dart
// 调试信息
logger.debug('调试信息');

// 一般信息
logger.info('一般信息');

// 警告
logger.warning('警告信息');

// 错误
logger.error('错误信息');

// 致命错误
logger.fatal('致命错误');

// 追踪
logger.trace('追踪信息');
```

## 带错误和堆栈

```dart
try {
  // 代码
} catch (e, stackTrace) {
  logger.error('操作失败', e, stackTrace);
}
```

## 专用方法

```dart
// 网络请求
logger.network('GET', '/api/words', data: params);

// 网络响应
logger.networkResponse(200, '/api/words', data: response);

// 网络错误
logger.networkError('GET', '/api/words', error);

// 数据库操作
logger.database('SELECT', table: 'words');
logger.database('INSERT', table: 'words', data: data);
```

## 日志级别

| 方法 | 表情 | 用途 |
|------|------|------|
| `trace()` | 🔍 | 追踪信息 |
| `debug()` | 🐛 | 调试信息 |
| `info()` | 💡 | 一般信息 |
| `warning()` | ⚠️ | 警告 |
| `error()` | ❌ | 错误 |
| `fatal()` | 💀 | 致命错误 |

## 常见场景

### Repository
```dart
logger.debug('开始查询数据');
logger.database('SELECT', table: 'words');
logger.info('查询成功，共 ${results.length} 条');
```

### Controller
```dart
logger.info('开始加载数据');
logger.error('加载失败', error, stackTrace);
```

### 初始化
```dart
logger.info('🚀 应用启动');
logger.debug('初始化数据库...');
logger.info('✅ 初始化完成');
```

## 注意事项

- ✅ 仅 Debug 模式输出
- ✅ Release 模式自动禁用
- ❌ 不要记录敏感信息
- ❌ 不要在循环中记录
