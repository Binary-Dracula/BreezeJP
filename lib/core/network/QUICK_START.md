# Dio 网络请求快速参考

## 🚀 基础使用

### 导入
```dart
import 'package:breeze_jp/core/network/dio_client.dart';
import 'package:breeze_jp/core/network/api_endpoints.dart';
```

### 获取客户端实例
```dart
final client = DioClient.instance;
```

## 📡 请求方法

### GET 请求
```dart
// 简单 GET
final response = await client.get('/words');

// 带查询参数
final response = await client.get(
  '/words',
  queryParameters: {'level': 'N5', 'limit': 20},
);
```

### POST 请求
```dart
await client.post(
  '/learning/progress',
  data: {
    'word_id': 123,
    'is_correct': true,
  },
);
```

### PUT 请求
```dart
await client.put(
  '/user/profile',
  data: {'name': 'John'},
);
```

### DELETE 请求
```dart
await client.delete('/words/123');
```

### 文件下载
```dart
await client.download(
  '/audio/word.mp3',
  '/path/to/save.mp3',
  onReceiveProgress: (received, total) {
    print('${(received / total * 100).toStringAsFixed(0)}%');
  },
);
```

## 🛡️ 错误处理

```dart
try {
  final response = await client.get('/words');
  // 处理成功响应
} on NetworkException catch (e) {
  // 处理网络错误
  print('错误: ${e.message}');
}
```

## 📋 API 端点管理

### 定义端点
```dart
// lib/core/network/api_endpoints.dart
class ApiEndpoints {
  static const String words = '/words';
  static const String wordDetail = '/words/{id}';
}
```

### 使用端点
```dart
// 直接使用
await client.get(ApiEndpoints.words);

// 替换参数
final path = ApiEndpoints.replaceParams(
  ApiEndpoints.wordDetail,
  {'id': '123'},
);
await client.get(path); // GET /words/123
```

## 🏗️ Repository 模式

```dart
class WordRepository {
  final _client = DioClient.instance;
  
  Future<List<Word>> fetchWords() async {
    try {
      final response = await _client.get(ApiEndpoints.words);
      return parseWords(response.data);
    } on NetworkException catch (e) {
      throw Exception('获取失败: ${e.message}');
    }
  }
}
```

## 🎮 在 Controller 中使用

```dart
class WordController extends Notifier<WordState> {
  @override
  WordState build() => const WordState();
  
  Future<void> loadWords() async {
    try {
      state = state.copyWith(isLoading: true);
      
      final repository = WordRepository();
      final words = await repository.fetchWords();
      
      state = state.copyWith(
        isLoading: false,
        words: words,
      );
    } on NetworkException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    }
  }
}
```

## ⚙️ 高级功能

### 自定义超时
```dart
await client.get(
  '/words',
  options: Options(
    receiveTimeout: const Duration(seconds: 30),
  ),
);
```

### 取消请求
```dart
final cancelToken = CancelToken();

client.get('/words', cancelToken: cancelToken);

// 取消
cancelToken.cancel('用户取消');
```

### 自定义请求头
```dart
await client.get(
  '/words',
  options: Options(
    headers: {'Custom-Header': 'value'},
  ),
);
```

## 🔧 配置

### 修改基础 URL
在 `dio_client.dart` 中：
```dart
BaseOptions(
  baseUrl: 'https://your-api.com',
  // ...
)
```

### 添加 Token
在 `dio_client.dart` 的拦截器中：
```dart
onRequest: (options, handler) async {
  final token = await getToken();
  if (token != null) {
    options.headers['Authorization'] = 'Bearer $token';
  }
  handler.next(options);
},
```

## 📝 常见错误信息

| 错误 | 说明 |
|------|------|
| 连接超时，请检查网络设置 | 网络连接超时 |
| 未授权，请重新登录 | 401 错误 |
| 请求的资源不存在 | 404 错误 |
| 服务器内部错误 | 500 错误 |
| 网络连接失败 | 无网络或网络不可达 |

## 💡 最佳实践

1. ✅ 所有网络请求都用 try-catch 包裹
2. ✅ 在 Repository 层封装网络请求
3. ✅ 使用 ApiEndpoints 管理 API 路径
4. ✅ 在 Controller 中处理业务逻辑
5. ✅ 统一错误处理和提示
6. ✅ 敏感信息不要硬编码

## 🔗 相关文档

- [详细文档](README.md)
- [示例代码](../../data/repositories/example_api_repository.dart)
- [Dio 官方文档](https://pub.dev/packages/dio)
