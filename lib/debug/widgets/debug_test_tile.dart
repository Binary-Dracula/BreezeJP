import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state/debug_state.dart';

class DebugTestTile extends StatelessWidget {
  final DebugTestItem item;

  const DebugTestTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.title),
      subtitle: Text(item.description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(item.route),
    );
  }
}
