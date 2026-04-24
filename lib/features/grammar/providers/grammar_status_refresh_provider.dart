import 'package:flutter_riverpod/flutter_riverpod.dart';

final grammarStatusRefreshProvider =
		NotifierProvider<GrammarStatusRefreshNotifier, int>(
			GrammarStatusRefreshNotifier.new,
		);

class GrammarStatusRefreshNotifier extends Notifier<int> {
	@override
	int build() => 0;

	void bump() {
		state++;
	}
}