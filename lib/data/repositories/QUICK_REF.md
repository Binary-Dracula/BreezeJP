# WordRepository 快速参考

## 导入

```dart
import 'package:breeze_jp/data/repositories/word_repository.dart';
```

## 创建实例

```dart
final repository = WordRepository();
```

## 常用方法

### 基础查询

```dart
// 根据 ID 获取
final word = await repository.getWordById(123);

// 根据等级获取
final words = await repository.getWordsByLevel('N5');

// 搜索
final results = await repository.searchWords('学校');

// 获取总数
final count = await repository.getWordCount();
```

### 完整详情

```dart
final detail = await repository.getWordDetail(123);

// 访问数据
detail.word.word              // 单词文本
detail.primaryMeaning         // 主要释义
detail.primaryAudioPath       // 音频路径
detail.meanings               // 所有释义
detail.examples               // 所有例句
```

### 随机学习

```dart
final words = await repository.getRandomWords(
  count: 10,
  jlptLevel: 'N5',
);
```

### 分页查询

```dart
final words = await repository.getAllWords(
  limit: 20,
  offset: 0,
);
```

### 统计信息

```dart
// 各等级数量
final countByLevel = await repository.getWordCountByLevel();
// {'N5': 800, 'N4': 600, ...}
```

## 在 Controller 中使用

```dart
// 创建 Provider
final wordRepositoryProvider = Provider((ref) => WordRepository());

// 使用
class MyController extends Notifier<MyState> {
  Future<void> loadData() async {
    final repo = ref.read(wordRepositoryProvider);
    final words = await repo.getWordsByLevel('N5');
    state = state.copyWith(words: words);
  }
}
```

## 错误处理

```dart
try {
  final words = await repository.getWordsByLevel('N5');
} catch (e) {
  print('加载失败: $e');
}
```

## 所有方法列表

| 方法 | 说明 |
|------|------|
| `getWordById` | 根据 ID 获取单词 |
| `getWordsByLevel` | 根据等级获取单词 |
| `getAllWords` | 获取所有单词 |
| `searchWords` | 搜索单词 |
| `getWordCount` | 获取单词总数 |
| `getWordMeanings` | 获取释义 |
| `getWordAudios` | 获取音频 |
| `getPrimaryWordAudio` | 获取主要音频 |
| `getExampleSentences` | 获取例句 |
| `getExampleAudio` | 获取例句音频 |
| `getWordDetail` | 获取完整详情 |
| `getWordsWithMeanings` | 获取列表及释义 |
| `getRandomWords` | 随机获取 |
| `getWordCountByLevel` | 统计各等级 |
