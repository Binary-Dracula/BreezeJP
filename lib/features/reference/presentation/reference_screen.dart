import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../domain/reference_data.dart';
import '../domain/models.dart';
import 'widgets/reference_card.dart';

class ReferenceScreen extends StatelessWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.referenceTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.referenceTabNumbers),
              Tab(text: l10n.referenceTabDates),
              Tab(text: l10n.referenceTabTime),
              Tab(text: l10n.referenceTabCounters),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReferenceList(groups: ReferenceData.numbers),
            _ReferenceList(groups: ReferenceData.datesAndMonths),
            _ReferenceList(groups: ReferenceData.time),
            _ReferenceList(groups: ReferenceData.counters),
          ],
        ),
      ),
    );
  }
}

class _ReferenceList extends StatelessWidget {
  final List<ReferenceGroup> groups;

  const _ReferenceList({required this.groups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (group.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...group.items.map((item) => ReferenceCard(item: item)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
