# 学习进度功能说明

## 概述

`study_words` 表用于记录用户对每个单词的学习进度和 SRS（间隔重复系统）数据。

## 数据库表结构

### study_words

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 主键 |
| user_id | INTEGER | 用户 ID |
| word_id | INTEGER | 单词 ID |
| user_state | INTEGER | 学习状态（0=未学习, 1=学习中, 2=已掌握, 3=忽略） |
| next_review_at | INTEGER | 下次复习时间（Unix 时间戳） |
| last_reviewed_at | INTEGER | 上次复习时间（Unix 时间戳） |
| interval | REAL | 当前复习间隔（天） |
| ease_factor | REAL | 难度因子（默认 2.5） |
| streak | INTEGER | 连续答对次数 |
| total_reviews | INTEGER | 累计复习次数 |
| fail_count | INTEGER | 答错次数 |
| created_at | INTEGER | 创建时间 |
| updated_at | INTEGER | 更新时间 |

**唯一约束**: `(user_id, word_id)` - 每个用户每个单词只有一条记录

## 数据模型

### StudyWord

```dart
class StudyWord {
  final int id;
  final int userId;
  final int wordId;
  final UserWordState userState;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final double interval;
  final double easeFactor;
  final int streak;
  final int totalReviews;
  final int failCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 辅助方法
  bool get needsReview;  // 是否需要复习
  bool get isNew;        // 是否为新单词
  double get progressPercentage;  // 学习进度百分比
}
```

### UserWordState 枚举

```dart
enum UserWordState {
  newWord(0),    // 未学习
  learning(1),   // 学习中
  mastered(2),   // 已掌握
  ignored(3),    // 已忽略
}
```

## Repository 使用

### 基础操作

```dart
final repository = ref.read(studyWordRepositoryProvider);

// 获取学习记录
final studyWord = await repository.getStudyWord(userId, wordId);

// 创建学习记录
final newStudyWord = StudyWord(
  id: 0,
  userId: 1,
  wordId: 100,
  userState: UserWordState.newWord,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
await repository.createStudyWord(newStudyWord);

// 更新学习记录
await repository.updateStudyWord(updatedStudyWord);
```

### 查询方法

```dart
// 获取用户所有学习记录
final allWords = await repository.getUserStudyWords(userId);

// 获取特定状态的单词
final learningWords = await repository.getUserStudyWords(
  userId,
  state: UserWordState.learning,
);

// 获取需要复习的单词
final dueWords = await repository.getDueReviews(userId, limit: 20);

// 获取新单词
final newWords = await repository.getNewWords(userId, limit: 10);
```

### 统计方法

```dart
// 获取学习统计
final stats = await repository.getUserStatistics(userId);
print('总单词数: ${stats['total_words']}');
print('学习中: ${stats['learning_words']}');
print('已掌握: ${stats['mastered_words']}');

// 获取待复习数量
final dueCount = await repository.getDueReviewCount(userId);
```

### SRS 更新方法

```dart
// 记录答对
await repository.recordCorrectReview(
  userId,
  wordId,
  newInterval: 2.5,      // 新间隔（天）
  newEaseFactor: 2.6,    // 新难度因子
);

// 记录答错
await repository.recordIncorrectReview(
  userId,
  wordId,
  newInterval: 0.5,      // 重置间隔
  newEaseFactor: 2.3,    // 降低难度因子
);

// 标记为已掌握
await repository.markAsMastered(userId, wordId);

// 标记为忽略
await repository.markAsIgnored(userId, wordId);

// 重置学习进度
await repository.resetProgress(userId, wordId);
```

## SRS 算法建议

### SM-2 算法（简化版）

