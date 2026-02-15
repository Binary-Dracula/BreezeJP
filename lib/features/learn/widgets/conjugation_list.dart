import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/models/word_conjugation.dart';

class ConjugationList extends StatelessWidget {
  final List<WordConjugation> conjugations;

  const ConjugationList({super.key, required this.conjugations});

  @override
  Widget build(BuildContext context) {
    if (conjugations.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final borderColor = theme.dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '活用',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 0.5),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: conjugations.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: borderColor.withOpacity(0.5),
            ),
            itemBuilder: (context, index) {
              final item = conjugations[index];
              return InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.conjugatedWord));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.conjugatedWord} 已复制'),
                      duration: const Duration(milliseconds: 500),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.typeNameCn ?? item.typeNameJa ?? '未知',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.conjugatedWord,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
