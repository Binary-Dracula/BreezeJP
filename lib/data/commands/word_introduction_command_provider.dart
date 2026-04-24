import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database_provider.dart';
import 'word_introduction_command.dart';

final wordIntroductionCommandProvider = Provider<WordIntroductionCommand>((
  ref,
) {
  final db = ref.read(databaseProvider);
  return WordIntroductionCommand(db);
});
