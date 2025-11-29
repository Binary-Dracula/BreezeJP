import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/kana_chart_controller.dart';
import '../state/kana_chart_state.dart';
import '../widgets/kana_grid.dart';

/// 五十音图展示页面
class KanaChartPage extends ConsumerStatefulWidget {
  const KanaChartPage({super.key});

  @override
  ConsumerState<KanaChartPage> createState() => _KanaChartPageState();
}

class _KanaChartPageState extends ConsumerState<KanaChartPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 类型定义（匹配数据库中的 type 字段）
  static const List<_KanaTabInfo> _tabs = [
    _KanaTabInfo(type: 'basic', label: '清音'),
    _KanaTabInfo(type: 'dakuon', label: '濁音'),
    _KanaTabInfo(type: 'handakuon', label: '半濁音'),
    _KanaTabInfo(type: 'youon', label: '拗音'),
    _KanaTabInfo(type: 'extended', label: '特殊'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kanaChartControllerProvider.notifier).loadKanaChart();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kanaChartControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('五十音図'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // 平假名/片假名切换
          _buildDisplayModeToggle(state.displayMode),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasError
          ? _buildErrorView(state.error!)
          : Column(
              children: [
                // 学习进度
                _buildProgressBar(state),
                // Tab 内容
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      return _buildKanaTabContent(state, tab.type);
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  /// 学习进度条
  Widget _buildProgressBar(KanaChartState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            '学习进度',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progressPercent,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${state.learnedCount}/${state.totalCount}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 平假名/片假名切换按钮
  Widget _buildDisplayModeToggle(KanaDisplayMode mode) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SegmentedButton<KanaDisplayMode>(
        segments: const [
          ButtonSegment(
            value: KanaDisplayMode.hiragana,
            label: Text('あ', style: TextStyle(fontSize: 16)),
          ),
          ButtonSegment(
            value: KanaDisplayMode.katakana,
            label: Text('ア', style: TextStyle(fontSize: 16)),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selected) {
          ref
              .read(kanaChartControllerProvider.notifier)
              .setDisplayMode(selected.first);
        },
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// 构建单个 Tab 内容
  Widget _buildKanaTabContent(KanaChartState state, String type) {
    // 过滤当前类型的假名
    final filteredKana = state.kanaLetters
        .where((k) => k.letter.type == type)
        .toList();

    if (filteredKana.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: KanaGrid(
        kanaLetters: filteredKana,
        displayMode: state.displayMode,
        kanaType: type,
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(kanaChartControllerProvider.notifier).loadKanaChart();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// Tab 信息
class _KanaTabInfo {
  final String type;
  final String label;

  const _KanaTabInfo({required this.type, required this.label});
}
