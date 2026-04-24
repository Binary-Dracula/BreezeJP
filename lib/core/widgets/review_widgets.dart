import 'package:flutter/material.dart';
import '../../core/algorithm/srs_types.dart';

/// 复习进度条
class ReviewProgressBar extends StatelessWidget {
  final double progress;
  final int currentIndex;
  final int totalItems;

  const ReviewProgressBar({
    super.key,
    required this.progress,
    required this.currentIndex,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6C63FF),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${currentIndex + 1} / $totalItems',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 客观题选项区域（网格）
class ReviewObjectiveOptions extends StatefulWidget {
  final List<String> options;
  final String correctOption;
  final ValueChanged<String> onSelect;

  const ReviewObjectiveOptions({
    super.key,
    required this.options,
    required this.correctOption,
    required this.onSelect,
  });

  @override
  State<ReviewObjectiveOptions> createState() => _ReviewObjectiveOptionsState();
}

class _ReviewObjectiveOptionsState extends State<ReviewObjectiveOptions> {
  String? _wrongOption;

  @override
  void didUpdateWidget(covariant ReviewObjectiveOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.correctOption != widget.correctOption ||
        oldWidget.options != widget.options) {
      _wrongOption = null;
    }
  }

  void _handleSelect(String option) {
    if (option == widget.correctOption) {
      widget.onSelect(option);
    } else {
      if (_wrongOption != option) {
        setState(() {
          _wrongOption = option;
        });
        widget.onSelect(option);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.options.length,
      itemBuilder: (context, index) {
        final option = widget.options[index];
        final isWrong = _wrongOption == option;
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isWrong ? Colors.red[50] : Colors.white,
            foregroundColor: isWrong ? Colors.red : const Color(0xFF2D3142),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isWrong ? Colors.red : Colors.grey[200]!,
                width: isWrong ? 2.0 : 1.0,
              ),
            ),
          ),
          onPressed: () => _handleSelect(option),
          child: Text(
            option,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

/// 客观题选项区域（垂直列表选项框：适合内容较长的单词形式）
class ReviewObjectiveListOptions extends StatefulWidget {
  final List<String> options;
  final String correctOption;
  final ValueChanged<String> onSelect;

  const ReviewObjectiveListOptions({
    super.key,
    required this.options,
    required this.correctOption,
    required this.onSelect,
  });

  @override
  State<ReviewObjectiveListOptions> createState() =>
      _ReviewObjectiveListOptionsState();
}

class _ReviewObjectiveListOptionsState
    extends State<ReviewObjectiveListOptions> {
  String? _wrongOption;

  @override
  void didUpdateWidget(covariant ReviewObjectiveListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.correctOption != widget.correctOption ||
        oldWidget.options != widget.options) {
      _wrongOption = null;
    }
  }

  void _handleSelect(String option) {
    if (option == widget.correctOption) {
      widget.onSelect(option);
    } else {
      if (_wrongOption != option) {
        setState(() {
          _wrongOption = option;
        });
        widget.onSelect(option);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.options.map((opt) {
        final isWrong = _wrongOption == opt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isWrong ? Colors.red[50] : Colors.white,
              foregroundColor: isWrong ? Colors.red : const Color(0xFF2D3142),
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isWrong ? Colors.red : Colors.grey[200]!,
                  width: isWrong ? 2.0 : 1.0,
                ),
              ),
            ),
            onPressed: () => _handleSelect(opt),
            child: Text(
              opt,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 主观评分按钮组
class ReviewSubjectiveRatings extends StatelessWidget {
  final ValueChanged<ReviewRating> onRate;

  const ReviewSubjectiveRatings({super.key, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildRatingButton(
          label: 'Hard',
          color: const Color(0xFFFF6B6B),
          rating: ReviewRating.hard,
        ),
        const SizedBox(width: 12),
        _buildRatingButton(
          label: 'Good',
          color: const Color(0xFF4DABF7),
          rating: ReviewRating.good,
        ),
        const SizedBox(width: 12),
        _buildRatingButton(
          label: 'Easy',
          color: const Color(0xFF51CF66),
          rating: ReviewRating.easy,
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required String label,
    required Color color,
    required ReviewRating rating,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => onRate(rating),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// 复习空状态（没任务时）
class ReviewEmptyState extends StatelessWidget {
  final String title;

  const ReviewEmptyState({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// 复习完成状态
class ReviewFinishedState extends StatelessWidget {
  final VoidCallback onBack;

  const ReviewFinishedState({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              '复习完成！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '干得漂亮，继续保持学习吧。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onBack,
                child: const Text(
                  '回到主页',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
