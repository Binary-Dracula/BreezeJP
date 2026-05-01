import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:breeze_jp/l10n/app_localizations.dart';
import '../controller/reference_controller.dart';
import '../reference_models.dart';
import '../state/reference_state.dart';
import '../widgets/reference_card.dart';

class ReferencePage extends ConsumerStatefulWidget {
  const ReferencePage({super.key});

  @override
  ConsumerState<ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends ConsumerState<ReferencePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(referenceControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(referenceControllerProvider);

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
        body: _buildBody(state, l10n),
      ),
    );
  }

  Widget _buildBody(ReferenceState state, AppLocalizations l10n) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(referenceControllerProvider.notifier).load(),
              child: Text(l10n.retryButton),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      children: [
        _ReferenceList(groups: state.numbers),
        _ReferenceList(groups: state.datesAndMonths),
        _ReferenceList(groups: state.time),
        _ReferenceList(groups: state.counters),
      ],
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
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 8,
              ),
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
