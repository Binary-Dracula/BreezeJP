# Design Document: Logging System

## Overview

本设计文档描述了 BreezeJP 应用日志系统的规范化方案。通过扩展现有的 `AppLogger` 类，添加分类日志方法和格式化工具，实现统一、清晰、易于调试的日志输出。

## Architecture

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Learn     │  │   Audio     │  │    Repository       │  │
│  │  Controller │  │   Service   │  │    (DB Layer)       │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         ▼                ▼                     ▼             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    AppLogger (Enhanced)                  ││
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   ││
│  │  │  learn() │ │  audio() │ │   db()   │ │  algo()  │   ││
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   ││
│  │       │            │            │            │          ││
│  │       ▼            ▼            ▼            ▼          ││
│  │  ┌─────────────────────────────────────────────────┐   ││
│  │  │              LogFormatter                        │   ││
│  │  │  formatStudyWord() | formatSRS() | formatDuration│   ││
│  │  └─────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────┘│
│                            │                                 │
│                            ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    Logger (Package)                      ││
│  │              PrettyPrinter | LogFilter                   ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### 日志分类

| 分类 | 前缀 | 用途 | 使用场景 |
|------|------|------|----------|
| LEARN | `[LEARN]` | 学习流程 | 会话开始/结束、单词加载、答案提交 |
| DB | `[DB]` | 数据库操作 | CRUD 操作、查询、事务 |
| AUDIO | `[AUDIO]` | 音频状态 | 播放、暂停、停止、错误 |
| ALGO | `[ALGO]` | 算法计算 | SRS 输入/输出、参数更新 |

## Components and Interfaces

### 1. LogCategory 枚举

```dart
/// 日志分类
enum LogCategory {
  learn('[LEARN]'),   // 学习流程
  db('[DB]'),         // 数据库操作
  audio('[AUDIO]'),   // 音频状态
  algo('[ALGO]');     // 算法计算

  const LogCategory(this.prefix);
  final String prefix;
}
```

### 2. AppLogger 扩展方法

```dart
class AppLogger {
  // 现有方法保持不变...

  // ==================== 学习流程日志 ====================
  
  /// 记录学习会话开始
  void learnSessionStart({required int userId});
  
  /// 记录单词加载
  void learnWordsLoaded({
    required int reviewCount,
    required int newCount,
    required int totalCount,
  });
  
  /// 记录单词查看
  void learnWordView({
    required int wordId,
    required int position,
    required int total,
  });
  
  /// 记录答案提交
  void learnAnswerSubmit({
    required int wordId,
    required String rating,
    required double newInterval,
    required double newEaseFactor,
  });
  
  /// 记录学习会话结束
  void learnSessionEnd({
    required int durationMs,
    required int learnedCount,
    required int reviewedCount,
  });

  // ==================== 数据库操作日志 ====================
  
  /// 记录数据库查询
  void dbQuery({
    required String table,
    String? where,
    int? resultCount,
  });
  
  /// 记录数据库插入
  void dbInsert({
    required String table,
    required int id,
    Map<String, dynamic>? keyFields,
  });
  
  /// 记录数据库更新
  void dbUpdate({
    required String table,
    required int affectedRows,
    List<String>? updatedFields,
  });
  
  /// 记录数据库删除
  void dbDelete({
    required String table,
    required int deletedRows,
  });
  
  /// 记录数据库错误
  void dbError({
    required String operation,
    required String table,
    required dynamic error,
    StackTrace? stackTrace,
  });

  // ==================== 音频状态日志 ====================
  
  /// 记录音频播放开始
  void audioPlayStart({
    required String sourceType,  // 'word' | 'example'
    required String source,
    int? wordId,
  });
  
  /// 记录音频播放完成
  void audioPlayComplete({
    required String source,
    required int durationMs,
  });
  
  /// 记录音频播放失败
  void audioPlayError({
    required String source,
    required String errorType,
    required String errorMessage,
  });
  
  /// 记录音频状态变化
  void audioStateChange({
    required String previousState,
    required String newState,
  });

  // ==================== 算法状态日志 ====================
  
  /// 记录 SRS 计算开始
  void algoCalculateStart({
    required String algorithmType,
    required SRSInput input,
  });
  
  /// 记录 SRS 计算完成
  void algoCalculateComplete({
    required String algorithmType,
    required SRSOutput output,
  });
  
  /// 记录参数更新
  void algoParamsUpdate({
    required int wordId,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  });
  
  /// 记录复习计划变更
  void algoScheduleChange({
    required int wordId,
    required DateTime? oldSchedule,
    required DateTime newSchedule,
  });
}
```

### 3. LogFormatter 工具类

