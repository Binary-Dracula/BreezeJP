# 网络请求层

## 文件说明

### dio_client.dart
Dio 网络请求客户端（单例模式），封装了所有 HTTP 请求方法。

**功能：**
- GET、POST、PUT、DELETE 请求
- 文件下载
- 请求/响应拦截器
- 统一错误处理
- 超时配置
- 请求日志（Debug 模式）

### api_endpoints.dart
API 端点常量管理，集中定义所有 API 路径。

### network_info.dart
网络状态检查工具（需要 connectivity_plus 包）。

## 使用示例

### 1. 基础 GET 请求

```dart
import 'package:breeze_jp/core/network/dio_client.dart';

class WordRepository {
  final _client = DioClient.instance;
  
  Future<List<Word>> fetchWords() async {
    try {
      final response = await _client.get('/words');
      final data = response.data as List;
      return data.map((json) => Word.fromJson(json)).toList();
    } on NetworkException catch (e) {
      throw Exception('获取单词失败: ${e.message}');
    }
  }
}
```

### 2. 带参数的 GET 请求

```dart
Future<List<Word>> fetchWordsByLevel(String level) async {
  try {
    final response = await _client.get(
      '/words',
      queryParameters: {'level': level, 'limit': 20},
    );
    return parseWords(response.data);
  } on NetworkException catch (e) {
    throw Exception(e.message);
  }
}
```

### 3. POST 请求

```dart
Future<void> submitLearningProgress(Map<String, dynamic> data) async {
  try {
    await _client.post(
      '/learning/progress',
      data: data,
    );
  } on NetworkException catch (e) {
    throw Exception('提交失败: ${e.message}');
  }
}
```

### 4. 文件下载

```dart
Future<void> downloadAudio(String filename, String savePath) async {
  try {
    await _client.download(
      '/audio/$filename',
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          print('下载进度: ${(received / total * 100).toStringAsFixed(0)}%');
        }
      },
    );
  } on NetworkException catch (e) {
    throw Exception('下载失败: ${e.message}');
  }
}
```

### 5. 使用 API 端点常量

```dart
import 'package:breeze_jp/core/network/api_endpoints.dart';

// 使用常量
final response = await _client.get(ApiEndpoints.words);

// 替换路径参数
final path = ApiEndpoints.replaceParams(
  ApiEndpoints.wordDetail,
  {'id': '123'},
);
final response = await _client.get(path); // GET /words/123
```

### 6. 在 Riverpod 中使用

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 创建 Provider
final wordRepositoryProvider = Provider((ref) => WordRepository());

class WordRepository {
  final _client = DioClient.instance;
  
  Future<List<Word>> fetchWords() async {
    final response = await _client.get(ApiEndpoints.words);
    return parseWords(response.data);
  }
}

// 在 Controller 中使用
class WordController extends Notifier<WordState> {
  @override
  WordState build() => const WordState();
  
  Future<void> loadWords() async {
    try {
      state = state.copyWith(isLoading: true);
      
      final repository = ref.read(wordRepositoryProvider);
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

### 7. 检查网络状态

```dart
import 'package:breeze_jp/core/network/network_info.dart';

final networkInfo = NetworkInfo();

// 检查是否有网络
if (await networkInfo.isConnected) {
  // 执行网络请求
} else {
  // 显示无网络提示
}

// 监听网络状态变化
networkInfo.onConnectivityChanged.listen((results) {
  if (results.contains(ConnectivityResult.none)) {
    print('网络已断开');
  } else {
    print('网络已连接');
  }
});
```

## 配置说明

### 修改基础 URL

在 `dio_client.dart` 中修改：

```dart
BaseOptions(
  baseUrl: 'https://your-api.com',  // 修改为实际的 API 地址
  // ...
)
```

或在 `api_endpoints.dart` 中修改：

```dart
static const String baseUrl = 'https://your-api.com';
```

### 添加认证 Token

在 `dio_client.dart` 的 `onRequest` 拦截器中：

```dart
onRequest: (options, handler) async {
  // 从本地存储获取 token
  final token = await getToken();
  if (token != null) {
    options.headers['Authorization'] = 'Bearer $token';
  }
  handler.next(options);
},
```

### 自定义超时时间

```dart
final response = await _client.get(
  '/words',
  options: Options(
    receiveTimeout: const Duration(seconds: 30),
  ),
);
```

### 取消请求

```dart
final cancelToken = CancelToken();

// 发起请求
_client.get('/words', cancelToken: cancelToken);

// 取消请求
cancelToken.cancel('用户取消');
```

## 错误处理

所有网络请求都会抛出 `NetworkException`，包含友好的错误信息：

```dart
try {
  final response = await _client.get('/words');
} on NetworkException catch (e) {
  // 显示错误信息
  print(e.message); // "连接超时，请检查网络设置"
}
```

## 注意事项

1. **网络状态检查需要额外依赖**：`network_info.dart` 需要 `connectivity_plus` 包
2. **日志仅在 Debug 模式显示**：使用 `assert()` 确保生产环境不打印日志
3. **错误信息已国际化**：可以根据需要修改错误提示文本
4. **单例模式**：`DioClient.instance` 全局共享一个实例

## 扩展功能

### 添加请求重试

```dart
dio.interceptors.add(
  RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ],
  ),
);
```

### 添加缓存

可以使用 `dio_cache_interceptor` 包添加缓存功能。

### 添加日志记录

可以使用 `pretty_dio_logger` 包美化日志输出。
