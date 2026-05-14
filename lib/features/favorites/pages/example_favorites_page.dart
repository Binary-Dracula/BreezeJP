import 'package:breeze_jp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/custom_ruby_text.dart';
import '../../../data/models/read/example_favorite_item.dart';
import '../controller/example_favorites_controller.dart';
import '../providers/favorite_refresh_provider.dart';
import '../state/example_favorites_state.dart';
import '../widgets/word_example_favorite_button.dart';

class ExampleFavoritesPage extends ConsumerStatefulWidget {
  const ExampleFavoritesPage({super.key});

  @override
  ConsumerState<ExampleFavoritesPage> createState() =>
      _ExampleFavoritesPageState();
}

class _ExampleFavoritesPageState extends ConsumerState<ExampleFavoritesPage> {
  final _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exampleFavoritesControllerProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(favoriteRefreshProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.read(exampleFavoritesControllerProvider.notifier).loadInitial();
    });

    final state = ref.watch(exampleFavoritesControllerProvider);
    final l10n = AppLocalizations.of(context)!;

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
        title: Text(
          l10n.exampleFavoritesTitle,
          style: const TextStyle(
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
                  ref
                      .read(exampleFavoritesControllerProvider.notifier)
                      .search('');
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchVisible) _buildSearchBar(l10n),
          _buildCountSummary(state, l10n),
          Expanded(child: _buildContent(state, l10n)),
        ],
      ),
    );
  }

  Widget _buildCountSummary(
    ExampleFavoritesState state,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF6F7FB),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Center(
        child: Text(
          l10n.exampleFavoritesCountSummary(state.totalCount),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.exampleFavoritesSearchHint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(exampleFavoritesControllerProvider.notifier)
                        .search('');
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
          ref.read(exampleFavoritesControllerProvider.notifier).search(value);
        },
      ),
    );
  }

  Widget _buildContent(ExampleFavoritesState state, AppLocalizations l10n) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.exampleFavoritesEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoadingMore) {
          ref.read(exampleFavoritesControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
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
          return _ExampleFavoriteCard(item: state.items[index]);
        },
      ),
    );
  }
}

class _ExampleFavoriteCard extends StatelessWidget {
  const _ExampleFavoriteCard({required this.item});

  final ExampleFavoriteItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          context.pushNamed('word-detail', pathParameters: {'id': item.wordId});
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWordMeta()),
                  const SizedBox(width: 12),
                  WordExampleFavoriteButton(
                    exampleId: item.exampleId,
                    wordId: item.wordId,
                    initialIsFavorited: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              JapaneseSentence(
                text: item.japanese,
                fontSize: 18,
                rubyFontSize: 11,
              ),
              if (item.chinese.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.chinese,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordMeta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                item.word,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.reading.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '(${item.reading})',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (item.primaryMeaning?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            item.primaryMeaning!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (item.jlptLevel?.isNotEmpty == true)
              _MetaTag(label: item.jlptLevel!, color: const Color(0xFF6366F1)),
            if (item.partOfSpeech?.isNotEmpty == true)
              _MetaTag(
                label: item.partOfSpeech!,
                color: const Color(0xFF14B8A6),
              ),
          ],
        ),
      ],
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
