# Requirements Document

## Introduction

本文档定义了 BreezeJP 应用的日志系统规范化需求。目标是系统性整理所有日志输出，包括学习流程、数据库操作、音频状态和算法状态，确保日志输出统一、清晰、易于调试。

## Glossary

- **AppLogger**: 应用日志工具类，基于 `logger` 包封装，提供统一的日志输出接口
- **LogCategory**: 日志分类，用于区分不同模块的日志输出
- **LogLevel**: 日志级别，包括 trace、debug、info、warning、error、fatal
- **SRS**: 间隔重复系统（Spaced Repetition System），用于记忆算法
- **StudySession**: 学习会话，从用户开始学习到结束的完整流程

## Requirements

### Requirement 1

**User Story:** As a developer, I want categorized logging methods, so that I can easily filter and identify logs from different modules.

#### Acceptance Criteria

1. WHEN a log message is created THEN the AppLogger SHALL prefix the message with a category identifier (e.g., [LEARN], [DB], [AUDIO], [ALGO])
2. WHEN logging a learning flow event THEN the AppLogger SHALL use the [LEARN] category prefix
3. WHEN logging a database operation THEN the AppLogger SHALL use the [DB] category prefix
4. WHEN logging an audio state change THEN the AppLogger SHALL use the [AUDIO] category prefix
5. WHEN logging an algorithm calculation THEN the AppLogger SHALL use the [ALGO] category prefix

### Requirement 2

**User Story:** As a developer, I want comprehensive learning flow logging, so that I can trace the complete user learning journey.

#### Acceptance Criteria

1. WHEN a learning session starts THEN the AppLogger SHALL log the session start with user ID and timestamp
2. WHEN words are loaded into the study queue THEN the AppLogger SHALL log the count of review words and new words separately
3. WHEN a user views a word THEN the AppLogger SHALL log the word ID and current queue position
4. WHEN a user submits an answer THEN the AppLogger SHALL log the rating, word ID, and resulting SRS parameters
5. WHEN a learning session ends THEN the AppLogger SHALL log the session duration, words learned count, and words reviewed count

### Requirement 3

**User Story:** As a developer, I want detailed database operation logging, so that I can monitor and debug data persistence issues.

#### Acceptance Criteria

1. WHEN a database query executes THEN the AppLogger SHALL log the operation type, table name, and query parameters
2. WHEN a database insert completes THEN the AppLogger SHALL log the table name, inserted ID, and key field values
3. WHEN a database update completes THEN the AppLogger SHALL log the table name, affected row count, and updated fields
4. WHEN a database delete completes THEN the AppLogger SHALL log the table name and deleted row count
5. WHEN a database error occurs THEN the AppLogger SHALL log the error message, SQL statement, and stack trace

### Requirement 4

**User Story:** As a developer, I want audio state logging, so that I can diagnose audio playback issues.

#### Acceptance Criteria

1. WHEN audio playback starts THEN the AppLogger SHALL log the audio source type (word/example), source URL or filename, and word ID
2. WHEN audio playback completes THEN the AppLogger SHALL log the completion status and playback duration
3. WHEN audio playback fails THEN the AppLogger SHALL log the error type, source information, and error message
4. WHEN audio state changes THEN the AppLogger SHALL log the previous state and new state (playing, paused, stopped)

### Requirement 5

**User Story:** As a developer, I want algorithm state logging, so that I can verify SRS calculations and debug scheduling issues.

#### Acceptance Criteria

1. WHEN an SRS calculation starts THEN the AppLogger SHALL log the algorithm type (SM-2/FSRS) and input parameters
2. WHEN an SRS calculation completes THEN the AppLogger SHALL log the output parameters including new interval, ease factor, and next review date
3. WHEN algorithm parameters are updated in the database THEN the AppLogger SHALL log the before and after values for key parameters
4. WHEN a word's review schedule changes THEN the AppLogger SHALL log the word ID, old schedule, and new schedule

### Requirement 6

**User Story:** As a developer, I want a log formatting utility, so that complex data structures are logged in a readable format.

#### Acceptance Criteria

1. WHEN logging a StudyWord object THEN the AppLogger SHALL format it as a single-line summary with key fields (id, wordId, state, interval, nextReview)
2. WHEN logging SRS input/output THEN the AppLogger SHALL format numeric values with appropriate precision (2 decimal places for intervals, 3 for factors)
3. WHEN logging timestamps THEN the AppLogger SHALL format them in ISO 8601 format with local timezone
4. WHEN logging duration values THEN the AppLogger SHALL format them in human-readable format (e.g., "2m 30s" instead of "150000ms")

### Requirement 7

**User Story:** As a developer, I want log output to be consistent across all modules, so that logs are easy to read and parse.

#### Acceptance Criteria

1. WHEN any module logs a message THEN the log format SHALL follow the pattern: "[CATEGORY] action: details"
2. WHEN logging key-value pairs THEN the AppLogger SHALL use consistent separators (key=value, comma-separated)
3. WHEN logging lists or arrays THEN the AppLogger SHALL include the count and first few items
4. WHEN logging errors THEN the AppLogger SHALL include the error type, message, and relevant context
