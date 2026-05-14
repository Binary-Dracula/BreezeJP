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
- ✅ **分类日志方法** - 按模块分类的日志输出
- ✅ **格式化工具** - 统一的数据格式化

### 日志级别

| 级别    | 方法               | 表情 | 用途               |
| ------- | ------------------ | ---- | ------------------ |
| Trace   | `logger.trace()`   | 🔍   | 追踪信息（最详细） |
| Debug   | `logger.debug()`   | 🐛   | 调试信息           |
| Info    | `logger.info()`    | 💡   | 一般信息           |
| Warning | `logger.warning()` | ⚠️   | 警告信息           |
| Error   | `logger.error()`   | ❌   | 错误信息           |
| Fatal   | `logger.fatal()`   | 💀   | 致命错误           |

### 日志分类

| 分类  | 前缀      | 用途       | 使用场景                          |
| ----- | --------- | ---------- | --------------------------------- |
| LEARN | `[LEARN]` | 学习流程   | 会话开始/结束、单词加载、答案提交 |
| DB    | `[DB]`    | 数据库操作 | CRUD 操作、查询、事务             |
| AUDIO | `[AUDIO]` | 音频状态   | 播放、暂停、停止、错误            |
| ALGO  | `[ALGO]`  | 算法计算   | SRS 输入/输出、参数更新           |

---

## 基础使用

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

---

## 分类日志方法

### 学习流程日志 [LEARN]

用于记录用户学习会话的完整流程。

```dart
// 记录学习会话开始
logger.learnSessionStart(userId: 1);
// 输出: [LEARN] session_start: userId=1, timestamp=2024-11-27T10:30:00+08:00

// 记录单词加载
logger.learnWordsLoaded(
  reviewCount: 5,
  newCount: 10,
  totalCount: 15,
);
// 输出: [LEARN] words_loaded: review=5, new=10, total=15

// 记录单词查看
logger.learnWordView(
  wordId: 123,
  position: 1,
  total: 15,
);
// 输出: [LEARN] word_view: wordId=123, position=1/15

// 记录答案提交
logger.learnAnswerSubmit(
  wordId: 123,
  rating: 'good',
  newInterval: 2.5,
  newEaseFactor: 2.6,
);
// 输出: [LEARN] answer_submit: wordId=123, rating=good, interval=2.50, ef=2.600

// 记录学习会话结束
logger.learnSessionEnd(
  durationMs: 330000,  // 5分30秒
  learnedCount: 10,
  reviewedCount: 5,
);
// 输出: [LEARN] session_end: duration=5m 30s, learned=10, reviewed=5

// 记录状态迁移
logger.stateChange(
  scope: 'word',
  userId: 1,
  itemId: 123,
  fromState: 'seen',
  toState: 'learning',
  reason: 'add_to_review',
);
// 输出: [LEARN] state_change: scope=word, userId=1, itemId=123, from=seen, to=learning, reason=add_to_review
```

### 数据库操作日志 [DB]

用于记录所有数据库 CRUD 操作。

```dart
// 记录数据库查询
logger.dbQuery(
  table: 'user_word_states',
  where: 'user_id=1 AND user_state=1',
  resultCount: 5,
);
// 输出: [DB] query: table=user_word_states, where="user_id=1 AND user_state=1", results=5

// 记录数据库插入
logger.dbInsert(
  table: 'user_word_states',
  id: 456,
  keyFields: {'wordId': 123, 'userId': 1},
);
// 输出: [DB] insert: table=user_word_states, id=456, wordId=123, userId=1

// 记录数据库更新
logger.dbUpdate(
  table: 'user_word_states',
  affectedRows: 1,
  updatedFields: ['interval', 'ease_factor', 'next_review_at'],
);
// 输出: [DB] update: table=user_word_states, affected=1, fields=[interval, ease_factor, next_review_at]

// 记录数据库删除
logger.dbDelete(
  table: 'learning_sessions',
  deletedRows: 1,
);
// 输出: [DB] delete: table=learning_sessions, deleted=1

// 记录数据库错误
logger.dbError(
  operation: 'INSERT',
  table: 'user_word_states',
  dbError: 'UNIQUE constraint failed',
  stackTrace: stackTrace,
);
// 输出: [DB] error: op=INSERT, table=user_word_states, error="UNIQUE constraint failed"
```

