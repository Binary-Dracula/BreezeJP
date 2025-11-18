# 📝 日志系统配置完成

## ✅ 已完成的工作

### 1. 添加依赖
在 `pubspec.yaml` 中添加了 `logger: ^2.5.0`

### 2. 创建日志工具类
`lib/core/utils/app_logger.dart` - 统一的日志管理工具

### 3. 集成到网络请求层
`lib/core/network/dio_client.dart` - 使用 logger 替代 print

### 4. 创建文档
`lib/core/utils/README.md` - 详细的使用文档

## 🎯 核心特性

### AppLogger 功能
- ✅ **仅 Debug 模式输出** - Release 模式不输出，不影响性能
- ✅ **彩色输出** - 不同级别不同颜色，易于区分
- ✅ **表情符号** - 直观的视觉标识
- ✅ **时间戳** - 记录日志时间
- ✅ **调用栈** - 显示方法调用链
- ✅ **专用方法** - 网络、数据库等专用日志方法

### 日志级别

| 级别 | 方法 | 表情 | 用途 |
|------|------|------|------|
| Trace | `logger.trace()` | 🔍 | 追踪信息 |
| Debug | `logger.debug()` | 🐛 | 调试信息 |
| Info | `logger.info()` | 💡 | 一般信息 |
| Warning | `logger.warning()` | ⚠️ | 警告信息 |
| Error | `logger.error()` | ❌ | 错误信息 |
| Fatal | `logger.fatal()` | 💀 | 致命错误 |

## 📖 快速使用

### 基础日志

```dart
import 'package:breeze_jp/core/utils/app_logger.dart';

logger.debug('调试信息');
logger.info('一般信息');
logger.warning('警告信息');
logger.error('错误信息');
```

### 带错误和堆栈

```dart
try {
  // 代码
} catch (e, stackTrace) {
  logger.error('操作失败', e, stackTrace);
}
```

### 网络请求日志

```dart
// 自动集成在 DioClient 中
logger.network('GET', '/api/words');
logger.networkResponse(200, '/api/words', data: response);
logger.networkError('GET', '/api/words', error);
```

### 数据库日志

```dart
logger.database('SELECT', table: 'words');
logger.database('INSERT', table: 'words', data: wordData);
```

## 🔄 已替换的 print 语句

### DioClient (lib/core/network/dio_client.dart)

**之前：**
```dart
assert(() {
  print('🌐 REQUEST[${options.method}] => ${options.uri}');
  print('Headers: ${options.headers}');
  return true;
}());
```

**之后：**
```dart
logger.network(
  options.method,
  options.uri.toString(),
  data: options.data,
);
```

## 📊 日志输出示例

### 网络请求日志
```
💡 INFO | 🌐 [GET] https://api.example.com/words
Data: {level: N5, limit: 20}

✅ INFO | ✅ [200] https://api.example.com/words
Response: [{id: 1, word: 学校}, ...]
```

### 数据库日志
```
🐛 DEBUG | 💾 DB[SELECT] words

🐛 DEBUG | 💾 DB[INSERT] words
Data: {id: 123, word: 学校}
```

### 错误日志
```
❌ ERROR | 操作失败
NetworkException: 连接超时，请检查网络设置
  at DioClient._handleError (dio_client.dart:215)
  at DioClient.get (dio_client.dart:89)
  ...
```

## 🎨 使用场景

### 1. Repository 层

```dart
class WordRepository {
  Future<List<Word>> fetchWords() async {
    logger.debug('开始获取单词列表');
    
    try {
      final results = await db.query('words');
      logger.database('SELECT', table: 'words');
      logger.info('成功获取 ${results.length} 个单词');
      
      return parseWords(results);
    } catch (e, stackTrace) {
      logger.error('获取单词失败', e, stackTrace);
      rethrow;
    }
  }
}
```

### 2. Controller 层

