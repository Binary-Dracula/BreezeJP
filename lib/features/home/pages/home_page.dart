import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/home_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // 初始加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeControllerProvider.notifier).loadHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);

    if (state.isLoading && !state.hasData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.hasError && !state.hasData) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(state.error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(homeControllerProvider.notifier).loadHomeData(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // 柔和的灰白色背景
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 顶部 Header
                _buildHeader(context, state.userName),

                const SizedBox(height: 32),

                // 2. 核心行动卡片 (Hero Card)
                _buildHeroStudyCard(
                  context,
                  state.reviewCount,
                  state.newWordCount,
                ),

                const SizedBox(height: 32),

                // 3. 数据概览小条 (Stats Row)
                _buildDailyStatsRow(
                  state.streakDays,
                  state.masteredWordCount,
                  state.todayStudyDurationMinutes,
                ),

                const SizedBox(height: 32),

                // 4. 功能网格 (Tools Grid)
                const Text(
                  "工具箱",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildToolsGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. 顶部 Header ---
  Widget _buildHeader(BuildContext context, String userName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(), // 根据时间显示 早上好/晚上好
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              userName, // 这里读数据库用户名
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        // 设置按钮
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {
              // TODO: 跳转到设置页
              // Navigator.push(...)
            },
          ),
        ),
      ],
    );
  }

  // --- 2. 核心行动卡片 (Hero Section) ---
  Widget _buildHeroStudyCard(
    BuildContext context,
    int reviewCount,
    int newCount,
  ) {
    bool hasTask = reviewCount > 0 || newCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B8EFF), Color(0xFF4E73DF)], // 清爽的蓝色渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E73DF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 任务计数
          Row(
            children: [
              _buildCountBadge(
                "待复习",
                reviewCount.toString(),
                Colors.white.withOpacity(0.2),
              ),
              const SizedBox(width: 12),
              _buildCountBadge(
                "新单词",
                newCount.toString(),
                Colors.white.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            "准备好开始了吗?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasTask ? "预计耗时 15 分钟" : "今日任务已完成，去休息吧！",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 24),

          // 巨大的开始按钮
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasTask
                  ? () {
                      // TODO: 跳转到 TikTokStudyPage
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => TikTokStudyPage(mode: ...)))
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4E73DF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "开始学习",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, String count, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. 每日数据条 ---
  Widget _buildDailyStatsRow(
    int streakDays,
    int masteredCount,
    int durationMinutes,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.local_fire_department_rounded,
            streakDays.toString(),
            "连续打卡",
            Colors.orange,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            Icons.check_circle_outline_rounded,
            masteredCount.toString(),
            "已掌握",
            Colors.green,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            Icons.timer_outlined,
            "${durationMinutes}m",
            "今日时长",
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade200);
  }

  // --- 4. 功能网格 (Tools Grid) ---
  Widget _buildToolsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true, // 关键：允许在 Column 中嵌套 GridView
      physics:
          const NeverScrollableScrollPhysics(), // 禁止 GridView 内部滚动，由外层 ScrollView 接管
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5, // 宽长比，控制卡片形状
      children: [
        _buildToolCard(
          icon: Icons.book_outlined,
          title: "单词本",
          subtitle: "查词与管理",
          color: Colors.amber,
          onTap: () {
            // TODO: 跳转到词库列表页 (LibraryPage)
          },
        ),
        _buildToolCard(
          icon: Icons.bar_chart_rounded,
          title: "详细统计",
          subtitle: "查看遗忘曲线",
          color: Colors.teal,
          onTap: () {
            // TODO: 跳转到统计详情页
          },
        ),
        // 未来可以加： _buildToolCard(icon: Icons.headset, title: "磨耳朵", ...),
      ],
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return "早上好 ☀️";
    if (hour < 18) return "下午好 👋";
    return "晚上好 🌙";
  }
}
