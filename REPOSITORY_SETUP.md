# 📦 Repository 层配置完成

## ✅ 已完成的工作

### 1. 创建数据模型

**WordDetail - 单词完整详情模型**
- `lib/data/models/word_detail.dart`
- 组合了 Word、WordMeaning、WordAudio、ExampleSentence
- 提供便捷的访问方法

**ExampleSentenceWithAudio - 例句及音频组合**
- 将例句和音频关联在一起
- 提供音频路径访问方法

### 2. 创建 WordRepository

**文件**: `lib/data/repositories/word_repository.dart`

**功能分类**:

#### 基础查询 (6个方法)
- ✅ `getWordById` - 根据 ID 获取单词
- ✅ `getWordsByLevel` - 根据 JLPT 等级获取单词
- ✅ `getAllWords` - 获取所有单词（支持分页）
- ✅ `searchWords` - 搜索单词
- ✅ `getWordCount` - 获取单词总数

#### 关联数据查询 (5个方法)
- ✅ `getWordMeanings` - 获取单词释义
- ✅ `getWordAudios` - 获取单词音频
- ✅ `getPrimaryWordAudio` - 获取主要音频
- ✅ `getExampleSentences` - 获取例句
- ✅ `getExampleAudio` - 获取例句音频

#### 组合查询 (2个方法)
- ✅ `getWordDetail` - 获取单词完整详情
- ✅ `getWordsWithMeanings` - 获取单词列表及主要释义

#### 高级查询 (2个方法)
- ✅ `getRandomWords` - 随机获取单词
- ✅ `getWordCountByLevel` - 统计各等级单词数量

**总计**: 15 个方法，覆盖所有常用场景

### 3. 创建文档

- `lib/data/repositories/README.md` - 详细使用文档
- `REPOSITORY_SETUP.md` - 配置总结（本文件）

## 🎯 核心特性

### 数据访问封装
- ✅ 所有数据库操作都封装在 Repository 中
- ✅ 返回类型安全的 Model 对象
- ✅ 统一的错误处理
- ✅ 完整的日志记录

### 便捷的组合查询
- ✅ `WordDetail` 一次性获取所有相关数据
- ✅ `ExampleSentenceWithAudio` 自动关联例句和音频
- ✅ 提供便捷的访问方法（如 `primaryMeaning`、`primaryAudioPath`）

### 性能优化
- ✅ 支持分页查询（limit、offset）
- ✅ 使用 JOIN 减少查询次数
- ✅ 合理的索引使用

## 📖 快速使用

### 基础查询

```dart
import 'package:breeze_jp/data/repositories/word_repository.dart';

final repository = WordRepository();

// 获取单词
final word = await repository.getWordById(123);

// 获取 N5 单词
final n5Words = await repository.getWordsByLevel('N5');

// 搜索单词
final results = await repository.searchWords('学校');
```

### 获取完整详情

```dart
final detail = await repository.getWordDetail(123);

if (detail != null) {
  print('单词: ${detail.word.word}');
  print('主要释义: ${detail.primaryMeaning}');
  print('音频路径: ${detail.primaryAudioPath}');
  
  // 遍历例句
  for (final example in detail.examples) {
    print('例句: ${example.sentence.sentenceJp}');
    print('翻译: ${example.sentence.translationCn}');
    print('音频: ${example.audioPath}');
  }
}
```

### 在 Controller 中使用

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 创建 Provider
final wordRepositoryProvider = Provider((ref) => WordRepository());

// 在 Controller 中使用
class WordController extends Notifier<WordState> {
  @override
  WordState build() => const WordState();
  
