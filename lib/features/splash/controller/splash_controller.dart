import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/db/app_database.dart';
import '../../../core/utils/app_logger.dart';
import '../state/splash_state.dart';

/// Splash 控制器 Provider
final splashControllerProvider =
    NotifierProvider<SplashController, SplashState>(SplashController.new);

/// Splash 控制器 - 管理应用初始化流程
class SplashController extends Notifier<SplashState> {
  @override
  SplashState build() => const SplashState();

  /// 执行初始化流程
  Future<void> initialize(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // 记录初始化流程开始
    logger.learnSessionStart(userId: 1);
    logger.info('[LEARN] app_init_start: initializing application');

    try {
      state = state.copyWith(
        isLoading: true,
        message: l10n.splashInitializing,
        error: null,
      );

      // 1. 初始化数据库
      state = state.copyWith(message: l10n.splashLoadingDatabase);
      logger.info('[LEARN] init_step: step=database_init');
      await _initializeDatabase(l10n);

      // 2. 可以在这里添加其他初始化任务
      // 例如：加载用户设置、检查更新等
      await Future.delayed(const Duration(milliseconds: 500));

      // 初始化完成
      state = state.copyWith(
        isLoading: false,
        message: l10n.splashInitComplete,
        isInitialized: true,
      );
      logger.info('[LEARN] app_init_complete: initialization successful');
    } catch (e) {
      logger.error('[LEARN] app_init_error: error="${e.toString()}"');
      state = state.copyWith(
        isLoading: false,
        error: l10n.splashInitFailed(e.toString()),
        isInitialized: false,
      );
    }
  }

  /// 初始化数据库
  Future<void> _initializeDatabase(AppLocalizations l10n) async {
    try {
      // 触发数据库初始化（如果需要会从 assets 复制）
      final db = await AppDatabase.instance.database;

      // 验证数据库是否正常
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
      final count = result.first['count'] as int;

      logger.dbQuery(table: 'words', where: 'COUNT(*)', resultCount: count);

      if (count == 0) {
        throw Exception(l10n.databaseEmpty);
      }

      logger.info('[LEARN] database_verified: wordCount=$count');
    } catch (e) {
      logger.dbError(operation: 'INIT', table: 'words', dbError: e);
      throw Exception(l10n.databaseInitFailed(e.toString()));
    }
  }
}
