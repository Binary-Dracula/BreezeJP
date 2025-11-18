# Repository 层

Repository 层负责封装所有数据访问逻辑，包括本地数据库查询和网络请求。

## 架构说明

```
Controller/ViewModel
       ↓
   Repository  ← 统一的数据访问接口
    ↙     ↘
本地数据库  网络API
```

## 已实现的 Repository

### WordRepository - 单词数据仓库

负责所有与单词相关的数据库操作。

#### 功能列表

**基础查询**
- `getWordById(int id)` - 根据 ID 获取单词
- `getWordsByLevel(String jlptLevel)` - 根据 JLPT 等级获取单词列表
- `getAllWords({int? limit, int? offset})` - 获取所有单词（支持分页）
- `searchWords(String keyword)` - 搜索单词
- `getWordCount({String? jlptLevel})` - 获取单词总数

**释义查询**
- `getWordMeanings(int wordId)` - 获取单词的所有释义

**音频查询**
- `getWordAudios(int wordId)` - 获取单词的所有音频
- `getPrimaryWordAudio(int wordId)` - 获取单词的主要音频

**例句查询**
- `getExampleSentences(int wordId)` - 获取单词的所有例句
- `getExampleAudio(int exampleId)` - 获取例句的音频

**组合查询**
- `getWordDetail(int wordId)` - 获取单词完整详情（包含释义、音频、例句）
- `getWordsWithMeanings({...})` - 获取单词列表及主要释义

**随机查询**
- `getRandomWords({int count, String? jlptLevel})` - 随机获取单词

**统计查询**
- `getWordCountByLevel()` - 获取各 JLPT 等级的单词数量

## 使用示例

### 1. 基础查询

```dart
import 'package:breeze_jp/data/repositories/word_repository.dart';

final repository = WordRepository();

// 获取单词
final word = await repository.getWordById(123);
print('单词: ${word?.word}');

// 获取 N5 单词列表
final n5Words = await repository.getWordsByLevel('N5');
print('N5 单词数量: ${n5Words.length}');

// 搜索单词
final results = await repository.searchWords('学校');
print('搜索结果: ${results.length} 个');
```

### 2. 获取完整单词详情

```dart
final detail = await repository.getWordDetail(123);

if (detail != null) {
  print('单词: ${detail.word.word}');
  print('假名: ${detail.word.furigana}');
  print('罗马音: ${detail.word.romaji}');
  
  // 释义
  print('释义:');
  for (final meaning in detail.meanings) {
    print('  ${meaning.definitionOrder}. ${meaning.meaningCn}');
  }
  
  // 音频
  if (detail.primaryAudioPath != null) {
    print('音频: ${detail.primaryAudioPath}');
  }
  
  // 例句
  print('例句:');
  for (final example in detail.examples) {
    print('  日文: ${example.sentence.sentenceJp}');
    print('  中文: ${example.sentence.translationCn}');
    if (example.audioPath != null) {
      print('  音频: ${example.audioPath}');
    }
  }
}
```

### 3. 在 Riverpod Controller 中使用

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:breeze_jp/data/repositories/word_repository.dart';

// 创建 Repository Provider
final wordRepositoryProvider = Provider((ref) => WordRepository());

// 在 Controller 中使用
class WordListController extends Notifier<WordListState> {
  @override
  WordListState build() => const WordListState();
  
