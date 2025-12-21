# Architecture Audit Report

## Summary
Not ready to freeze: controllers still touch repository/DB directly, multiple Query/Analytics classes bypass `databaseProvider`, debug code breaks data-layer boundaries, and Session stats drop `kanaReview` deltas.

## Blockers

| Rule | File | Evidence | Fix |
| --- | --- | --- | --- |
| Controller must not access DB; must call Command/Query/Analytics only | `lib/features/splash/controller/splash_controller.dart` | `import '../../../data/db/app_database.dart';` and `final db = await AppDatabase.instance.database;` (`_initializeDatabase`) | Move DB init/check into a Command/Query; controller calls that API instead of `AppDatabase` directly. |
| Controller must not depend on Repository layer | `lib/features/learn/controller/learn_controller.dart` (plus `home`, `initial_choice`, `kana_chart`, `kana_stroke`, `kana/review`) | `import '../../../data/repositories/active_user_provider.dart';` and `ref.read(activeUserProvider.future)` (see `learn_controller.dart:4,26-28`) | Replace `activeUserProvider` usage with a Query/Command provider (e.g., `activeUserQueryProvider`), and update controllers to read that instead. |
| Repository layer must be CRUD-only; no behavior/side effects | `lib/data/repositories/active_user_provider.dart` | Provider performs cross-repository logic and writes (`createUser`, `setCurrentUserId`): `await userRepository.createUser(...)` + `await appStateRepository.setCurrentUserId(...)` | Move this flow into Command (write) + Query (read) layer; keep `repositories/` as pure CRUD. |
| Query/Analytics must inject Database via `databaseProvider` (no direct `AppDatabase.instance`) | `lib/data/queries/daily_stat_query.dart`, `lib/data/queries/study_word_query.dart`, `lib/data/queries/study_log_query.dart`, `lib/data/queries/word_read_queries.dart`, `lib/data/analytics/word_analytics.dart`, `lib/data/analytics/study_word_analytics.dart` | `Future<Database> get _db async => await AppDatabase.instance.database;` (e.g., `daily_stat_query.dart:15`, `study_word_query.dart:14`, `study_log_query.dart:15`, `word_read_queries.dart:29`, `word_analytics.dart:14`, `study_word_analytics.dart:14`) | Inject `Database` via `databaseProvider` in each provider + constructor; remove `AppDatabase` usage from Query/Analytics. |
| Debug must only use Query/Command; no direct DB or Repository | `lib/debug/tools/debug_kana_review_data_generator.dart`, `lib/debug/tmp/debug_kana_review_tmp.dart` | `final db = await AppDatabase.instance.database;` (`debug_kana_review_data_generator.dart:13`), and `import '../../data/repositories/active_user_provider.dart';` + `ref.read(activeUserProvider.future)` (`debug_kana_review_tmp.dart:11,34`) | Refactor debug tools to use Query/Command providers (and an ActiveUser Query/Command) instead of DB/Repository direct access. |
| Session stats must flow from `SessionStatPolicy` → accumulator → `applySession` without loss | `lib/data/commands/session/session_stat_policy.dart`, `lib/data/commands/session/study_session_handle.dart`, `lib/data/commands/daily_stat_command.dart` | `SessionStatAccumulator` tracks `kanaReviewCount` + `deltaFor(SessionEventType.kanaReview)` increments it, but `StudySessionHandle.flush()` only passes `learned/reviewed/failed/mastered` to `applySession`, and `applySession` has no `kanaReviewed` parameter | Extend `applySession` + `flush()` to include `kanaReviewCount` (or map `kanaReview` to the correct stats field) so kana review events update `daily_stats`. |

## Debts

| Rule | File | Evidence | Fix |
| --- | --- | --- | --- |
| Query layer should own read/list/paging APIs (single-table reads currently split) | `lib/data/repositories/study_log_repository.dart` | Repository exposes list/filter reads like `getUserLogs`, `getLogsByDateRange`, `getLogsByType` | Consider moving list/filter reads into `StudyLogQuery` to keep repository minimal CRUD. |
| Query layer access style should be consistent (DB vs repository mix) | `lib/data/queries/word_read_queries.dart` | Same class uses repositories (`wordRepository`, `wordMeaningRepository`) and direct DB `rawQuery` (`getWordListItems`) | Optionally split: keep read-join logic in Query with injected DB, and route entity CRUD through repositories consistently. |

## Auto-fix candidates

- Convert Query/Analytics constructors to accept `Database` and wire providers to `databaseProvider` for: `daily_stat_query.dart`, `study_word_query.dart`, `study_log_query.dart`, `word_read_queries.dart`, `word_analytics.dart`, `study_word_analytics.dart`.
- Replace `active_user_provider` imports in controllers with a new Query/Command provider (mechanical import + call-site swap once provider exists).
- Rewrite `debug_kana_review_data_generator.dart` to use `KanaQuery`/`KanaCommand` and an ActiveUser Query/Command instead of direct `AppDatabase` calls.

## Recommended next step

A) Migrate Query/Analytics to `databaseProvider` injection (touch 6 files, no behavior change).
B) Move `active_user_provider` logic into Command/Query and update controllers to stop using repositories.
C) Fix Session stats plumbing for `kanaReview` (propagate `kanaReviewCount` to `DailyStatCommand.applySession`).
