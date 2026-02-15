import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/learning_status.dart';
import '../controller/grammar_controller.dart';
import '../state/grammar_state.dart';
import '../widgets/grammar_card.dart';

class GrammarLearningPage extends ConsumerStatefulWidget {
  final int grammarId;

  const GrammarLearningPage({super.key, required this.grammarId});

  @override
  ConsumerState<GrammarLearningPage> createState() =>
      _GrammarLearningPageState();
}

class _GrammarLearningPageState extends ConsumerState<GrammarLearningPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(grammarControllerProvider.notifier)
          .initWithGrammar(widget.grammarId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(grammarControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Optional: Menu for "Ignore" or "Report"
        ],
      ),
      body: _buildBody(state),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildBody(GrammarState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${state.error}'),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(grammarControllerProvider.notifier)
                    .initWithGrammar(widget.grammarId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.studyQueue.isEmpty) {
      return const Center(child: Text('没有内容'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: state.studyQueue.length,
      onPageChanged: (index) {
        ref.read(grammarControllerProvider.notifier).onPageChanged(index);
      },
      itemBuilder: (context, index) {
        final detail = state.studyQueue[index];
        return GrammarCard(detail: detail);
      },
    );
  }

  Widget? _buildBottomBar(GrammarState state) {
    final currentDetail = state.currentGrammarDetail;
    if (currentDetail == null) return null;

    final status = currentDetail.userState;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (status == LearningStatus.seen) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(grammarControllerProvider.notifier).addToReview();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('加入复习'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C8DFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(grammarControllerProvider.notifier)
                        .markAsMastered();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('已掌握'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    side: const BorderSide(color: Color(0xFF34D399)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
