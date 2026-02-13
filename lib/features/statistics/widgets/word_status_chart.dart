import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/models/read/user_word_statistics.dart';

/// 单词状态分布环形图
class WordStatusChart extends StatelessWidget {
  final UserWordStatistics? distribution;

  const WordStatusChart({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    final dist = distribution;
    final hasData = dist != null && dist.totalWords > 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text(
            '单词状态分布',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  '暂无单词数据',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: _buildSections(dist),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildLegendColumn(dist),
              ],
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(UserWordStatistics dist) {
    final total = dist.totalWords.toDouble();
    final items = <_StatusItem>[
      _StatusItem('已曝光', dist.newWords, const Color(0xFF94A3B8)),
      _StatusItem('学习中', dist.learningWords, const Color(0xFF3B82F6)),
      _StatusItem('已掌握', dist.masteredWords, const Color(0xFF22C55E)),
      _StatusItem('已忽略', dist.ignoredWords, const Color(0xFFF59E0B)),
    ];

    return items.where((item) => item.count > 0).map((item) {
      final percentage = (item.count / total * 100);
      return PieChartSectionData(
        value: item.count.toDouble(),
        color: item.color,
        radius: 40,
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.55,
      );
    }).toList();
  }

  Widget _buildLegendColumn(UserWordStatistics dist) {
    final items = [
      _StatusItem('已曝光', dist.newWords, const Color(0xFF94A3B8)),
      _StatusItem('学习中', dist.learningWords, const Color(0xFF3B82F6)),
      _StatusItem('已掌握', dist.masteredWords, const Color(0xFF22C55E)),
      _StatusItem('已忽略', dist.ignoredWords, const Color(0xFFF59E0B)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${item.label}  ${item.count}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusItem {
  final String label;
  final int count;
  final Color color;

  const _StatusItem(this.label, this.count, this.color);
}
