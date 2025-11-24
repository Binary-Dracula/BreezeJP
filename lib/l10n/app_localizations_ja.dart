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
