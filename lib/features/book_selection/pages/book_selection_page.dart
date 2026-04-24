import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../controller/book_selection_controller.dart';
import '../../../data/models/vocab_book.dart';

/// 辞书选择页面
class BookSelectionPage extends ConsumerWidget {
  final bool navigateToLearnOnSelect;

  const BookSelectionPage({super.key, this.navigateToLearnOnSelect = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookSelectionControllerProvider);
    final selectedBookId = ref.watch(selectedBookIdProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('选择辞书'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '无法加载辞书列表',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请检查网络连接后重试',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(bookSelectionControllerProvider.notifier)
                          .refreshBooks(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : Builder(
              builder: (context) {
                final books = state.books;
                if (books.isEmpty) {
                  return Center(
                    child: Text(
                      '暂无可用辞书',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final isSelected = book.id == selectedBookId;
                    return _BookCard(
                      book: book,
                      isSelected: isSelected,
                      onTap: () => _onBookSelected(context, ref, book),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _onBookSelected(
    BuildContext context,
    WidgetRef ref,
    VocabBook book,
  ) async {
    await ref.read(selectedBookIdProvider.notifier).setBookId(book.id);
    if (context.mounted) {
      if (navigateToLearnOnSelect) {
        context.go('/learn/${book.id}');
      } else {
        context.pop();
      }
    }
  }
}

class _BookCard extends StatelessWidget {
  final VocabBook book;
  final bool isSelected;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFF5C8DFF), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C8DFF), Color(0xFF6DD5ED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (book.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${book.wordCount} 词',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF5C8DFF),
                size: 24,
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}