```dart
class SRSCalculator {
  /// 计算下次复习间隔
  static Map<String, double> calculateNextReview({
    required double currentInterval,
    required double currentEaseFactor,
    required bool isCorrect,
    required int quality, // 0-5: 0=完全不记得, 5=完美记住
  }) {
    double newEaseFactor = currentEaseFactor;
    double newInterval = currentInterval;

    if (isCorrect && quality >= 3) {
      // 答对
      newEaseFactor = currentEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      newEaseFactor = newEaseFactor.clamp(1.3, 2.5);
      
      if (currentInterval == 0) {
        newInterval = 1; // 第一次：1天
      } else if (currentInterval == 1) {
        newInterval = 6; // 第二次：6天
      } else {
        newInterval = currentInterval * newEaseFactor;
      }
    } else {
      // 答错
      newInterval = 1; // 重置为1天
      newEaseFactor = (currentEaseFactor - 0.2).clamp(1.3, 2.5);
    }

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
    };
  }
}
```

### 使用示例

```dart
// 用户答对了
final result = SRSCalculator.calculateNextReview(
  currentInterval: studyWord.interval,
  currentEaseFactor: studyWord.easeFactor,
  isCorrect: true,
  quality: 4, // 记得比较清楚
);

await repository.recordCorrectReview(
  userId,
  wordId,
  newInterval: result['interval']!,
  newEaseFactor: result['easeFactor']!,
);
```

## 常见查询示例

### 获取今日需要复习的单词

```dart
final dueWords = await repository.getDueReviews(userId);
print('今日需要复习 ${dueWords.length} 个单词');
```

### 获取学习进度概览

```dart
final stats = await repository.getUserStatistics(userId);
final total = stats['total_words'] as int;
final mastered = stats['mastered_words'] as int;
final progress = total > 0 ? (mastered / total * 100).toStringAsFixed(1) : '0.0';
print('学习进度: $progress% ($mastered/$total)');
```

### 获取某个 JLPT 等级的学习情况

```dart
// 需要在 Repository 中添加此方法
Future<Map<String, int>> getJLPTLevelProgress(int userId, String jlptLevel) async {
  final db = await _db;
  final result = await db.rawQuery('''
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN sw.user_state = 2 THEN 1 ELSE 0 END) as mastered
    FROM words w
    LEFT JOIN study_words sw ON w.id = sw.word_id AND sw.user_id = ?
    WHERE w.jlpt_level = ?
  ''', [userId, jlptLevel]);
  
  return {
    'total': result.first['total'] as int,
    'mastered': result.first['mastered'] as int? ?? 0,
  };
}
```

## UI 集成建议

### 显示学习进度

```dart
class StudyProgressWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(studyWordRepositoryProvider);
    
    return FutureBuilder<Map<String, dynamic>>(
      future: repository.getUserStatistics(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final stats = snapshot.data!;
        final total = stats['total_words'] as int;
        final mastered = stats['mastered_words'] as int;
        
        return Column(
          children: [
            Text('总单词数: $total'),
            Text('已掌握: $mastered'),
            LinearProgressIndicator(
              value: total > 0 ? mastered / total : 0,
            ),
          ],
        );
      },
    );
  }
}
```

### 显示待复习数量徽章

```dart
FutureBuilder<int>(
  future: repository.getDueReviewCount(userId),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    if (count == 0) return Icon(Icons.check_circle);
    
    return Badge(
      label: Text('$count'),
      child: Icon(Icons.school),
    );
  },
)
```

## 注意事项

1. **唯一约束**: 每个用户每个单词只能有一条记录，插入前检查是否已存在
2. **时间戳**: 数据库使用 Unix 时间戳（秒），Dart 使用毫秒，需要转换
3. **SRS 算法**: 可根据实际需求调整间隔计算逻辑
4. **性能优化**: 大量数据时使用分页查询（limit/offset）
5. **数据同步**: 如果支持多设备，需要考虑数据同步策略

## 相关文件

- `.kiro/steering/database.md` - 数据库文档
- `lib/data/models/study_word.dart` - 数据模型
- `lib/data/repositories/study_word_repository.dart` - 数据仓库
- `lib/data/repositories/study_word_repository_provider.dart` - Provider

## 下一步

1. 实现 SRS 算法服务
2. 创建学习进度 Controller
3. 实现复习功能 UI
4. 添加学习统计页面
5. 实现学习提醒功能
