import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/statistics_controller.dart';
import '../state/statistics_state.dart';
import '../widgets/overview_cards.dart';
import '../widgets/learning_trend_chart.dart';
import '../widgets/time_trend_chart.dart';
import '../widgets/learning_heatmap.dart';
import '../widgets/word_status_chart.dart';
import '../widgets/period_summary.dart';

/// 详细统计页面
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(statisticsControllerProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(statisticsControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          '详细统计',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        // 时段选择器固定在 AppBar 底部，不随页面滚动
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: _buildPeriodSelector(state),
          ),
        ),
      ),
      body: state.isLoading && state.trendData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.hasError && state.trendData.isEmpty
          ? _buildError(state)
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(statisticsControllerProvider.notifier).loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ─── 趋势分析区域（跟随时段切换） ───
                    LearningTrendChart(
                      data: state.trendData,
                      isMonthly: state.isMonthlyGranularity,
                    ),
                    const SizedBox(height: 16),
                    TimeTrendChart(
                      data: state.trendData,
                      isMonthly: state.isMonthlyGranularity,
                    ),
                    const SizedBox(height: 16),
                    PeriodSummary(
                      activeDays: state.activeDays,
                      avgNewLearned: state.avgNewLearned,
                      avgReviewed: state.avgReviewed,
                      avgTimeMinutes: state.avgTimeMinutes,
                    ),

                    // ─── 分隔：学习总览（不受时段影响） ───
                    const SizedBox(height: 28),
                    _buildSectionHeader('学习总览'),
                    const SizedBox(height: 12),

                    OverviewCards(
                      masteredCount: state.masteredCount,
                      streakDays: state.streakDays,
                      totalStudyTimeMs: state.totalStudyTimeMs,
                    ),
                    const SizedBox(height: 16),
                    LearningHeatmap(data: state.heatmapData),
                    const SizedBox(height: 16),
                    WordStatusChart(distribution: state.wordDistribution),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// 时段选择器
  Widget _buildPeriodSelector(StatisticsState state) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: StatsPeriod.values.map((period) {
          final isSelected = state.period == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(statisticsControllerProvider.notifier)
                  .switchPeriod(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _periodLabel(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 区域分割标题
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  String _periodLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.week:
        return '本周';
      case StatsPeriod.month:
        return '本月';
      case StatsPeriod.all:
        return '全部';
    }
  }

  Widget _buildError(StatisticsState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(state.error ?? '加载失败'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(statisticsControllerProvider.notifier).loadData(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
