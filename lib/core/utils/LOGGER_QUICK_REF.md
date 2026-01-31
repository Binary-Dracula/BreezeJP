# Logger 快速参考

## 导入

```dart
import 'package:breeze_jp/core/utils/app_logger.dart';
import 'package:breeze_jp/core/utils/log_formatter.dart';
```

## 基础用法

```dart
logger.debug('调试信息');
logger.info('一般信息');
logger.warning('警告信息');
logger.error('错误信息', error, stackTrace);
logger.fatal('致命错误');
logger.trace('追踪信息');
```

---

## 分类日志方法

### [LEARN] 学习流程

```dart
// 会话开始
logger.learnSessionStart(userId: 1);

// 单词加载
logger.learnWordsLoaded(reviewCount: 5, newCount: 10, totalCount: 15);

// 单词查看
logger.learnWordView(wordId: 123, position: 1, total: 15);

// 答案提交
logger.learnAnswerSubmit(wordId: 123, rating: 'good', newInterval: 2.5, newEaseFactor: 2.6);

// 会话结束
logger.learnSessionEnd(durationMs: 330000, learnedCount: 10, reviewedCount: 5);

// 状态迁移
logger.stateChange(
  scope: 'word',
  userId: 1,
  itemId: 123,
  fromState: 'seen',
  toState: 'learning',
  reason: 'add_to_review',
);
```

### [DB] 数据库操作

```dart
// 查询
logger.dbQuery(table: 'study_words', where: 'user_id=1', resultCount: 5);

// 插入
logger.dbInsert(table: 'study_words', id: 456, keyFields: {'wordId': 123});

// 更新
logger.dbUpdate(table: 'study_words', affectedRows: 1, updatedFields: ['interval']);

// 删除
logger.dbDelete(table: 'study_logs', deletedRows: 10);

// 错误
logger.dbError(operation: 'UPDATE', table: 'study_words', dbError: e, stackTrace: st);
```

### [AUDIO] 音频状态

```dart
// 播放开始
logger.audioPlayStart(sourceType: 'word', source: url, wordId: 123);

// 播放完成
logger.audioPlayComplete(source: url, durationMs: 1200);

// 播放错误
logger.audioPlayError(source: url, errorType: 'NetworkError', errorMessage: msg);

// 状态变化
logger.audioStateChange(previousState: 'playing', newState: 'stopped');
```

### [ALGO] 算法计算

```dart
// 计算开始
logger.algoCalculateStart(algorithmType: 'FSRS', input: srsInput);

// 计算完成
logger.algoCalculateComplete(algorithmType: 'FSRS', output: srsOutput);

// 参数更新
logger.algoParamsUpdate(wordId: 123, before: {...}, after: {...});

// 计划变更
logger.algoScheduleChange(wordId: 123, oldSchedule: null, newSchedule: newDate);

// SRS 更新
logger.srsUpdate(
  scope: 'word',
  userId: 1,
  itemId: 123,
  rating: ReviewRating.good,
  algorithmType: AlgorithmType.sm2,
  before: {...},
  after: {...},
);
```

---

## LogFormatter 格式化

```dart
// StudyWord 摘要
LogFormatter.formatStudyWord(word);
// → id=1, wordId=123, state=learning, interval=2.50, nextReview=...

// SRS 输入/输出
LogFormatter.formatSRSInput(input);
LogFormatter.formatSRSOutput(output);

// 时间戳 (ISO 8601)
LogFormatter.formatTimestamp(DateTime.now());
// → 2024-11-27T10:30:00+08:00

// 时长 (人类可读)
LogFormatter.formatDuration(330000);
// → 5m 30s

// 键值对
LogFormatter.formatKeyValues({'userId': 1, 'wordId': 123});
// → userId=1, wordId=123

// 变更集
LogFormatter.formatChanges({'interval': 1}, {'interval': 2});
// → changes=[interval: 1 -> 2]

// 列表摘要
LogFormatter.formatListSummary([1, 2, 3, 4, 5], maxItems: 3);
// → count=5, items=[1, 2, 3, ...]
```

---

## 格式化精度

| 类型 | 精度 | 示例 |
|------|------|------|
| interval | 2 位小数 | `2.50` |
| easeFactor | 3 位小数 | `2.500` |
| stability | 3 位小数 | `4.200` |
| difficulty | 3 位小数 | `5.300` |
| 时间戳 | ISO 8601 | `2024-11-27T10:30:00+08:00` |
| 时长 | 人类可读 | `5m 30s` |

---

## 日志级别

| 方法 | 表情 | 用途 |
|------|------|------|
| `trace()` | 🔍 | 追踪信息 |
| `debug()` | 🐛 | 调试信息 |
| `info()` | 💡 | 一般信息 |
| `warning()` | ⚠️ | 警告 |
| `error()` | ❌ | 错误 |
| `fatal()` | 💀 | 致命错误 |

---

## 注意事项

- ✅ 仅 Debug 模式输出
- ✅ Release 模式自动禁用
- ✅ 使用分类方法记录对应模块日志
- ❌ 不要记录敏感信息
- ❌ 不要在循环中记录
- ❌ 不要混用分类方法
