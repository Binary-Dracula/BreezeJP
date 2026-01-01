/// Debug Only:
/// - 用于验证 firstLearn 是否只由 addWordToReview 写入
/// - 不参与任何统计
/// - 禁止在此页面触发学习行为
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/queries/debug_first_learn_query.dart';

class DebugFirstLearnInspectorPage extends ConsumerStatefulWidget {
  const DebugFirstLearnInspectorPage({
    super.key,
    required this.userId,
  });

  final int? userId;

  @override
  ConsumerState<DebugFirstLearnInspectorPage> createState() =>
      _DebugFirstLearnInspectorPageState();
}

class _DebugFirstLearnInspectorPageState
    extends ConsumerState<DebugFirstLearnInspectorPage> {
  late Future<_DebugFirstLearnData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug · FirstLearn Inspector'),
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
      body: FutureBuilder<_DebugFirstLearnData>(
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
          if (data == null || data.userId == null) {
            return const Center(
              child: Text('未指定 userId（使用 /debug/first-learn?userId=...）'),
            );
          }

          if (data.items.isEmpty) {
            return const Center(child: Text('暂无 firstLearn 日志'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = data.items[index];
              final timeLabel = _formatDateTime(item.createdAt);
              final todayLabel = item.isToday ? '  TODAY' : '';
              final line =
                  '[word_id=${item.wordId}]  $timeLabel$todayLabel';
              return Text(line);
            },
          );
        },
      ),
    );
  }

  Future<_DebugFirstLearnData> _loadData() async {
    final userId = widget.userId;
    if (userId == null) {
      return const _DebugFirstLearnData(userId: null, items: []);
    }

    final query = ref.read(debugFirstLearnQueryProvider);
    final items = await query.getRecentFirstLearns(userId);
    return _DebugFirstLearnData(userId: userId, items: items);
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}

class _DebugFirstLearnData {
  const _DebugFirstLearnData({
    required this.userId,
    required this.items,
  });

  final int? userId;
  final List<DebugFirstLearnItem> items;
}
