import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daily_stat.dart';
import '../../data/queries/active_user_query_provider.dart';
import '../../data/queries/daily_stat_query.dart';
import '../../data/queries/mastered_count_query.dart';

class DebugStatisticsPage extends ConsumerStatefulWidget {
  const DebugStatisticsPage({super.key});

  @override
  ConsumerState<DebugStatisticsPage> createState() =>
      _DebugStatisticsPageState();
}

class _DebugStatisticsPageState extends ConsumerState<DebugStatisticsPage> {
  late Future<_DebugStatisticsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计调试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _dataFuture = _loadStatistics();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<_DebugStatisticsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('加载失败：${snapshot.error}'),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('未获取到统计数据'));
          }
          if (data.userId == null) {
            return const Center(child: Text('未找到活跃用户'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTodayStatsCard(data),
              const SizedBox(height: 12),
              _buildStreakDebugCard(data),
              const SizedBox(height: 12),
              _buildMasteredDebugCard(data),
              const SizedBox(height: 12),
              _buildDailyStatsTable(data.recentStats),
            ],
          );
        },
      ),
    );
  }

  Future<_DebugStatisticsData> _loadStatistics() async {
    final userId = await ref.read(activeUserQueryProvider).getActiveUserId();
    if (userId == null) {
      return _DebugStatisticsData.empty();
    }

    final dailyStatQuery = ref.read(dailyStatQueryProvider);
    final masteredQuery = ref.read(masteredStateQueryProvider);

    final streak = await dailyStatQuery.calculateStreak(userId);
    final recentStats = await dailyStatQuery.getRecentDailyStats(
      userId,
      days: 14,
    );

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final todayStr = _formatDate(today);
    final yesterdayStr = _formatDate(yesterday);

    final todayStat = _findStatByDate(recentStats, todayStr);
    final yesterdayStat = _findStatByDate(recentStats, yesterdayStr);

    final todayNewLearned = todayStat?.newLearnedCount ?? 0;
    final todayReviewCount = todayStat?.reviewCount ?? 0;
    final todayTotalTimeMs = todayStat?.totalTimeMs ?? 0;
    final todayActive = todayStat?.hasActivity ?? false;
    final anchorHit =
        (todayStat?.hasActivity ?? false) || (yesterdayStat?.hasActivity ?? false);

    final masteredWordCount = await masteredQuery.getWordMasteredCount(userId);
    final masteredKanaCount = await masteredQuery.getKanaMasteredCount(userId);

    return _DebugStatisticsData(
      userId: userId,
      todayNewLearned: todayNewLearned,
      todayReviewCount: todayReviewCount,
      todayTotalTimeMs: todayTotalTimeMs,
      todayActive: todayActive,
      streak: streak,
      todayDate: todayStr,
      yesterdayDate: yesterdayStr,
      anchorHit: anchorHit,
      masteredWordCount: masteredWordCount,
      masteredKanaCount: masteredKanaCount,
      recentStats: recentStats,
    );
  }

  Widget _buildTodayStatsCard(_DebugStatisticsData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日统计',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildKeyValue('新学数', '${data.todayNewLearned}'),
            _buildKeyValue('复习数', '${data.todayReviewCount}'),
            _buildKeyValue(
              '总时长',
              _formatDurationMs(data.todayTotalTimeMs),
            ),
            _buildKeyValue('是否活跃', '${data.todayActive}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakDebugCard(_DebugStatisticsData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '连续学习',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildKeyValue('连续天数', '${data.streak}'),
            _buildKeyValue('今日日期', data.todayDate),
            _buildKeyValue('昨日日期', data.yesterdayDate),
            _buildKeyValue('锚点命中', '${data.anchorHit}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteredDebugCard(_DebugStatisticsData data) {
    final total = data.masteredWordCount + data.masteredKanaCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '累计掌握',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildKeyValue('单词已掌握', '${data.masteredWordCount}'),
            _buildKeyValue('假名已掌握', '${data.masteredKanaCount}'),
            _buildKeyValue('合计', '$total'),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyStatsTable(List<DailyStat> stats) {
    final rows = [...stats]
      ..sort((a, b) => b.dateString.compareTo(a.dateString));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每日统计表（最近14天）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Text('暂无每日统计数据')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('日期')),
                    DataColumn(label: Text('新学')),
                    DataColumn(label: Text('复习')),
                    DataColumn(label: Text('时长(毫秒)')),
                    DataColumn(label: Text('是否活跃')),
                  ],
                  rows: rows
                      .map(
                        (stat) => DataRow(
                          cells: [
                            DataCell(Text(stat.dateString)),
                            DataCell(Text('${stat.newLearnedCount}')),
                            DataCell(Text('${stat.reviewCount}')),
                            DataCell(Text('${stat.totalTimeMs}')),
                            DataCell(Text('${stat.hasActivity}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDurationMs(int ms) {
    if (ms <= 0) return '0毫秒';
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) return '${seconds}秒（${ms}毫秒）';
    return '${minutes}分 ${seconds}秒（${ms}毫秒）';
  }

  DailyStat? _findStatByDate(List<DailyStat> stats, String dateStr) {
    for (final stat in stats) {
      if (stat.dateString == dateStr) {
        return stat;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _DebugStatisticsData {
  final int? userId;
  final int todayNewLearned;
  final int todayReviewCount;
  final int todayTotalTimeMs;
  final bool todayActive;
  final int streak;
  final String todayDate;
  final String yesterdayDate;
  final bool anchorHit;
  final int masteredWordCount;
  final int masteredKanaCount;
  final List<DailyStat> recentStats;

  const _DebugStatisticsData({
    required this.userId,
    required this.todayNewLearned,
    required this.todayReviewCount,
    required this.todayTotalTimeMs,
    required this.todayActive,
    required this.streak,
    required this.todayDate,
    required this.yesterdayDate,
    required this.anchorHit,
    required this.masteredWordCount,
    required this.masteredKanaCount,
    required this.recentStats,
  });

  factory _DebugStatisticsData.empty() {
    return _DebugStatisticsData(
      userId: null,
      todayNewLearned: 0,
      todayReviewCount: 0,
      todayTotalTimeMs: 0,
      todayActive: false,
      streak: 0,
      todayDate: '',
      yesterdayDate: '',
      anchorHit: false,
      masteredWordCount: 0,
      masteredKanaCount: 0,
      recentStats: const [],
    );
  }
}
