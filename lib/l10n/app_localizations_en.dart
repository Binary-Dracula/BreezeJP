// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Breeze JP';

  @override
  String get appSubtitle => 'Japanese Learning Assistant';

  @override
  String get splashInitializing => 'Initializing...';

  @override
  String get splashLoadingDatabase => 'Loading database...';

  @override
  String get splashInitComplete => 'Initialization complete';

  @override
  String splashInitFailed(String error) {
    return 'Initialization failed: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get homeWelcome => 'Welcome to Breeze JP';

  @override
  String get homeSubtitle => 'Start your Japanese learning journey';

  @override
  String get startLearning => 'Start Learning';

  @override
  String get databaseEmpty => 'Database is empty, please check data files';

  @override
  String databaseInitFailed(String error) {
    return 'Database initialization failed: $error';
  }
}
