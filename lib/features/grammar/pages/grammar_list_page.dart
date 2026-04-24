import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/learning_status.dart';
import '../controller/grammar_list_controller.dart';
import '../providers/grammar_status_refresh_provider.dart';
import '../state/grammar_list_state.dart';

class GrammarListPage extends ConsumerStatefulWidget {
  const GrammarListPage({super.key});

  @override
  ConsumerState<GrammarListPage> createState() => _GrammarListPageState();
}

class _GrammarListPageState extends ConsumerState<GrammarListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _levels = ['n5', 'n4', 'n3', 'n2', 'n1'];

  @override
  void initState() {
    super.initState();
    // 从 Provider 读取当前的 Level，确定初始 Tab 索引
    final currentLevel = ref.read(grammarListControllerProvider).selectedLevel;
    final initialIndex = _levels.indexOf(currentLevel ?? 'n5');

    _tabController = TabController(
      length: _levels.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(_onTabChanged);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(grammarListControllerProvider.notifier).loadGrammars();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final level = _levels[_tabController.index];
      ref.read(grammarListControllerProvider.notifier).selectLevel(level);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(grammarStatusRefreshProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.read(grammarListControllerProvider.notifier).loadGrammars();
    });

    final state = ref.watch(grammarListControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('语法列表', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5C8DFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF5C8DFF),
          tabs: _levels.map((l) => Tab(text: l.toUpperCase())).toList(),
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(GrammarListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text('Error: ${state.error}'));
    }

    if (state.grammars.isEmpty) {
      return const Center(child: Text('没有找到语法'));
    }

    final count =
        state.levelCounts[state.selectedLevel] ?? state.grammars.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '共 $count 条',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: state.grammars.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final grammar = state.grammars[index];
              final isMastered = grammar.userState == LearningStatus.mastered;
              final isLearning = grammar.userState == LearningStatus.learning;

              Color bgColor = Colors.white;
              Color borderColor = Colors.grey.shade200;

              if (isMastered) {
                bgColor = Theme.of(context).primaryColor.withValues(alpha: 0.1);
                borderColor = Theme.of(context).primaryColor.withValues(alpha: 0.3);
              } else if (isLearning) {
                bgColor = Colors.orange.withValues(alpha: 0.1);
                borderColor = Colors.orange.withValues(alpha: 0.3);
              }

              return Card(
                elevation: 0,
                color: bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: ListTile(
                  title: Text(
                    grammar.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMastered
                          ? Theme.of(context).primaryColor
                          : (isLearning ? Colors.orange.shade800 : Colors.black87),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: isMastered
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.7)
                        : (isLearning ? Colors.orange.shade400 : Colors.grey),
                  ),
                  onTap: () {
                    context.push('/grammar/learn/${grammar.id}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
