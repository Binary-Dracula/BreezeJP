import 'package:flutter/material.dart';

/// 概览卡片组（累计掌握 / 连续学习 / 总学时）
class OverviewCards extends StatelessWidget {
  final int masteredCount;
  final int streakDays;
  final int totalStudyTimeMs;

  const OverviewCards({
    super.key,
    required this.masteredCount,
    required this.streakDays,
    required this.totalStudyTimeMs,
  });

  @override
  Widget build(BuildContext context) {
    final hours = totalStudyTimeMs ~/ 3600000;
    final minutes = (totalStudyTimeMs % 3600000) ~/ 60000;
    final timeText = hours > 0 ? '$hours 小时 $minutes 分' : '$minutes 分钟';

    return Row(
      children: [
        Expanded(
          child: _OverviewCard(
            icon: Icons.workspace_premium_outlined,
            label: '累计掌握',
            value: '$masteredCount',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            icon: Icons.local_fire_department_rounded,
            label: '连续学习',
            value: '$streakDays 天',
            color: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            icon: Icons.timer_outlined,
            label: '总学时',
            value: timeText,
            color: const Color(0xFF0EA5E9),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
