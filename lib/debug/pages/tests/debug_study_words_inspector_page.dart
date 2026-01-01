import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/queries/debug_study_words_query.dart';

class DebugStudyWordsInspectorPage extends ConsumerStatefulWidget {
  const DebugStudyWordsInspectorPage({
    super.key,
    int? userId,
  });

  @override
  ConsumerState<DebugStudyWordsInspectorPage> createState() =>
      _DebugStudyWordsInspectorPageState();
}

class _DebugStudyWordsInspectorPageState
    extends ConsumerState<DebugStudyWordsInspectorPage> {
  late Future<DebugStudyWordsResult> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug · StudyWords Inspector'),
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
      body: FutureBuilder<DebugStudyWordsResult>(
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
            return const Center(child: Text('暂无 study_words 数据'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = data.items[index];
              final createdAt = _formatTime(item.createdAt);
              final updatedAt = _formatTime(item.updatedAt);
              final nextReview = item.nextReviewAt != null ? '✔' : '—';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('[word_id=${item.wordId}] ${item.displayWord}'),
                  Text(
                    'state=${item.stateLabel} nextReview=$nextReview '
                    'created=$createdAt updated=$updatedAt',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<DebugStudyWordsResult> _loadData() async {
    final query = ref.read(debugStudyWordsQueryProvider);
    return query.getStudyWordsForActiveUser();
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