### 音频状态日志 [AUDIO]

用于记录音频播放状态和错误。

```dart
// 记录音频播放开始
logger.audioPlayStart(
  source: 'https://example.com/audio/word_123.mp3',
);
// 输出: [AUDIO] play_start: https://example.com/audio/word_123.mp3

// 记录音频播放完成
logger.audioPlayComplete(
  source: 'https://example.com/audio/word_123.mp3',
);
// 输出: [AUDIO] play_complete: source="https://example.com/audio/word_123.mp3"

// 记录音频播放失败
logger.audioPlayError(
  audio: 'https://example.com/audio/word_123.mp3',
  errorType: 'NetworkError',
  errorMessage: 'Connection timeout',
);
// 输出: [AUDIO] play_error: source="https://...", type=NetworkError, msg="Connection timeout"

// 记录音频状态变化
logger.audioStateChange(
  newState: 'playing',
);
// 输出: [AUDIO] state_change: playing
```

### 算法状态日志 [ALGO]

用于记录 SRS 算法计算过程。

```dart
// 记录 SRS 计算开始
logger.algoCalculateStart(
  algorithmType: 'FSRS',
  input: SRSInput(
    interval: 1.0,
    easeFactor: 2.5,
    stability: 0.0,
    difficulty: 0.0,
    rating: Rating.good,
  ),
);
// 输出: [ALGO] calculate_start: type=FSRS, interval=1.00, ef=2.500, stability=0.000, difficulty=0.000, rating=good

// 记录 SRS 计算完成
logger.algoCalculateComplete(
  algorithmType: 'FSRS',
  output: SRSOutput(
    interval: 3.5,
    easeFactor: 2.6,
    stability: 4.2,
    difficulty: 5.3,
    nextReviewAt: DateTime.now().add(Duration(days: 3)),
  ),
);
// 输出: [ALGO] calculate_complete: type=FSRS, interval=3.50, ef=2.600, stability=4.200, difficulty=5.300, nextReview=2024-11-30T10:30:00+08:00

// 记录参数更新
logger.algoParamsUpdate(
  wordId: 123,
  before: {'interval': 1.0, 'easeFactor': 2.5},
  after: {'interval': 3.5, 'easeFactor': 2.6},
);
// 输出: [ALGO] params_update: wordId=123, interval: 1.0 -> 3.5, easeFactor: 2.5 -> 2.6

// 记录复习计划变更
logger.algoScheduleChange(
  wordId: 123,
  oldSchedule: null,
  newSchedule: DateTime(2024, 11, 30, 10, 30),
);
// 输出: [ALGO] schedule_change: wordId=123, old=null, new=2024-11-30T10:30:00+08:00

// 记录 SRS 更新
logger.srsUpdate(
  scope: 'word',
  userId: 1,
  itemId: 123,
  rating: ReviewRating.good,
  algorithmType: AlgorithmType.sm2,
  before: {'interval': 1, 'nextReview': null},
  after: {'interval': 3, 'nextReview': '2024-11-30T10:30:00+08:00'},
);
// 输出: [ALGO] srs_update: scope=word, userId=1, itemId=123, rating=good, algo=sm2, changes=[interval: 1 -> 3, nextReview: null -> 2024-11-30T10:30:00+08:00]
```

---

## LogFormatter 格式化工具

提供统一的数据格式化方法，确保日志输出一致性。

