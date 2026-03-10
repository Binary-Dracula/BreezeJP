import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/read/grammar_book_item.dart';
import '../controller/grammar_book_controller.dart';
import '../state/grammar_book_state.dart';

/// 语法本页面
class GrammarBookPage extends ConsumerStatefulWidget {
  const GrammarBookPage({super.key});

  @override
  ConsumerState<GrammarBookPage> createState() => _GrammarBookPageState();
}

class _GrammarBookPageState extends ConsumerState<GrammarBookPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(grammarBookControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      ref
          .read(grammarBookControllerProvider.notifier)
          .switchTab(_tabController.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(grammarBookControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          // 搜索栏
          if (_isSearchVisible) _buildSearchBar(),
          // TabBar
          _buildTabBar(state),
          // 列表内容
          Expanded(child: _buildTabContent(state)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(GrammarBookState state) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        '语法本',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? Icons.search_off : Icons.search,
            color: Colors.grey.shade800,
          ),
          onPressed: () {
            setState(() {
              _isSearchVisible = !_isSearchVisible;
              if (!_isSearchVisible) {
                _searchController.clear();
                ref.read(grammarBookControllerProvider.notifier).search('');
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '搜索语法...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(grammarBookControllerProvider.notifier).search('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F3F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        onChanged: (value) {
          ref.read(grammarBookControllerProvider.notifier).search(value);
        },
      ),
    );
  }

  Widget _buildTabBar(GrammarBookState state) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF5C8DFF),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF5C8DFF),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs: [
          Tab(text: '学习中 (${state.learningCount})'),
          Tab(text: '已掌握 (${state.masteredCount})'),
        ],
      ),
    );
  }

  Widget _buildTabContent(GrammarBookState state) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGrammarList(
          items: state.learningGrammars,
          isLoading: state.isLoading,
          isLoadingMore: state.isLoadingMore,
          hasMore: state.hasMoreLearning,
          isLearningTab: true,
          emptyMessage: '还没有正在学习的语法\n快去学习新语法吧！',
        ),
        _buildGrammarList(
          items: state.masteredGrammars,
          isLoading: state.isLoading,
          isLoadingMore: state.isLoadingMore,
          hasMore: state.hasMoreMastered,
          isLearningTab: false,
          emptyMessage: '还没有掌握的语法\n继续加油学习吧！',
          emptyIcon: Icons.emoji_events_outlined,
        ),
      ],
    );
  }

  Widget _buildGrammarList({
    required List<GrammarBookItem> items,
    required bool isLoading,
    required bool isLoadingMore,
    required bool hasMore,
    required bool isLearningTab,
    required String emptyMessage,
    IconData emptyIcon = Icons.menu_book_outlined,
  }) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return _buildEmptyState(emptyMessage, emptyIcon);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isLoadingMore) {
          ref.read(grammarBookControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _GrammarListTile(
            item: items[index],
            isLearningTab: isLearningTab,
            onTap: () =>
                context.push('/grammar/learn/${items[index].grammarId}'),
            onToggleStatus: () {
              ref
                  .read(grammarBookControllerProvider.notifier)
                  .toggleStatus(items[index].grammarId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/grammar/list'),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('去学习'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C8DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// 语法列表项
class _GrammarListTile extends StatelessWidget {
  final GrammarBookItem item;
  final bool isLearningTab;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  const _GrammarListTile({
    required this.item,
    required this.isLearningTab,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              // 语法信息
              Expanded(child: _buildGrammarInfo()),
              // 状态切换按钮
              _buildStatusButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrammarInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 语法标题
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // 标签：JLPT 等级
        Row(
          children: [
            if (item.jlptLevel != null)
              _buildTag(item.jlptLevel!, const Color(0xFF6366F1)),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusButton() {
    if (isLearningTab) {
      // 学习中 → 掌握
      return _StatusToggleButton(
        label: '掌握',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF34D399),
        onPressed: onToggleStatus,
      );
    } else {
      // 已掌握 → 恢复学习
      return _StatusToggleButton(
        label: '恢复',
        icon: Icons.replay_rounded,
        color: const Color(0xFF5C8DFF),
        onPressed: onToggleStatus,
      );
    }
  }
}

/// 状态切换按钮
class _StatusToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _StatusToggleButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
