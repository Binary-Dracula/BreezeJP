import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/providers/home_summary_invalidation_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/queries/home_query.dart';
import '../state/home_state.dart';

/// HomeController Provider
final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

/// 主页控制器
class HomeController extends Notifier<HomeState> {
  static const _guestState = HomeState(isInitialized: true);
  Future<void>? _refreshInFlight;
  bool _refreshQueued = false;

  @override
  HomeState build() {
    ref.listen<bool>(isLoggedInProvider, (previous, next) {
      if (previous == next) {
        return;
      }

      if (!next) {
        state = _guestState;
        return;
      }

      if (!state.isLoading) {
        Future<void>.microtask(() async {
          if (!ref.mounted) {
            return;
          }
          await loadHomeData();
        });
      }
    });

    ref.listen<int>(homeSummaryInvalidationProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      if (!ref.read(isLoggedInProvider) || !state.isInitialized) {
        return;
      }
      unawaited(_scheduleRefresh());
    });

    if (ref.watch(isLoggedInProvider)) {
      Future<void>.microtask(() async {
        if (!ref.mounted) {
          return;
        }
        if (!state.isInitialized && !state.isLoading) {
          await loadHomeData();
        }
      });
    }

    return const HomeState();
  }

  HomeQuery get _homeQuery => ref.read(homeQueryProvider);

  /// 加载主页数据
  Future<void> loadHomeData() async {
    try {
      if (!ref.read(isLoggedInProvider)) {
        logger.debug('游客模式，跳过主页远端加载');
        state = _guestState;
        return;
      }

      logger.debug('开始加载主页数据');
      state = state.copyWith(isLoading: true, error: null);

      final summary = await _homeQuery.fetchHomeSummary();
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        userName: summary.userName,
        reviewCount: summary.reviewCount,
        kanaReviewCount: summary.kanaReviewCount,
        masteredWordCount: summary.masteredWordCount,
        isInitialized: true,
      );

      logger.debug('主页数据加载成功');
    } catch (e, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      logger.error('加载主页数据失败', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        error: '加载失败: $e',
      );
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadHomeData();
  }

  Future<void> _scheduleRefresh() async {
    if (_refreshInFlight != null) {
      _refreshQueued = true;
      await _refreshInFlight;
      return;
    }

    final completer = Completer<void>();
    _refreshInFlight = completer.future;

    try {
      do {
        _refreshQueued = false;
        await loadHomeData();
      } while (_refreshQueued);
      completer.complete();
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
