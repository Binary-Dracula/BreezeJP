import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/queries/debug_study_logs_query.dart';

class DebugStudyLogsInspectorPage extends ConsumerStatefulWidget {
  const DebugStudyLogsInspectorPage({
    super.key,
    int? userId,
  });

  @override
  ConsumerState<DebugStudyLogsInspectorPage> createState() =>
      _DebugStudyLogsInspectorPageState();
}

class _DebugStudyLogsInspectorPageState
    extends ConsumerState<DebugStudyLogsInspectorPage> {
  late Future<DebugStudyLogsResult> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug · StudyLogs Inspector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _dataFuture = _loadData();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<DebugStudyLogsResult>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null || data.userId == null) {
            return const Center(
              child: Text('未检测到当前用户（active user）'),
            );
          }

          if (data.items.isEmpty) {
            return const Center(child: Text('暂无 study_logs 数据'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = data.items[index];
              final timeLabel = _formatTime(item.createdAt);
              final todayLabel = item.isToday ? ' TODAY' : '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${item.id} [word_id=${item.wordId}] ${item.displayWord}'),
                  Text(
                    'log_type=${item.logTypeLabel} '
                    'created_at=$timeLabel$todayLabel',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<DebugStudyLogsResult> _loadData() async {
    final query = ref.read(debugStudyLogsQueryProvider);
    return query.getStudyLogsForActiveUser();
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
