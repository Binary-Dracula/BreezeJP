import 'package:flutter/material.dart';

import '../../../data/models/word_detail.dart';
import '../../favorites/widgets/word_favorite_button.dart';
import '../../learn/widgets/conjugation_list.dart';
import '../../learn/widgets/word_examples_section.dart';
import '../../learn/widgets/word_header.dart';
import '../../learn/widgets/word_insights_section.dart';
import '../../learn/widgets/word_meanings_section.dart';

class WordDetailContent extends StatelessWidget {
  final WordDetail wordDetail;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final List<Widget> prefixChildren;

  const WordDetailContent({
    super.key,
    required this.wordDetail,
    this.scrollController,
    this.padding = const EdgeInsets.only(bottom: 24),
    this.prefixChildren = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...prefixChildren,
          WordHeader(
            wordDetail: wordDetail,
            trailingAction: WordFavoriteButton(
              wordId: wordDetail.word.id,
              initialIsFavorited: wordDetail.isFavorited,
            ),
          ),
          WordMeaningsSection(richContent: wordDetail.richContent),
          WordExamplesSection(examples: wordDetail.examples),
          WordInsightsSection(richContent: wordDetail.richContent),
          ConjugationList(conjugations: wordDetail.richContent.conjugations),
        ],
      ),
    );
  }
}
