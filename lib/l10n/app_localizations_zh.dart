// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Breeze JP';

  @override
  String get appSubtitle => '日语学习助手';

  @override
  String get splashInitializing => '正在初始化...';

  @override
  String get splashLoadingDatabase => '正在加载数据库...';

  @override
  String get splashInitComplete => '初始化完成';

  @override
  String splashInitFailed(String error) {
    return '初始化失败: $error';
  }

  @override
  String get retry => '重试';

  @override
  String get homeWelcome => '欢迎使用 Breeze JP';

  @override
  String get homeSubtitle => '开始你的日语学习之旅';

  @override
  String get startLearning => '开始学习';

  @override
  String get databaseEmpty => '数据库为空，请检查数据文件';

  @override
  String databaseInitFailed(String error) {
    return '数据库初始化失败: $error';
  }
}
