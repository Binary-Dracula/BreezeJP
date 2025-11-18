// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Breeze JP';

  @override
  String get appSubtitle => '日本語学習アシスタント';

  @override
  String get splashInitializing => '初期化中...';

  @override
  String get splashLoadingDatabase => 'データベースを読み込んでいます...';

  @override
  String get splashInitComplete => '初期化完了';

  @override
  String splashInitFailed(String error) {
    return '初期化失敗: $error';
  }

  @override
  String get retry => '再試行';

  @override
  String get homeWelcome => 'Breeze JP へようこそ';

  @override
  String get homeSubtitle => '日本語学習の旅を始めましょう';

  @override
  String get startLearning => '学習を始める';

  @override
  String get databaseEmpty => 'データベースが空です。データファイルを確認してください';

  @override
  String databaseInitFailed(String error) {
    return 'データベース初期化失敗: $error';
  }
}
