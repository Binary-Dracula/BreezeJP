---
inclusion: always
---

# 项目架构与文件组织（冻结版）

## 架构模式

**MVVM + Command / Query / Analytics / Repository + Session + Riverpod**

---

## 一、全局数据流（冻结）

```
View → Controller
           ├─→ Query (Read)
           ├─→ Analytics (Statistics / Read-only)
           └─→ Command (Behavior / Write)
                       ↓
                 Repository (Entity CRUD)
                       ↓
                    Database
```

### 补充说明（关键）

* **Session 不是所有写操作的必经路径**
* Session 只负责：
  **“学习 / 复习过程中的统计聚合”**
* 以下行为 **不经过 Session**，且是合法的：

  * Word `seen` 创建
  * Word `learning` 进入（点击加入复习）
  * Word `mastered / ignored` 状态切换
  * PageDurationTracker 写入学习时长

---

## 二、各层职责与禁止项（冻结）

| Layer                 | 职责                                  | 明确禁止                 |
| --------------------- | ----------------------------------- | -------------------- |
| **View**              | UI 渲染、用户交互                          | 直接访问 DB、统计计算、状态推导    |
| **Controller**        | 流程编排、调用 Command / Query / Analytics | 直接调用 Repository / DB |
| **Command**           | 写行为 / 状态变更 / 副作用入口                  | 返回 Map / SQL 原始结果    |
| **Command / Session** | 会话级统计聚合                             | 绕过规则写 daily_stats    |
| **Query**             | 只读查询（join / list / detail）          | 写操作                  |
| **Analytics**         | 聚合统计 / 报表（只读）                       | 写操作                  |
| **Repository**        | 单表 CRUD                             | join / 统计 / 业务语义     |
| **External**          | 外部 API Client                       | 本地持久化 / 业务规则         |
| **Model**             | 数据结构                                | 行为 / 业务逻辑            |
| **State**             | 不可变状态容器                             | 可变字段                 |

---

## 三、核心冻结规则（Hard Rules）

### 1️⃣ Controller 规则

* Controller **只调用**：

  * Command
  * Query
  * Analytics
* ❌ 不直接写：

  * `daily_stats`
  * `study_logs`
  * `kana_logs`

---

### 2️⃣ Repository 规则

* 仅负责 **单表实体一致性**
* 不包含：

  * join
  * count / group by
  * 业务判断（如 firstLearn / mastered）

---

### 3️⃣ Query / Analytics 规则

* **只读**
* 通过 `databaseProvider` 注入 Database
* ❌ 禁止：

  * 使用 `AppDatabase.instance`
  * 写入任何状态

---

### 4️⃣ Command 规则（重要修订说明）

Command 是**唯一写入口**，但存在 **三类正交写路径**：

| 写入类型                                    | 责任组件                                        | 是否经 Session |
| --------------------------------------- | ------------------------------------------- | ----------- |
| 状态写入（study_words / kana_learning_state） | `WordCommand / KanaCommand`                 | ❌           |
| 行为日志（study_logs / kana_logs）            | `WordCommand / KanaCommand / ReviewCommand` | ❌           |
| 统计聚合（daily_stats）                       | `Session` / `DailyStatCommand`              | ✅ / ❌（时间除外） |

> **关键冻结点**
> “唯一写入口” ≠ “必须走 Session”

---

## 四、Session 架构（统计专用）

### 适用范围（冻结）

Session **只负责以下统计类写入**：

* 今日学习数（new_learned_count）
* 今日复习数（review_count）
* 会话级统计聚合

### 不适用范围（明确）

以下行为 **不经过 Session**：

* Word `seen` 创建
* Word `learning` 进入
* Word `mastered / ignored`
* PageDurationTracker 学习时长

---

### Session 统计链路（冻结）

```
SessionStatPolicy
   → SessionStatAccumulator
      → flush
         → DailyStatCommand.applySession
```

### 硬性规则

* Feature 不得直接写 `daily_stats`
* 不允许绕过 Policy / Accumulator

---

## 五、Word 学习数据三层模型（关键冻结）

### 1️⃣ study_words（状态表）

> **描述：当前状态**

* 每个 word **最多一条**
* 不表达“今天发生了什么”

合法状态：

* `seen`
* `learning`
* `mastered`
* `ignored`

---

### 2️⃣ study_logs（行为日志）

> **描述：用户做了什么**

* 同一 word 可有多条

* `firstLearn` 语义冻结：

  > firstLearn 是「第一次点击加入复习」，而不是「第一次进入 learning」
  > 当且仅当：
      用户点击「加入复习」
      且该单词 此前从未出现过 firstLearn log
  > 与以下因素全部无关
      study_words 当前状态
      是否曾是 mastered / ignored
      是否曾恢复为 seen
      是否是第一次展示
      是否是第一次进入 learning
      
* 与 `study_words` **无直接推导关系**

---

### 3️⃣ daily_stats（统计快照）

> **描述：今天发生了多少次**

* 只增量写
* 不反推状态
* 不回放日志

---

## 六、Word 学习生命周期（冻结对齐）

### 状态流转（唯一合法）

```
无记录
   ↓（首次展示）
seen
   ↓（点击加入复习）
learning
   ↓（点击已掌握）
mastered
```

* `ignored` 可由任意状态进入
* `ignored → seen` 仅由用户显式操作

---

### seen 创建规则（冻结）

* **唯一时机**：

  * Learn 页面 `onPageChanged`
* 行为：

  * `getOrCreateLearningState`
* ❌ 禁止：

  * 页面初始化
  * 音频播放
  * 停留时间判断

---

### learning 进入规则（冻结）

* **唯一合法触发**：

  * 点击「加入复习」
  * 「一键掌握」（内部拆分）
* ❌ 禁止隐式进入

---

## 七、学习时长统计（冻结补充）

* 唯一来源：`PageDurationTracker`
* 唯一写入口：`DailyStatCommand.applyTimeOnlyDelta`
* 不经过 Session
* 不参与行为日志

---

## 八、Debug 架构规则（冻结）

* Debug：

  * 只能调用 Command / Query / Analytics
  * ❌ 不直连 Repository / DB
* Debug Command：

  * 不被 Feature 调用
  * 不参与正式统计链路

---

## 九、依赖关系规则（冻结）

* Feature → Data / Services / Core
* Services → Data / Core
* Data → Core
* Debug → Command / Query / Analytics

---

## 十、目录结构（与当前代码一致）

> **目录结构保持不变，仅语义冻结**

（目录树保持你提供的版本，此处不再重复）

---

## 十一、最终冻结声明（Hard Stop）

> 本文档定义的是 **“什么可以写、什么不可以写”**，
> 而不是“怎么写得更方便”。

任何违反本文档的实现：

* ❌ 不是优化
* ❌ 不是临时方案
* ❌ 不是 UI 问题
* ✅ 是 **架构错误**

---

### 🔒 Final Rule

> **当你发现统计、状态或行为“感觉怪怪的”，
> 问题一定不在感觉，而在是否违反了本文件。**

---
