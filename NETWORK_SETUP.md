# 🌐 网络请求层配置完成

## ✅ 已完成的工作

### 1. 添加依赖
在 `pubspec.yaml` 中添加了 `dio: ^5.7.0`

### 2. 创建网络请求层文件

```
lib/core/network/
├── dio_client.dart        # Dio 客户端（单例模式）
├── api_endpoints.dart     # API 端点常量管理
├── network_info.dart      # 网络状态检查（需要 connectivity_plus）
└── README.md              # 详细使用文档
```

### 3. 创建示例 Repository
`lib/data/repositories/example_api_repository.dart` - 演示如何使用网络请求

## 🎯 核心功能

### DioClient 特性
- ✅ 单例模式，全局共享
- ✅ 支持 GET、POST、PUT、DELETE 请求
- ✅ 支持文件下载（带进度回调）
- ✅ 请求/响应/错误拦截器
- ✅ 统一错误处理
- ✅ 超时配置（连接、发送、接收）
- ✅ 请求日志（仅 Debug 模式）
- ✅ 友好的错误提示

### 错误处理
所有网络错误都会转换为 `NetworkException`，包含友好的中文提示：
- 连接超时
- 网络连接失败
- 401 未授权
- 404 资源不存在
- 500 服务器错误
- 等等...

## 📖 快速开始

### 1. 基础 GET 请求

```dart
import 'package:breeze_jp/core/network/dio_client.dart';

final client = DioClient.instance;

try {
  final response = await client.get('/words');
  print(response.data);
} on NetworkException catch (e) {
  print('错误: ${e.message}');
}
```

### 2. 带参数的请求

```dart
final response = await client.get(
  '/words',
  queryParameters: {
    'level': 'N5',
    'limit': 20,
  },
);
```

### 3. POST 请求

```dart
await client.post(
  '/learning/progress',
  data: {
    'word_id': 123,
    'is_correct': true,
  },
);
```

### 4. 文件下载

```dart
await client.download(
  '/audio/word_123.mp3',
  '/path/to/save/word_123.mp3',
  onReceiveProgress: (received, total) {
    print('进度: ${(received / total * 100).toStringAsFixed(0)}%');
  },
);
```

### 5. 在 Repository 中使用

```dart
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

### 6. 在 Riverpod Controller 中使用

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

## ⚙️ 配置说明

### 修改基础 URL

在 `lib/core/network/dio_client.dart` 中修改：

```dart
BaseOptions(
  baseUrl: 'https://your-api.com',  // 修改为实际的 API 地址
  // ...
)
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
// 全局配置（在 BaseOptions 中）
connectTimeout: const Duration(seconds: 10),
receiveTimeout: const Duration(seconds: 10),

// 单个请求配置
final response = await client.get(
  '/words',
  options: Options(
    receiveTimeout: const Duration(seconds: 30),
  ),
);
```

## 📁 API 端点管理

使用 `ApiEndpoints` 类集中管理所有 API 路径：

```dart
// 定义端点
class ApiEndpoints {
  static const String words = '/words';
  static const String wordDetail = '/words/{id}';
}

// 使用端点
final response = await client.get(ApiEndpoints.words);

// 替换路径参数
final path = ApiEndpoints.replaceParams(
  ApiEndpoints.wordDetail,
  {'id': '123'},
);
final response = await client.get(path); // GET /words/123
```

## 🔌 网络状态检查（可选）

如果需要检查网络状态，需要添加 `connectivity_plus` 依赖：

```yaml
dependencies:
  connectivity_plus: ^6.1.2
```

然后使用 `NetworkInfo`：

```dart
import 'package:breeze_jp/core/network/network_info.dart';

final networkInfo = NetworkInfo();

// 检查网络
if (await networkInfo.isConnected) {
  // 执行网络请求
} else {
  // 显示无网络提示
}

// 监听网络变化
networkInfo.onConnectivityChanged.listen((results) {
  if (results.contains(ConnectivityResult.none)) {
    print('网络已断开');
  }
});
```

## 🎨 使用场景示例

### 场景 1: 从服务器同步单词数据

```dart
class WordSyncService {
  final _client = DioClient.instance;
  
  Future<void> syncWords() async {
    try {
      final response = await _client.get('/words/sync');
      final words = parseWords(response.data);
      
      // 保存到本地数据库
      await saveToDatabase(words);
    } on NetworkException catch (e) {
      throw Exception('同步失败: ${e.message}');
    }
  }
}
```

### 场景 2: 下载音频文件

```dart
class AudioDownloadService {
  final _client = DioClient.instance;
  
  Future<void> downloadWordAudio(String wordId) async {
    final savePath = await getAudioSavePath(wordId);
    
    await _client.download(
      '/audio/word_$wordId.mp3',
      savePath,
      onReceiveProgress: (received, total) {
        final progress = (received / total * 100).toStringAsFixed(0);
        print('下载进度: $progress%');
      },
    );
  }
}
```

### 场景 3: 上传学习记录

```dart
class LearningRecordService {
  final _client = DioClient.instance;
  
  Future<void> uploadProgress(LearningRecord record) async {
    await _client.post(
      '/learning/records',
      data: record.toJson(),
    );
  }
}
```

## 📚 更多功能

### 请求取消

```dart
final cancelToken = CancelToken();

// 发起请求
client.get('/words', cancelToken: cancelToken);

// 取消请求
cancelToken.cancel('用户取消');
```

### 上传进度

```dart
await client.post(
  '/upload',
  data: formData,
  onSendProgress: (sent, total) {
    print('上传进度: ${(sent / total * 100).toStringAsFixed(0)}%');
  },
);
```

### FormData 上传

```dart
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(filePath),
  'name': 'example',
});

await client.post('/upload', data: formData);
```

## ⚠️ 注意事项

1. **网络状态检查是可选的**：`network_info.dart` 需要额外安装 `connectivity_plus` 包
2. **日志仅在 Debug 模式显示**：使用 `assert()` 确保生产环境不打印敏感信息
3. **错误处理要完善**：所有网络请求都应该用 try-catch 包裹
4. **基础 URL 需要配置**：记得修改 `dio_client.dart` 中的 `baseUrl`
5. **Token 管理**：如果需要认证，在拦截器中添加 token 逻辑

## 🚀 下一步

1. 根据实际 API 修改 `baseUrl`
2. 在 `api_endpoints.dart` 中添加实际的 API 端点
3. 创建具体的 Repository 类
4. 在 Controller 中调用 Repository
5. 如需网络状态检查，添加 `connectivity_plus` 依赖

## 📖 参考文档

- [Dio 官方文档](https://pub.dev/packages/dio)
- [示例代码](lib/data/repositories/example_api_repository.dart)
- [详细使用说明](lib/core/network/README.md)

---

网络请求层已配置完成，可以开始使用了！🎉
