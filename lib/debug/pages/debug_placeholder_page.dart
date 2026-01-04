import 'package:flutter/material.dart';

class DebugPlaceholderPage extends StatelessWidget {
  const DebugPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: const Center(
        child: Text(
          'Debug tools removed.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