```dart
/// 日志格式化工具
class LogFormatter {
  /// 格式化 StudyWord 为单行摘要
  static String formatStudyWord(StudyWord word);
  
  /// 格式化 SRS 输入
  static String formatSRSInput(SRSInput input);
  
  /// 格式化 SRS 输出
  static String formatSRSOutput(SRSOutput output);
  
  /// 格式化时间戳为 ISO 8601
  static String formatTimestamp(DateTime dateTime);
  
  /// 格式化时长为人类可读格式
  static String formatDuration(int milliseconds);
  
  /// 格式化键值对
  static String formatKeyValues(Map<String, dynamic> data);
  
  /// 格式化列表摘要
  static String formatListSummary<T>(List<T> list, {int maxItems = 3});
}
```

## Data Models

### 日志输出格式

```
[CATEGORY] action: key1=value1, key2=value2
```

### 示例输出

```
// 学习流程
[LEARN] session_start: userId=1, timestamp=2024-11-27T10:30:00+08:00
[LEARN] words_loaded: review=5, new=10, total=15
[LEARN] word_view: wordId=123, position=1/15
[LEARN] answer_submit: wordId=123, rating=good, interval=2.50, ef=2.60
[LEARN] session_end: duration=5m 30s, learned=10, reviewed=5

// 数据库操作
[DB] query: table=study_words, where="user_id=1 AND user_state=1", results=5
[DB] insert: table=study_words, id=456, wordId=123, userId=1
[DB] update: table=study_words, affected=1, fields=[interval, ease_factor, next_review_at]
[DB] delete: table=study_logs, deleted=10
[DB] error: op=INSERT, table=study_words, error="UNIQUE constraint failed"

// 音频状态
[AUDIO] play_start: type=word, source="https://...", wordId=123
[AUDIO] play_complete: source="https://...", duration=1.2s
[AUDIO] play_error: source="https://...", type=NetworkError, msg="Connection timeout"
[AUDIO] state_change: playing -> stopped

// 算法计算
[ALGO] calculate_start: type=FSRS, interval=1.00, ef=2.50, stability=0.00, difficulty=0.00
[ALGO] calculate_complete: type=FSRS, interval=3.50, ef=2.60, stability=4.20, difficulty=5.30, nextReview=2024-11-30
[ALGO] params_update: wordId=123, interval: 1.00 -> 3.50, ef: 2.50 -> 2.60
[ALGO] schedule_change: wordId=123, old=null, new=2024-11-30T10:30:00+08:00
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Category Prefix Consistency

*For any* log message generated by a categorized logging method (learn, db, audio, algo), the output string SHALL contain the corresponding category prefix ([LEARN], [DB], [AUDIO], [ALGO]) at the beginning of the message.

**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

### Property 2: Learning Flow Log Completeness

*For any* learning session, the log output SHALL contain all required fields: session start with userId and timestamp, word loading with review/new counts, answer submissions with rating and SRS parameters, and session end with duration and word counts.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

### Property 3: Database Operation Log Completeness

*For any* database operation (query, insert, update, delete), the log output SHALL contain the operation type, table name, and operation-specific details (result count for query, ID for insert, affected rows for update/delete).

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

### Property 4: Audio State Log Completeness

*For any* audio state change, the log output SHALL contain the source information and state transition details (previous state and new state for state changes, error details for failures).

**Validates: Requirements 4.1, 4.2, 4.3, 4.4**

### Property 5: Algorithm Log Completeness

*For any* SRS calculation, the log output SHALL contain the algorithm type, input parameters, and output parameters with appropriate numeric precision.

**Validates: Requirements 5.1, 5.2, 5.3, 5.4**

### Property 6: Formatting Consistency

*For any* formatted output, numeric values SHALL use consistent precision (2 decimal places for intervals, 3 for factors), timestamps SHALL be in ISO 8601 format, and durations SHALL be in human-readable format.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4**

### Property 7: Output Format Consistency

*For any* log message, the format SHALL follow the pattern "[CATEGORY] action: key=value, ..." with consistent separators and include error context when applicable.

**Validates: Requirements 7.1, 7.2, 7.3, 7.4**

## Error Handling

### 日志方法错误处理

- 日志方法本身不应抛出异常
- 如果格式化失败，使用降级输出（原始数据的 toString）
- 空值处理：使用 "null" 或 "-" 表示

### 示例

```dart
void learnWordView({required int wordId, required int position, required int total}) {
  try {
    info('${LogCategory.learn.prefix} word_view: wordId=$wordId, position=$position/$total');
  } catch (e) {
    // 降级输出
    debug('Log formatting failed: $e');
  }
}
```

## Testing Strategy

### 单元测试

- 测试每个格式化方法的输出格式
- 测试边界值（空列表、null 值、极大/极小数值）
- 测试时间格式化的时区处理

### 属性测试

使用 `test` 包进行属性测试：

- **Property 1**: 生成随机日志消息，验证分类前缀存在
- **Property 6**: 生成随机数值，验证格式化精度
- **Property 7**: 生成随机键值对，验证输出格式

### 测试框架

- 使用 Flutter 内置的 `test` 包
- 使用 `mockito` 模拟依赖
- 属性测试使用 `test` 包的参数化测试功能

### 测试文件结构

```
test/
├── core/
│   └── utils/
│       ├── app_logger_test.dart
│       └── log_formatter_test.dart
```
