---
inclusion: always
---

# 项目架构与文件组织

## 架构模式

功能优先架构（Feature-First），按功能模块组织代码：

```
lib/
├── core/              # 共享层
│   ├── constants/     # 应用级常量
│   ├── utils/         # 工具函数
│   └── widgets/       # 可复用 UI 组件
├── data/              # 数据层
│   ├── db/            # 数据库管理（AppDatabase 单例）
│   ├── models/        # 数据模型（Word、ExampleSentence 等）
│   └── repositories/  # 数据访问层（Repository 模式）
├── features/          # 功能模块
│   ├── learn/         # 学习功能
│   ├── review/        # 复习功能
│   ├── settings/      # 设置功能
│   └── word_detail/   # 单词详情
├── router/            # 路由配置（go_router）
├── services/          # 业务逻辑服务
└── main.dart          # 应用入口
```

## 功能模块结构

每个功能模块遵循统一结构：

```
features/[功能名]/
├── controller/    # Riverpod 控制器
├── pages/         # 页面级组件（路由目标）
├── state/         # 状态类定义
└── widgets/       # 功能内可复用组件
```

## 文件放置规则

### 新建数据模型
- 路径：`lib/data/models/`
- 必须实现：`fromMap()` 和 `toMap()`
- 示例：`lib/data/models/word.dart`

### 新建功能
- 路径：`lib/features/[功能名]/`
- 创建子目录：`controller/`、`pages/`、`state/`、`widgets/`
- 页面组件放在 `pages/`，可复用组件放在 `widgets/`

### 新建 Repository
- 路径：`lib/data/repositories/`
- 命名：`[实体名]_repository.dart`（例：`word_repository.dart`）
- 通过 `AppDatabase.instance` 访问数据库

### 新建共享组件
- 路径：`lib/core/widgets/`
- 用于跨功能模块复用的 UI 组件

### 新建工具函数
- 路径：`lib/core/utils/`
- 纯函数，无状态

## 资源文件组织

```
assets/
├── audio/
│   ├── words/      # 单词音频（命名：单词_romaji_voice_source.mp3）
│   └── examples/   # 例句音频（命名：sentence_[id]_voice_source.mp3）
├── database/
│   └── breeze_jp.sqlite  # 预置数据库
└── images/         # 图片资源
```

## 数据库访问模式

```dart
// 获取数据库实例
final db = await AppDatabase.instance.database;

// 查询示例
final results = await db.query('words', where: 'jlpt_level = ?', whereArgs: ['N5']);
```

## 测试文件组织

测试文件镜像源代码结构：

```
test/
├── features/       # 功能测试
└── utils/          # 工具函数测试
```