```dart
class WordController extends Notifier<WordState> {
  Future<void> loadWords() async {
    logger.info('开始加载单词');
    
    try {
      final words = await repository.fetchWords();
      logger.info('单词加载成功，共 ${words.length} 个');
      
      state = state.copyWith(words: words);
    } catch (e, stackTrace) {
      logger.error('加载单词失败', e, stackTrace);
      state = state.copyWith(error: e.toString());
    }
  }
}
```

### 3. 初始化流程

```dart
Future<void> initialize() async {
  logger.info('🚀 应用初始化开始');
  
  try {
    logger.debug('正在初始化数据库...');
    await initDatabase();
    logger.info('✅ 数据库初始化完成');
    
    logger.debug('正在加载配置...');
    await loadConfig();
    logger.info('✅ 配置加载完成');
    
    logger.info('🎉 应用初始化成功');
  } catch (e, stackTrace) {
    logger.error('❌ 应用初始化失败', e, stackTrace);
    rethrow;
  }
}
```

## ⚙️ 配置说明

### 日志过滤器

```dart
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // 仅在 Debug 模式输出日志
    return kDebugMode;
  }
}
```

### 日志输出器

```dart
class _AppLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (kDebugMode) {
      for (var line in event.lines) {
        print(line);  // 实际输出到控制台
      }
    }
    
    // 可以扩展：
    // - 写入文件
    // - 发送到远程服务器
    // - 保存到数据库
  }
}
```

## 🔧 自定义配置

在 `app_logger.dart` 中可以调整：

```dart
Logger(
  printer: PrettyPrinter(
    methodCount: 2,        // 调用栈深度
    errorMethodCount: 8,   // 错误时的调用栈深度
    lineLength: 120,       // 每行宽度
    colors: true,          // 彩色输出
    printEmojis: true,     // 表情符号
  ),
);
```

## 💡 最佳实践

### ✅ 推荐做法

1. **使用合适的日志级别**
   ```dart
   logger.debug('开发调试信息');
   logger.info('重要业务流程');
   logger.warning('潜在问题');
   logger.error('错误和异常');
   ```

2. **记录关键操作**
   - 应用启动/初始化
   - 网络请求
   - 数据库操作
   - 用户重要操作

3. **包含上下文信息**
   ```dart
   logger.info('用户登录', {'userId': userId, 'time': DateTime.now()});
   ```

4. **错误时记录堆栈**
   ```dart
   logger.error('操作失败', error, stackTrace);
   ```

### ❌ 避免做法

1. **不要记录敏感信息**
   - 密码
   - Token
   - 个人隐私数据

2. **不要过度日志**
   - 避免在循环中记录
   - 避免记录过大的数据

3. **不要在生产代码中使用 print**
   - 使用 logger 替代
   - print 无法控制输出

## 📚 相关文档

- [详细使用文档](lib/core/utils/README.md)
- [Logger 官方文档](https://pub.dev/packages/logger)

## 🎉 总结

### 改进对比

| 特性 | print | logger |
|------|-------|--------|
| 日志级别 | ❌ | ✅ 6 个级别 |
| 彩色输出 | ❌ | ✅ |
| 时间戳 | ❌ | ✅ |
| 调用栈 | ❌ | ✅ |
| 生产环境控制 | ❌ | ✅ 自动禁用 |
| 格式化输出 | ❌ | ✅ |
| 扩展性 | ❌ | ✅ 可扩展 |

### 已完成

- ✅ 引入 logger 依赖
- ✅ 创建 AppLogger 工具类
- ✅ 替换 DioClient 中的 print
- ✅ 提供专用日志方法（网络、数据库）
- ✅ 仅 Debug 模式输出
- ✅ 完善的文档

### 下一步

可以在其他模块中使用 logger：
- Repository 层
- Controller 层
- Service 层
- 初始化流程

---

日志系统已配置完成，代码更专业、更易维护！🚀