  Future<void> loadWords(String level) async {
    try {
      state = state.copyWith(isLoading: true);
      
      final repository = ref.read(wordRepositoryProvider);
      final words = await repository.getWordsByLevel(level);
      
      state = state.copyWith(
        isLoading: false,
        words: words,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
```

### 随机学习

```dart
// 随机获取 10 个 N5 单词
final words = await repository.getRandomWords(
  count: 10,
  jlptLevel: 'N5',
);
```

### 统计信息

```dart
// 获取各等级单词数量
final countByLevel = await repository.getWordCountByLevel();
// 结果: {'N5': 800, 'N4': 600, 'N3': 1200, ...}

// 获取总数
final totalCount = await repository.getWordCount();
```

## 📊 数据模型

### Word - 单词基本信息
```dart
class Word {
  final int id;
  final String word;              // 单词文本
  final String? furigana;         // 假名
  final String? romaji;           // 罗马音
  final String? jlptLevel;        // JLPT 等级
  final String? partOfSpeech;     // 词性
  final String? pitchAccent;      // 音调
}
```

### WordDetail - 完整详情
```dart
class WordDetail {
  final Word word;                              // 单词基本信息
  final List<WordMeaning> meanings;             // 所有释义
  final List<WordAudio> audios;                 // 所有音频
  final List<ExampleSentenceWithAudio> examples; // 所有例句
  
  // 便捷访问
  String? get primaryMeaning;        // 主要释义
  List<String> get allMeanings;      // 所有释义文本
  String? get primaryAudioFilename;  // 主要音频文件名
  String? get primaryAudioPath;      // 主要音频路径
}
```

### ExampleSentenceWithAudio - 例句及音频
```dart
class ExampleSentenceWithAudio {
  final ExampleSentence sentence;  // 例句
  final ExampleAudio? audio;       // 音频（可选）
  
  String? get audioPath;           // 音频路径
}
```

## 🔍 查询示例

### 1. 分页查询
```dart
final words = await repository.getAllWords(
  limit: 20,
  offset: 0,
);
```

### 2. 条件查询
```dart
// 按等级
final n5Words = await repository.getWordsByLevel('N5');

// 搜索
final results = await repository.searchWords('学校');
```

### 3. 关联查询
```dart
// 获取单词的释义
final meanings = await repository.getWordMeanings(wordId);

// 获取单词的例句
final examples = await repository.getExampleSentences(wordId);
```

### 4. 组合查询
```dart
// 一次性获取所有数据
final detail = await repository.getWordDetail(wordId);

// 获取列表及主要释义（优化的 JOIN 查询）
final wordsWithMeanings = await repository.getWordsWithMeanings(
  jlptLevel: 'N5',
  limit: 20,
);
```

## 📝 日志输出

Repository 自动记录所有操作：

```
🐛 DEBUG | 💾 DB[SELECT] words
Data: {jlpt_level: N5}

💡 INFO | 获取单词详情: 123

🐛 DEBUG | 💾 DB[SELECT] word_meanings
Data: {word_id: 123}

🐛 DEBUG | 💾 DB[SELECT] example_sentences
Data: {word_id: 123}

💡 INFO | 单词详情获取成功: 学校 (2个释义, 3个例句)
```

## 🎨 使用场景

### 场景 1: 单词列表页面
```dart
class WordListController extends Notifier<WordListState> {
  Future<void> loadWords(String level) async {
    final repository = ref.read(wordRepositoryProvider);
    final words = await repository.getWordsByLevel(level);
    state = state.copyWith(words: words);
  }
}
```

### 场景 2: 单词详情页面
```dart
class WordDetailController extends Notifier<WordDetailState> {
  Future<void> loadDetail(int wordId) async {
    final repository = ref.read(wordRepositoryProvider);
    final detail = await repository.getWordDetail(wordId);
    state = state.copyWith(detail: detail);
  }
}
```

### 场景 3: 学习模式
```dart
class LearnController extends Notifier<LearnState> {
  Future<void> startLearning(String level) async {
    final repository = ref.read(wordRepositoryProvider);
    final words = await repository.getRandomWords(
      count: 10,
      jlptLevel: level,
    );
    state = state.copyWith(words: words);
  }
}
```

### 场景 4: 搜索功能
```dart
class SearchController extends Notifier<SearchState> {
  Future<void> search(String keyword) async {
    final repository = ref.read(wordRepositoryProvider);
    final results = await repository.searchWords(keyword);
    state = state.copyWith(results: results);
  }
}
```

## 🔧 扩展指南

### 添加新查询方法

```dart
class WordRepository {
  // 添加按词性查询
  Future<List<Word>> getWordsByPartOfSpeech(String pos) async {
    logger.database('SELECT', table: 'words', data: {'part_of_speech': pos});
    
    final db = await _db;
    final results = await db.query(
      'words',
      where: 'part_of_speech = ?',
      whereArgs: [pos],
    );
    
    return results.map((map) => Word.fromMap(map)).toList();
  }
}
```

### 创建新 Repository

```dart
// lib/data/repositories/learning_record_repository.dart
class LearningRecordRepository {
  Future<Database> get _db async => await AppDatabase.instance.database;
  
  Future<void> saveRecord(LearningRecord record) async {
    logger.database('INSERT', table: 'learning_records');
    
    final db = await _db;
    await db.insert('learning_records', record.toMap());
  }
}
```

## 💡 最佳实践

### ✅ 推荐做法

1. **通过 Provider 注入**
   ```dart
   final wordRepositoryProvider = Provider((ref) => WordRepository());
   ```

2. **统一错误处理**
   ```dart
   try {
     final words = await repository.getWordsByLevel('N5');
   } catch (e) {
     // 处理错误
   }
   ```

3. **使用组合查询**
   ```dart
   // 好：一次查询获取所有数据
   final detail = await repository.getWordDetail(wordId);
   
   // 避免：多次查询
   final word = await repository.getWordById(wordId);
   final meanings = await repository.getWordMeanings(wordId);
   final examples = await repository.getExampleSentences(wordId);
   ```

4. **分页加载大量数据**
   ```dart
   final words = await repository.getAllWords(
     limit: 20,
     offset: page * 20,
   );
   ```

### ❌ 避免做法

1. ❌ 直接在 UI 中访问数据库
2. ❌ 在 Repository 中处理业务逻辑
3. ❌ 返回 Map 而不是 Model 对象
4. ❌ 忽略错误处理

## 📚 相关文档

- [详细使用文档](lib/data/repositories/README.md)
- [数据库架构](.kiro/steering/database.md)
- [项目架构](.kiro/steering/structure.md)

## 🎉 总结

### 已完成
- ✅ WordRepository 完整实现（15个方法）
- ✅ WordDetail 组合模型
- ✅ ExampleSentenceWithAudio 组合模型
- ✅ 完整的日志记录
- ✅ 统一的错误处理
- ✅ 详细的文档

### 特点
- 🎯 类型安全 - 返回 Model 对象
- 📝 日志完整 - 记录所有操作
- 🚀 性能优化 - 支持分页和 JOIN
- 🛡️ 错误处理 - 统一的异常处理
- 📖 文档完善 - 详细的使用说明

### 下一步
可以基于 WordRepository 创建：
- Controller 层（使用 Riverpod）
- UI 页面（单词列表、详情、学习等）
- 其他 Repository（学习记录、用户进度等）

---

Repository 层已完成，为应用提供了稳定可靠的数据访问接口！🚀
