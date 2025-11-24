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

  @override
  String get homeTodayGoal => '今日目标';

  @override
  String get homeWordsUnit => '词';

  @override
  String get homeReview => '复习';

  @override
  String get homeNewWords => '新词';

  @override
  String get loading => '加载中...';

  @override
  String get learning => '学习中';

  @override
  String get learnWords => '学习单词';

  @override
  String get loadingWords => '正在加载单词...';

  @override
  String get noWordsToLearn => '没有需要学习的单词';

  @override
  String get examples => '例句';

  @override
  String get ratingAgain => '重来';

  @override
  String get ratingAgainSub => '忘记';

  @override
  String get ratingHard => '困难';

  @override
  String get ratingHardSub => '模糊';

  @override
  String get ratingGood => '良好';

  @override
  String get ratingGoodSub => '记得';

  @override
  String get ratingEasy => '简单';

  @override
  String get ratingEasySub => '熟练';

  @override
  String get previous => '上一个';

  @override
  String get next => '下一个';

  @override
  String get learningFinished => '学习完成！';

  @override
  String get learningFinishedDesc => '你已完成本次学习。';

  @override
  String get backToHome => '返回主页';

  @override
  String get continueLearningTitle => '继续学习？';

  @override
  String get continueLearningContent => '你已完成当前队列。是否加载更多单词？';

  @override
  String get restABit => '休息一下';

  @override
  String get continueLearning => '继续学习';
}