  Future<void> loadWords(String jlptLevel) async {
    try {
      state = state.copyWith(isLoading: true);
      
      final repository = ref.read(wordRepositoryProvider);
      final words = await repository.getWordsByLevel(jlptLevel);
      
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

### 4. 分页加载

```dart
Future<void> loadMoreWords() async {
  final repository = WordRepository();
  
  final currentPage = 0;
  final pageSize = 20;
  
  final words = await repository.getAllWords(
    limit: pageSize,
    offset: currentPage * pageSize,
  );
  
  print('加载了 ${words.length} 个单词');
}
```

### 5. 随机学习

```dart
Future<void> startRandomLearning() async {
  final repository = WordRepository();
  
  // 随机获取 10 个 N5 单词
  final words = await repository.getRandomWords(
    count: 10,
    jlptLevel: 'N5',
  );
  
  for (final word in words) {
    print('学习单词: ${word.word}');
  }
}
```

### 6. 统计信息

```dart
Future<void> showStatistics() async {
  final repository = WordRepository();
  
  // 获取各等级单词数量
  final countByLevel = await repository.getWordCountByLevel();
  
  print('单词统计:');
  countByLevel.forEach((level, count) {
    print('  $level: $count 个');
  });
  
  // 获取总数
  final totalCount = await repository.getWordCount();
  print('总计: $totalCount 个');
}
```

### 7. 列表显示（带主要释义）

```dart
Future<void> displayWordList() async {
  final repository = WordRepository();
  
  final wordsWithMeanings = await repository.getWordsWithMeanings(
    jlptLevel: 'N5',
    limit: 20,
  );
  
  for (final row in wordsWithMeanings) {
    final word = Word.fromMap(row);
    final meaning = row['primary_meaning'] as String?;
    
    print('${word.word} - $meaning');
  }
}
```

## 数据模型

### Word - 单词基本信息
```dart
class Word {
  final int id;
  final String word;
  final String? furigana;
  final String? romaji;
  final String? jlptLevel;
  final String? partOfSpeech;
  final String? pitchAccent;
}
```

### WordDetail - 单词完整详情
```dart
class WordDetail {
  final Word word;
  final List<WordMeaning> meanings;
  final List<WordAudio> audios;
  final List<ExampleSentenceWithAudio> examples;
  
  // 便捷方法
  String? get primaryMeaning;
  List<String> get allMeanings;
  String? get primaryAudioFilename;
  String? get primaryAudioPath;
}
```

### ExampleSentenceWithAudio - 例句及音频
```dart
class ExampleSentenceWithAudio {
  final ExampleSentence sentence;
  final ExampleAudio? audio;
  
  String? get audioPath;
}
```

## 错误处理

所有 Repository 方法都会记录日志并重新抛出异常，调用方需要处理：

```dart
try {
  final words = await repository.getWordsByLevel('N5');
  // 处理成功
} catch (e) {
  // 处理错误
  print('加载失败: $e');
}
```

## 日志记录

Repository 自动记录所有数据库操作：

```
🐛 DEBUG | 💾 DB[SELECT] words
Data: {jlpt_level: N5}

💡 INFO | 获取单词详情: 123
💡 INFO | 单词详情获取成功: 学校 (2个释义, 3个例句)
```

## 性能优化建议

1. **使用分页** - 大量数据时使用 `limit` 和 `offset`
2. **缓存结果** - 在 Controller 层缓存常用数据
3. **批量查询** - 使用 `getWordsWithMeanings` 而不是多次单独查询
4. **索引优化** - 数据库表已有适当索引

## 扩展 Repository

### 添加新方法

```dart
class WordRepository {
  // 添加自定义查询
  Future<List<Word>> getWordsByPartOfSpeech(String pos) async {
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
  
  Future<void> saveLearningRecord(LearningRecord record) async {
    final db = await _db;
    await db.insert('learning_records', record.toMap());
  }
}
```

## 最佳实践

1. ✅ 所有数据库操作都通过 Repository
2. ✅ Repository 返回 Model 对象，不返回 Map
3. ✅ 使用日志记录所有操作
4. ✅ 统一错误处理
5. ✅ 提供便捷的组合查询方法
6. ✅ 在 Controller 中通过 Provider 注入 Repository

## 待实现的 Repository

- `LearningRecordRepository` - 学习记录
- `ReviewRepository` - 复习记录
- `UserProgressRepository` - 用户进度
- `SettingsRepository` - 应用设置

---

Repository 层是数据访问的唯一入口，确保数据操作的一致性和可维护性。
