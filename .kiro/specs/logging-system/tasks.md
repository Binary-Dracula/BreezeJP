# Implementation Plan

- [x] 1. Create LogCategory enum and LogFormatter utility class
  - [x] 1.1 Create LogCategory enum in `lib/core/utils/log_category.dart`
    - Define four categories: learn, db, audio, algo with their prefixes
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [x] 1.2 Create LogFormatter class in `lib/core/utils/log_formatter.dart`
    - Implement formatStudyWord() for single-line StudyWord summary
    - Implement formatSRSInput() and formatSRSOutput() with proper precision
    - Implement formatTimestamp() for ISO 8601 format
    - Implement formatDuration() for human-readable duration
    - Implement formatKeyValues() for consistent key=value formatting
    - Implement formatListSummary() for list with count and sample items
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 7.2, 7.3_
  - [ ]* 1.3 Write property tests for LogFormatter
    - **Property 6: Formatting Consistency**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**

- [x] 2. Extend AppLogger with categorized logging methods
  - [x] 2.1 Add learning flow logging methods to AppLogger
    - Implement learnSessionStart(), learnWordsLoaded(), learnWordView()
    - Implement learnAnswerSubmit(), learnSessionEnd()
    - Use [LEARN] prefix for all methods
    - _Requirements: 1.2, 2.1, 2.2, 2.3, 2.4, 2.5_
  - [x] 2.2 Add database operation logging methods to AppLogger
    - Implement dbQuery(), dbInsert(), dbUpdate(), dbDelete()
    - Implement dbError() with stack trace support
    - Use [DB] prefix for all methods
    - _Requirements: 1.3, 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 2.3 Add audio state logging methods to AppLogger
    - Implement audioPlayStart(), audioPlayComplete()
    - Implement audioPlayError(), audioStateChange()
    - Use [AUDIO] prefix for all methods
    - _Requirements: 1.4, 4.1, 4.2, 4.3, 4.4_
  - [x] 2.4 Add algorithm logging methods to AppLogger
    - Implement algoCalculateStart(), algoCalculateComplete()
    - Implement algoParamsUpdate(), algoScheduleChange()
    - Use [ALGO] prefix for all methods
    - _Requirements: 1.5, 5.1, 5.2, 5.3, 5.4_
  - [ ]* 2.5 Write property tests for categorized logging methods
    - **Property 1: Category Prefix Consistency**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Integrate logging into LearnController
  - [x] 4.1 Update LearnController to use new logging methods
    - Replace existing logger calls with categorized methods
    - Add learnSessionStart() in loadWords() when session starts
    - Add learnWordsLoaded() after loading review and new words
    - Add learnWordView() in onPageChanged()
    - Add learnAnswerSubmit() in submitAnswer()
    - Add learnSessionEnd() in endSession()
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  - [ ]* 4.2 Write property tests for learning flow logging
    - **Property 2: Learning Flow Log Completeness**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

- [x] 5. Integrate logging into Repository classes
  - [x] 5.1 Update StudyWordRepository to use new logging methods
    - Replace existing logger.database() calls with dbQuery(), dbInsert(), dbUpdate(), dbDelete()
    - Add dbError() for error cases
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 5.2 Update StudyLogRepository to use new logging methods
    - Replace existing logger calls with categorized db methods
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 5.3 Update other repositories (DailyStatRepository, UserRepository, WordRepository)
    - Apply consistent db logging across all repositories
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [ ]* 5.4 Write property tests for database operation logging
    - **Property 3: Database Operation Log Completeness**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

- [x] 6. Integrate logging into AudioService
  - [x] 6.1 Update AudioService to use new logging methods
    - Replace existing logger calls with audioPlayStart(), audioPlayComplete()
    - Add audioPlayError() for error cases
    - Add audioStateChange() for state transitions
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [ ]* 6.2 Write property tests for audio state logging
    - **Property 4: Audio State Log Completeness**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

- [x] 7. Integrate logging into AlgorithmService
  - [x] 7.1 Update AlgorithmService to use new logging methods
    - Add algoCalculateStart() before calculation
    - Add algoCalculateComplete() after calculation
    - _Requirements: 5.1, 5.2_
  - [x] 7.2 Update LearnController to log algorithm parameter updates
    - Add algoParamsUpdate() when updating StudyWord
    - Add algoScheduleChange() when schedule changes
    - _Requirements: 5.3, 5.4_
  - [ ]* 7.3 Write property tests for algorithm logging
    - **Property 5: Algorithm Log Completeness**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**

- [x] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Update SplashController and AppDatabase with logging
  - [x] 9.1 Update SplashController to use categorized logging
    - Add [LEARN] category logs for initialization flow
    - _Requirements: 2.1_
  - [x] 9.2 Update AppDatabase to use categorized logging
    - Add [DB] category logs for database initialization and copy operations
    - _Requirements: 3.1, 3.5_

- [x] 10. Update README documentation
  - [x] 10.1 Update lib/core/utils/README.md with new logging methods
    - Document all new categorized logging methods
    - Add usage examples for each category
    - Update best practices section
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 11. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
