import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import 'learning_session_repository.dart';

final learningSessionRepositoryProvider = Provider<LearningSessionRepository>(
  (ref) => LearningSessionRepository(() => AppDatabase.instance.database),
);
