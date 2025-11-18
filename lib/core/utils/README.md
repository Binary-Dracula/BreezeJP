# 工具类库

## AppLogger - 应用日志工具

统一的日志管理工具，基于 `logger` 包封装。

### 特性

- ✅ 仅在 Debug 模式输出日志
- ✅ 彩色输出，易于区分
- ✅ 表情符号标识不同日志级别
- ✅ 显示方法调用栈
- ✅ 时间戳显示
- ✅ 专门的网络和数据库日志方法

### 日志级别

| 级别 | 方法 | 表情 | 用途 |
|------|------|------|------|
| Trace | `logger.trace()` | 🔍 | 追踪信息（最详细） |
| Debug | `logger.debug()` | 🐛 | 调试信息 |
| Info | `logger.info()` | 💡 | 一般信息 |
| Warning | `logger.warning()` | ⚠️ | 警告信息 |
| Error | `logger.error()` | ❌ | 错误信息 |
| Fatal | `logger.fatal()` | 💀 | 致命错误 |

### 基础使用

```dart
import 'package:breeze_jp/core/utils/app_logger.dart';

// 使用全局实例
logger.debug('这是调试信息');
logger.info('这是一般信息');
logger.warning('这是警告信息');
logger.error('这是错误信息');
```

### 带错误和堆栈信息

```dart
try {
  // 一些可能出错的代码
} catch (e, stackTrace) {
  logger.error('操作失败', e, stackTrace);
}
```

### 网络请求日志

```dart
// 记录请求
logger.network('GET', '/api/words', data: {'level': 'N5'});

// 记录响应
logger.networkResponse(200, '/api/words', data: responseData);

// 记录错误
logger.networkError('GET', '/api/words', error);
```

### 数据库操作日志

```dart
// 记录数据库操作
logger.database('INSERT', table: 'words', data: wordData);
logger.database('SELECT', table: 'words');
logger.database('UPDATE', table: 'words', data: {'id': 123});
logger.database('DELETE', table: 'words');
```

### 在不同场景中使用

#### 1. 在 Repository 中

```dart
class WordRepository {
  Future<List<Word>> fetchWords() async {
    logger.debug('开始获取单词列表');
    
    try {
      final db = await AppDatabase.instance.database;
      final results = await db.query('words');
      
      logger.database('SELECT', table: 'words');
      logger.info('成功获取 ${results.length} 个单词');
      
      return results.map((map) => Word.fromMap(map)).toList();
    } catch (e, stackTrace) {
      logger.error('获取单词列表失败', e, stackTrace);
      rethrow;
    }
  }
}
```

#### 2. 在 Controller 中

```dart
class WordController extends Notifier<WordState> {
  Future<void> loadWords() async {
    logger.info('开始加载单词');
    
    try {
      state = state.copyWith(isLoading: true);
      
      final repository = WordRepository();
      final words = await repository.fetchWords();
      
      state = state.copyWith(
        isLoading: false,
        words: words,
      );
      
      logger.info('单词加载成功，共 ${words.length} 个');
    } catch (e, stackTrace) {
      logger.error('加载单词失败', e, stackTrace);
      
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
```

#### 3. 在网络请求中

DioClient 已经自动集成了日志，无需手动添加。

#### 4. 在初始化流程中

```dart
class SplashController extends Notifier<SplashState> {
  Future<void> initialize(BuildContext context) async {
    logger.info('🚀 应用初始化开始');
    
    try {
      logger.debug('正在初始化数据库...');
      await _initializeDatabase(l10n);
      logger.info('✅ 数据库初始化完成');
      
      logger.debug('正在加载配置...');
      await _loadConfig();
      logger.info('✅ 配置加载完成');
      
      logger.info('🎉 应用初始化成功');
    } catch (e, stackTrace) {
      logger.error('❌ 应用初始化失败', e, stackTrace);
      rethrow;
    }
  }
}
```

### 日志输出示例

```
💡 INFO 2024-11-18 21:00:00.123 | 🚀 应用初始化开始
🐛 DEBUG 2024-11-18 21:00:00.234 | 正在初始化数据库...
💾 DB[COPY] breeze_jp.sqlite
✅ INFO 2024-11-18 21:00:01.456 | 数据库初始化完成
🌐 [GET] https://api.example.com/words
✅ [200] https://api.example.com/words
Response: {...}
💡 INFO 2024-11-18 21:00:02.789 | 单词加载成功，共 100 个
```

### 配置选项

在 `app_logger.dart` 中可以自定义配置：

```dart
Logger(
  filter: _AppLogFilter(),
  printer: PrettyPrinter(
    methodCount: 2,        // 显示的方法调用栈数量
    errorMethodCount: 8,   // 错误时显示的方法调用栈数量
    lineLength: 120,       // 每行的宽度
    colors: true,          // 彩色输出
    printEmojis: true,     // 打印表情符号
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  output: _AppLogOutput(),
);
```

### 生产环境

日志仅在 Debug 模式输出，Release 模式下不会有任何日志输出，不影响性能。

### 扩展功能

可以在 `_AppLogOutput` 中添加其他输出方式：

```dart
class _AppLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // 输出到控制台
    if (kDebugMode) {
      for (var line in event.lines) {
        print(line);
      }
    }
    
    // 可以添加：
    // 1. 写入文件
    // _writeToFile(event.lines);
    
    // 2. 发送到远程日志服务器
    // _sendToServer(event.lines);
    
    // 3. 保存到数据库
    // _saveToDatabase(event.lines);
  }
}
```

### 最佳实践

1. ✅ 使用合适的日志级别
   - `debug` - 开发调试信息
   - `info` - 重要的业务流程
   - `warning` - 潜在问题
   - `error` - 错误和异常

2. ✅ 记录关键操作
   - 应用启动/初始化
   - 网络请求
   - 数据库操作
   - 用户重要操作

3. ✅ 包含上下文信息
   ```dart
   logger.info('用户登录成功', {'userId': userId, 'timestamp': DateTime.now()});
   ```

4. ✅ 错误时记录堆栈
   ```dart
   logger.error('操作失败', error, stackTrace);
   ```

5. ❌ 避免记录敏感信息
   - 密码
   - Token
   - 个人隐私数据

6. ❌ 避免过度日志
   - 不要在循环中记录日志
   - 不要记录过大的数据

### 与 print 的对比

| 特性 | print | logger |
|------|-------|--------|
| 日志级别 | ❌ | ✅ |
| 彩色输出 | ❌ | ✅ |
| 时间戳 | ❌ | ✅ |
| 调用栈 | ❌ | ✅ |
| 生产环境控制 | ❌ | ✅ |
| 格式化输出 | ❌ | ✅ |
| 扩展性 | ❌ | ✅ |

### 迁移指南

将现有的 `print` 替换为 `logger`：

```dart
// 之前
print('调试信息');
print('错误: $error');

// 之后
logger.debug('调试信息');
logger.error('错误', error);
```

---

使用 AppLogger 让你的日志更专业、更易读、更易维护！
