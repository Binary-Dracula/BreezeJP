import 'package:flutter/material.dart';

import '../../../data/models/read/daily_stat_stats.dart';

/// GitHub 风格学习热力图 — 严格复刻 GitHub Contribution Graph
/// 横向 53 周列，纵向 7 行（Sun-Sat），今天定位于最右列最后一个活跃行
class LearningHeatmap extends StatelessWidget {
  final List<DailyStatHeatmapItem> data;

  const LearningHeatmap({super.key, required this.data});

  // GitHub 绿色色阶
  static const _level0 = Color(0xFFEBEDF0);
  static const _level1 = Color(0xFF9BE9A8);
  static const _level2 = Color(0xFF40C463);
  static const _level3 = Color(0xFF30A14E);
  static const _level4 = Color(0xFF216E39);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text(
                '学习热力图',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '最近 12 个月',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 热力图（可横向滚动）
          LayoutBuilder(
            builder: (context, constraints) {
              return _GitHubHeatmapGrid(
                data: data,
                availableWidth: constraints.maxWidth,
              );
            },
          ),
          const SizedBox(height: 10),
          // 图例
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Less',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(width: 4),
        for (final color in [_level0, _level1, _level2, _level3, _level4])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          'More',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

/// GitHub Contribution Graph 布局核心
///
/// GitHub 的规则：
///  - 列 = 周（Sun 起始），最右列 = 本周，最左列 = 52 周前那一周
///  - 行 = 星期几 (Sun=0 ... Sat=6)，GitHub 默认 Sun 在顶
///  - 月份标签标注在每月第一周所在列的顶部
class _GitHubHeatmapGrid extends StatelessWidget {
  final List<DailyStatHeatmapItem> data;
  final double availableWidth;

  const _GitHubHeatmapGrid({required this.data, required this.availableWidth});

  // GitHub 用 Sunday 作为每周第一天
  static const _dayLabels = ['', 'Mon', '', 'Wed', '', 'Fri', ''];

  @override
  Widget build(BuildContext context) {
    // 1. Build date->count map
    final dataMap = <String, int>{};
    int maxCount = 1;
    for (final item in data) {
      dataMap[item.date] = item.count;
      if (item.count > maxCount) maxCount = item.count;
    }

    // 2. Build 53 weeks of dates, ending at today
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Find Sunday of this week (GitHub weeks start Sunday)
    final thisSunday = todayDate.subtract(
      Duration(days: todayDate.weekday % 7),
    );
    // Go back 52 weeks to the starting Sunday
    final startSunday = thisSunday.subtract(const Duration(days: 52 * 7));

    // Generate all weeks
    final weeks = <List<DateTime>>[];
    var weekStart = startSunday;
    while (!weekStart.isAfter(thisSunday)) {
      final week = List.generate(7, (d) => weekStart.add(Duration(days: d)));
      weeks.add(week);
      weekStart = weekStart.add(const Duration(days: 7));
    }

    final numWeeks = weeks.length; // Should be 53

    // 3. Determine month labels
    // Only label a column if it contains the 1st of a month
    final monthLabels = <int, String>{};
    for (var w = 0; w < numWeeks; w++) {
      for (final day in weeks[w]) {
        if (day.day == 1) {
          monthLabels[w] = _monthAbbr(day.month);
          break;
        }
      }
    }

    // 4. Layout calculations
    const dayLabelWidth = 32.0;
    const cellGap = 3.0;
    const cellSize = 11.0;
    final totalGridWidth = numWeeks * cellSize + (numWeeks - 1) * cellGap;
    final needsScroll = (dayLabelWidth + totalGridWidth) > availableWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels + grid
        SizedBox(
          height: (cellSize + cellGap) * 7 + 16, // 7 rows + month label row
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day-of-week labels (left)
              SizedBox(
                width: dayLabelWidth,
                child: Column(
                  children: [
                    // Spacer for month label row
                    const SizedBox(height: 16),
                    // Day labels
                    ...List.generate(7, (i) {
                      return SizedBox(
                        height: cellSize + cellGap,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _dayLabels[i],
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Grid (scrollable if needed)
              Expanded(
                child: needsScroll
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true, // Start showing the most recent
                        child: _buildGrid(
                          weeks,
                          monthLabels,
                          dataMap,
                          maxCount,
                          todayDate,
                          cellSize,
                          cellGap,
                        ),
                      )
                    : _buildGrid(
                        weeks,
                        monthLabels,
                        dataMap,
                        maxCount,
                        todayDate,
                        cellSize,
                        cellGap,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(
    List<List<DateTime>> weeks,
    Map<int, String> monthLabels,
    Map<String, int> dataMap,
    int maxCount,
    DateTime todayDate,
    double cellSize,
    double cellGap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels row
        SizedBox(
          height: 16,
          child: Row(
            children: List.generate(weeks.length, (w) {
              final label = monthLabels[w];
              return SizedBox(
                width: cellSize + cellGap,
                child: label != null
                    ? Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }),
          ),
        ),
        // Cell grid: 7 rows x N columns
        ...List.generate(7, (dayIndex) {
          return SizedBox(
            height: cellSize + cellGap,
            child: Row(
              children: List.generate(weeks.length, (w) {
                final day = weeks[w][dayIndex];
                final isFuture = day.isAfter(todayDate);
                final dateStr = _formatDate(day);
                final count = dataMap[dateStr] ?? 0;

                return Padding(
                  padding: EdgeInsets.only(right: cellGap),
                  child: isFuture
                      ? SizedBox(width: cellSize, height: cellSize)
                      : Tooltip(
                          message: '$dateStr: $count',
                          waitDuration: const Duration(milliseconds: 300),
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: _getColor(count, maxCount),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  Color _getColor(int count, int maxCount) {
    if (count == 0) return LearningHeatmap._level0;
    final ratio = count / maxCount;
    if (ratio <= 0.25) return LearningHeatmap._level1;
    if (ratio <= 0.50) return LearningHeatmap._level2;
    if (ratio <= 0.75) return LearningHeatmap._level3;
    return LearningHeatmap._level4;
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _monthAbbr(int month) {
    const abbrs = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return abbrs[month];
  }
}
