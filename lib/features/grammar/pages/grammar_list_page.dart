import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controller/grammar_list_controller.dart';
import '../state/grammar_list_state.dart';

class GrammarListPage extends ConsumerStatefulWidget {
  const GrammarListPage({super.key});

  @override
  ConsumerState<GrammarListPage> createState() => _GrammarListPageState();
}

class _GrammarListPageState extends ConsumerState<GrammarListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _levels.length, vsync: this);
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
          tabs: _levels.map((l) => Tab(text: l)).toList(),
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.grammars.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final grammar = state.grammars[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            title: Text(
              grammar.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              grammar.meaning ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              // Navigate to Learning Page with this grammar
              context.push('/grammar/learn/${grammar.id}');
            },
          ),
        );
      },
    );
  }
}