```dart
import 'package:breeze_jp/core/utils/log_formatter.dart';

// 格式化 StudyWord 对象
final summary = LogFormatter.formatStudyWord(studyWord);
// 输出: id=1, wordId=123, state=learning, interval=2.50, nextReview=2024-11-30T10:30:00+08:00

// 格式化 SRS 输入参数
final inputStr = LogFormatter.formatSRSInput(srsInput);
// 输出: interval=1.00, ef=2.500, stability=0.000, difficulty=0.000, rating=good

// 格式化 SRS 输出参数
final outputStr = LogFormatter.formatSRSOutput(srsOutput);
// 输出: interval=3.50, ef=2.600, stability=4.200, difficulty=5.300, nextReview=2024-11-30T10:30:00+08:00

// 格式化时间戳 (ISO 8601 带时区)
final timestamp = LogFormatter.formatTimestamp(DateTime.now());
// 输出: 2024-11-27T10:30:00+08:00

// 格式化时长 (人类可读)
final duration = LogFormatter.formatDuration(330000);  // 5分30秒
// 输出: 5m 30s

// 格式化键值对
final kvStr = LogFormatter.formatKeyValues({'userId': 1, 'wordId': 123});
// 输出: userId=1, wordId=123

// 格式化变更集
final diffStr = LogFormatter.formatChanges({'interval': 1}, {'interval': 2});
// 输出: changes=[interval: 1 -> 2]

// 格式化列表摘要
final listStr = LogFormatter.formatListSummary([1, 2, 3, 4, 5], maxItems: 3);
// 输出: count=5, items=[1, 2, 3, ...]
```

### 格式化精度规范

| 数据类型              | 精度     | 示例                        |
| --------------------- | -------- | --------------------------- |
| interval (间隔)       | 2 位小数 | `2.50`                      |
| easeFactor (难度因子) | 3 位小数 | `2.500`                     |
| stability (稳定性)    | 3 位小数 | `4.200`                     |
| difficulty (难度)     | 3 位小数 | `5.300`                     |
| 时间戳                | ISO 8601 | `2024-11-27T10:30:00+08:00` |
| 时长                  | 人类可读 | `5m 30s`                    |

---

## 使用场景示例

### 在 Controller 中使用

```dart
class LearnController extends Notifier<LearnState> {
  Future<void> loadWords() async {
    // 记录会话开始
    logger.learnSessionStart(userId: 1);

    try {
      final reviewWords = await _studyWordRepository.getReviewWords(userId: 1);
      final newWords = await _wordRepository.getNewWords(limit: 10);

      // 记录单词加载
      logger.learnWordsLoaded(
        reviewCount: reviewWords.length,
        newCount: newWords.length,
        totalCount: reviewWords.length + newWords.length,
      );

      state = state.copyWith(words: [...reviewWords, ...newWords]);
    } catch (e, stackTrace) {
      logger.error('加载单词失败', e, stackTrace);
    }
  }

  void submitAnswer(int wordId, Rating rating) {
    // 记录答案提交
    logger.learnAnswerSubmit(
      wordId: wordId,
      rating: rating.name,
      newInterval: output.interval,
      newEaseFactor: output.easeFactor,
    );
  }
}
```

### 在 Repository 中使用

```dart
class StudyWordRepository {
  Future<List<StudyWord>> getReviewWords({required int userId}) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final results = await db.query(
      'user_word_states',
      where: 'user_id = ? AND user_state = ? AND next_review_at <= ?',
      whereArgs: [userId, 1, now],
    );

    // 记录查询
    logger.dbQuery(
      table: 'user_word_states',
      where: 'user_id=$userId AND user_state=1 AND next_review_at<=$now',
      resultCount: results.length,
    );

    return results.map((map) => StudyWord.fromMap(map)).toList();
  }

  Future<int> updateStudyWord(StudyWord word) async {
    try {
      final db = await AppDatabase.instance.database;
      final affected = await db.update(
        'user_word_states',
        word.toMap(),
        where: 'id = ?',
        whereArgs: [word.id],
      );

      // 记录更新
      logger.dbUpdate(
        table: 'user_word_states',
        affectedRows: affected,
        updatedFields: ['interval', 'ease_factor', 'next_review_at'],
      );

      return affected;
    } catch (e, stackTrace) {
      // 记录错误
      logger.dbError(
        operation: 'UPDATE',
        table: 'user_word_states',
        dbError: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
```

