import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/common/widgets/issue_report_sheet.dart';
import '../controller/word_detail_controller.dart';
import '../widgets/word_detail_content.dart';

class WordDetailPage extends ConsumerStatefulWidget {
  final String wordId;

  const WordDetailPage({super.key, required this.wordId});

  @override
  ConsumerState<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends ConsumerState<WordDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wordDetailControllerProvider.notifier).loadWord(widget.wordId);
    });
  }

  @override
  void didUpdateWidget(covariant WordDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordId != widget.wordId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wordDetailControllerProvider.notifier).loadWord(widget.wordId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wordDetailControllerProvider);
    final detail = state.detail;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (detail != null)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 20),
              onPressed: () {
                IssueReportSheet.show(
                  context: context,
                  ref: ref,
                  contentType: 'word',
                  contentId: detail.word.id,
                  contentSnapshot: {
                    'word': detail.word.toMap(),
                    'rich_content': detail.richContent.toJsonString(),
                  },
                  displayTitle: detail.word.word,
                );
              },
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(state) {
    if (state.isLoading && state.detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.detail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ref.read(wordDetailControllerProvider.notifier).loadWord(widget.wordId);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final detail = state.detail;
    if (detail == null) {
      return const SizedBox.shrink();
    }

    return WordDetailContent(
      wordDetail: detail,
    );
  }
}