# 技术文档

## Statistics / Data Flow

## 学习统计体系（封板）

### 设计原则（Hard Rules）

1. **时间统计（学习时长）**
   - 唯一来源：页面驻留时间（PageDurationTracker）
   - 唯一写入表：daily_stats.total_time_ms
   - 写入路径：DailyStatCommand.applyTimeOnlyDelta
   - ❌ 禁止从 study_logs / session / 行为中计算时间
   - ❌ 禁止在行为日志中携带 duration

2. **今日学习 / 今日复习**
   - 唯一来源：daily_stats
     - new_learned_count
     - review_count
   - 写入时机：学习 / 复习行为发生时的增量更新
   - ❌ 禁止通过日志回放或库存表推导“今日”数据

3. **累计掌握**
   - 唯一来源：状态表
     - study_words.user_state = mastered
     - kana_learning_state.learning_status = mastered
   - ❌ 禁止通过 daily_stats 或日志累计推导

4. **连续学习（streak）**
   - 唯一来源：daily_stats
   - 判定标准：当天或昨天存在任意有效学习行为或学习时长
   - 计算方式：gaps-and-islands（非递归 CTE）
   - ❌ 禁止从 logs 回放计算 streak

### 明确禁止的反模式（Anti-patterns）

- ❌ 在页面中直接写入 daily_stats
- ❌ 从 study_logs 统计今日学习、连续学习
- ❌ 在行为日志中维护 durationMs
- ❌ 引入第二套统计表或缓存统计结果
- ❌ 在 UI 层进行任何统计计算