### 在 AudioService 中使用

```dart
class AudioService {
  Future<void> playAudio(String source) async {
    // 记录播放开始
    logger.audioPlayStart(
      source: source,
    );

    try {
      await _player.setUrl(source);
      await _player.play();

      logger.audioPlayComplete(
        source: source,
      );
    } catch (e) {
      // 记录播放错误
      logger.audioPlayError(
        audio: source,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}
```

---

## 日志输出示例

```
💡 INFO | [LEARN] session_start: userId=1, timestamp=2024-11-27T10:30:00+08:00
🐛 DEBUG | [DB] query: table=user_word_states, where="user_id=1 AND user_state=1", results=5
💡 INFO | [LEARN] words_loaded: review=5, new=10, total=15
💡 INFO | [LEARN] word_view: wordId=123, position=1/15
💡 INFO | [AUDIO] play_start: type=word, source="https://...", wordId=123
💡 INFO | [AUDIO] play_complete: source="https://...", duration=1s 200ms
💡 INFO | [ALGO] calculate_start: type=FSRS, interval=1.00, ef=2.500, stability=0.000, difficulty=0.000, rating=good
💡 INFO | [ALGO] calculate_complete: type=FSRS, interval=3.50, ef=2.600, stability=4.200, difficulty=5.300, nextReview=2024-11-30
🐛 DEBUG | [DB] update: table=user_word_states, affected=1, fields=[interval, ease_factor, next_review_at]
💡 INFO | [LEARN] answer_submit: wordId=123, rating=good, interval=3.50, ef=2.600
💡 INFO | [LEARN] session_end: duration=5m 30s, learned=10, reviewed=5
```

---

## 最佳实践

### ✅ 推荐做法

1. **使用分类日志方法**
   - 学习流程使用 `learnXxx()` 方法
   - 数据库操作使用 `dbXxx()` 方法
   - 音频状态使用 `audioXxx()` 方法
   - 算法计算使用 `algoXxx()` 方法

2. **记录关键操作**
   - 会话开始和结束
   - 数据库 CRUD 操作
   - 音频播放状态变化
   - SRS 算法计算结果

3. **包含上下文信息**

   ```dart
   logger.learnAnswerSubmit(
     wordId: wordId,
     rating: rating.name,
     newInterval: output.interval,
     newEaseFactor: output.easeFactor,
   );
   ```

4. **错误时记录堆栈**

   ```dart
   logger.dbError(
     operation: 'UPDATE',
     table: 'user_word_states',
     dbError: error,
     stackTrace: stackTrace,
   );
   ```

5. **使用 LogFormatter 格式化复杂数据**
   ```dart
   final summary = LogFormatter.formatStudyWord(word);
   logger.debug('处理单词: $summary');
   ```

### ❌ 避免做法

1. **不要在循环中记录日志**

   ```dart
   // ❌ 错误
   for (final word in words) {
     logger.debug('处理单词: ${word.id}');
   }

   // ✅ 正确
   logger.debug('开始处理 ${words.length} 个单词');
   ```

2. **不要记录敏感信息**
   - 密码
   - Token
   - 个人隐私数据

3. **不要记录过大的数据**

   ```dart
   // ❌ 错误
   logger.debug('查询结果: $results');  // results 可能很大

   // ✅ 正确
   logger.dbQuery(table: 'words', resultCount: results.length);
   ```

4. **不要混用分类**

   ```dart
   // ❌ 错误 - 数据库操作使用了 learn 方法
   logger.learnWordsLoaded(...);  // 在 Repository 中

   // ✅ 正确 - 使用对应的分类方法
   logger.dbQuery(table: 'user_word_states', resultCount: count);
   ```

---

## 配置选项

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

---

## 生产环境

日志仅在 Debug 模式输出，Release 模式下不会有任何日志输出，不影响性能。

---

## 快速参考

详见 [LOGGER_QUICK_REF.md](./LOGGER_QUICK_REF.md) 获取简洁的方法速查表。
