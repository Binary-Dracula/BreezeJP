---
inclusion: always
---

# 项目架构与文件组织（Structure · 冻结版）

> 本文档定义的是 **工程结构、层级职责与依赖规则**  
> 不裁决产品行为、不裁决统计语义  
> 所有业务与数据语义以 `freeze.md` 为最终依据

---

## 架构模式

**MVVM + Command / Query / Analytics / Repository + Session + Riverpod**

该模式用于保证：

* 写入口集中
* 读写职责分离
* 统计链路可控
* Feature 与数据层解耦

---

## 一、全局数据流（工程级冻结）

```

View → Controller
├─→ Query        (Read-only)
├─→ Analytics   (Read-only Aggregation)
└─→ Command     (Write / Side Effects)
↓
Repository (Single-table CRUD)
↓
Database

```

### 工程级说明

* **Controller 是 Feature 的唯一编排点**
* **Repository 永不暴露给 Feature**
* **Database 只允许通过 Provider 注入**

---

## 二、各层职责与禁止项（结构级冻结）

| Layer | 工程职责 | 明确禁止 |
|------|---------|---------|
| **View** | UI 渲染、用户交互 | 访问 Repository / DB、统计推导 |
| **Controller** | 调度流程、调用 Command / Query / Analytics | 直接访问 Repository / DB |
| **Command** | 写行为入口、状态变更、副作用触发 | 返回 Map / SQL 原始结构 |
| **Query** | 只读查询（detail / list / join） | 写操作 |
| **Analytics** | 聚合统计（只读） | 写操作 |
| **Repository** | 单表 CRUD、一致性保证 | join / 统计 / 业务语义 |
| **Model** | 数据结构定义 | 行为 / 业务逻辑 |
| **State** | 不可变状态容器 | 可变字段 |
| **External** | 外部 API / SDK | 本地持久化 / 业务裁决 |

---

## 三、Controller 层规则（工程约束）

* Controller **只能调用**：
  * Command
  * Query
  * Analytics

* Controller **不允许**：
  * 直接写数据库
  * 推导学习 / 统计语义
  * 操作 Session 内部状态

> Controller 只负责编排，不负责裁决。

---

## 四、Repository 层规则

* Repository 只保证：
  * 单表一致性
  * 基本 CRUD

* Repository **不允许**：
  * join
  * count / group by
  * firstLearn / mastered 等业务判断

---

## 五、Query / Analytics 层规则

* **只读**
* 通过 `databaseProvider` 注入 Database
* 不允许：
  * 使用全局单例 Database
  * 写任何表
  * 推导学习事件

---

## 六、Command 层结构说明（重要）

Command 是**唯一写入口**，但写入路径在结构上是**正交的**：

| 写入类型 | 责任组件 | 是否经 Session |
|--------|---------|---------------|
| 状态写入 | `WordCommand / KanaCommand` | ❌ |
| 行为日志 | `WordCommand / ReviewCommand` | ❌ |
| 统计聚合 | `Session / DailyStatCommand` | ✅ |

> 结构层只声明「谁写」，不声明「何时写」  
> 具体语义由 freeze.md 冻结

---

## 七、Session 架构（工程层）

### 工程定位

Session 是**统计聚合工具**，不是通用写入口。

### 仅用于：

* Session 内统计累积
* flush 到 `daily_stats`

### 不用于：

* 状态写入
* 行为日志写入
* UI 触发行为

---

### Session 结构链路（固定）

```

SessionStatPolicy
→ SessionStatAccumulator
→ flush
→ DailyStatCommand

```

---

## 八、学习时长统计（结构说明）

* 数据来源：`PageDurationTracker`
* 写入口：`DailyStatCommand.applyTimeOnlyDelta`
* 不经过 Session
* 不产生行为日志

---

## 九、Debug 架构规则（工程级）

* Debug Feature：
  * 只能调用 Command / Query / Analytics
  * 不直连 Repository / Database

* Debug Command：
  * 不被正式 Feature 依赖
  * 不进入正式统计链路

---

## 十、模块依赖方向（冻结）

```

Feature
↓
Services
↓
Data
↓
Core

```

补充规则：

* Debug → Command / Query / Analytics
* Data 不依赖 Feature
* Core 不依赖任何上层模块

---

## 十一、目录结构声明

> 目录结构以当前代码为准  
> 本文档 **不负责维护目录树快照**

目录的任何调整：

* 不得破坏上述依赖方向
* 不得引入跨层访问

---

## 十二、Structure 文档冻结声明

> 本文档回答的问题是：
> **“这一层能不能依赖那一层”**
> **“这一类代码能不能做这类事”**

它不回答：

* 产品该怎么做
* 数据语义该如何解释

若出现冲突：

* **Freeze > Product > Structure > Tech**

---

### ⛔ Hard Stop

> **任何为了“少写一层”而破坏结构边界的行为，
> 都是架构错误，而不是工程优化。**

```

---