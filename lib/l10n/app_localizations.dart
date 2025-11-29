import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'Breeze JP'**
  String get appName;

  /// 应用副标题
  ///
  /// In zh, this message translates to:
  /// **'日语学习助手'**
  String get appSubtitle;

  /// Splash 页面初始化提示
  ///
  /// In zh, this message translates to:
  /// **'正在初始化...'**
  String get splashInitializing;

  /// 加载数据库提示
  ///
  /// In zh, this message translates to:
  /// **'正在加载数据库...'**
  String get splashLoadingDatabase;

  /// 初始化完成提示
  ///
  /// In zh, this message translates to:
  /// **'初始化完成'**
  String get splashInitComplete;

  /// 初始化失败提示
  ///
  /// In zh, this message translates to:
  /// **'初始化失败: {error}'**
  String splashInitFailed(String error);

  /// 重试按钮
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// 主页欢迎文字
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 Breeze JP'**
  String get homeWelcome;

  /// 主页副标题
  ///
  /// In zh, this message translates to:
  /// **'开始你的日语学习之旅'**
  String get homeSubtitle;

  /// 开始学习按钮
  ///
  /// In zh, this message translates to:
  /// **'开始学习'**
  String get startLearning;

  /// 数据库为空错误提示
  ///
  /// In zh, this message translates to:
  /// **'数据库为空，请检查数据文件'**
  String get databaseEmpty;

  /// 数据库初始化失败提示
  ///
  /// In zh, this message translates to:
  /// **'数据库初始化失败: {error}'**
  String databaseInitFailed(String error);

  /// No description provided for @homeTodayGoal.
  ///
  /// In zh, this message translates to:
  /// **'今日目标'**
  String get homeTodayGoal;

  /// No description provided for @homeWordsUnit.
  ///
  /// In zh, this message translates to:
  /// **'词'**
  String get homeWordsUnit;

  /// No description provided for @homeReview.
  ///
  /// In zh, this message translates to:
  /// **'复习'**
  String get homeReview;

  /// No description provided for @homeNewWords.
  ///
  /// In zh, this message translates to:
  /// **'新词'**
  String get homeNewWords;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @learning.
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get learning;

  /// No description provided for @learnWords.
  ///
  /// In zh, this message translates to:
  /// **'学习单词'**
  String get learnWords;

  /// No description provided for @loadingWords.
  ///
  /// In zh, this message translates to:
  /// **'正在加载单词...'**
  String get loadingWords;

  /// No description provided for @noWordsToLearn.
  ///
  /// In zh, this message translates to:
  /// **'没有需要学习的单词'**
  String get noWordsToLearn;

  /// No description provided for @examples.
  ///
  /// In zh, this message translates to:
  /// **'例句'**
  String get examples;

  /// No description provided for @ratingAgain.
  ///
  /// In zh, this message translates to:
  /// **'重来'**
  String get ratingAgain;

  /// No description provided for @ratingAgainSub.
  ///
  /// In zh, this message translates to:
  /// **'忘记'**
  String get ratingAgainSub;

  /// No description provided for @ratingHard.
  ///
  /// In zh, this message translates to:
  /// **'困难'**
  String get ratingHard;

  /// No description provided for @ratingHardSub.
  ///
  /// In zh, this message translates to:
  /// **'模糊'**
  String get ratingHardSub;

  /// No description provided for @ratingGood.
  ///
  /// In zh, this message translates to:
  /// **'良好'**
  String get ratingGood;

  /// No description provided for @ratingGoodSub.
  ///
  /// In zh, this message translates to:
  /// **'记得'**
  String get ratingGoodSub;

  /// No description provided for @ratingEasy.
  ///
  /// In zh, this message translates to:
  /// **'简单'**
  String get ratingEasy;

  /// No description provided for @ratingEasySub.
  ///
  /// In zh, this message translates to:
  /// **'熟练'**
  String get ratingEasySub;

  /// No description provided for @previous.
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get next;

  /// No description provided for @learningFinished.
  ///
  /// In zh, this message translates to:
  /// **'学习完成！'**
  String get learningFinished;

  /// No description provided for @learningFinishedDesc.
  ///
  /// In zh, this message translates to:
  /// **'你已完成本次学习。'**
  String get learningFinishedDesc;

  /// No description provided for @backToHome.
  ///
  /// In zh, this message translates to:
  /// **'返回主页'**
  String get backToHome;

  /// No description provided for @continueLearningTitle.
  ///
  /// In zh, this message translates to:
  /// **'继续学习？'**
  String get continueLearningTitle;

  /// No description provided for @continueLearningContent.
  ///
  /// In zh, this message translates to:
  /// **'你已完成当前队列。是否加载更多单词？'**
  String get continueLearningContent;

  /// No description provided for @restABit.
  ///
  /// In zh, this message translates to:
  /// **'休息一下'**
  String get restABit;

  /// No description provided for @continueLearning.
  ///
  /// In zh, this message translates to:
  /// **'继续学习'**
  String get continueLearning;

  /// 重试按钮文字
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryButton;

  /// 早上的问候语
  ///
  /// In zh, this message translates to:
  /// **'早上好 ☀️'**
  String get greetingMorning;

  /// 下午的问候语
  ///
  /// In zh, this message translates to:
  /// **'下午好 👋'**
  String get greetingAfternoon;

  /// 晚上的问候语
  ///
  /// In zh, this message translates to:
  /// **'晚上好 🌙'**
  String get greetingEvening;

  /// 用户问候语
  ///
  /// In zh, this message translates to:
  /// **'Hi, {userName}'**
  String userGreeting(String userName);

  /// 连续打卡天数标签
  ///
  /// In zh, this message translates to:
  /// **'连续打卡'**
  String get streakDays;

  /// 已掌握单词数标签
  ///
  /// In zh, this message translates to:
  /// **'已掌握'**
  String get masteredWords;

  /// 今日学习时长标签
  ///
  /// In zh, this message translates to:
  /// **'今日时长'**
  String get todayDuration;

  /// 单词本功能标题
  ///
  /// In zh, this message translates to:
  /// **'单词本'**
  String get wordBook;

  /// 单词本功能副标题
  ///
  /// In zh, this message translates to:
  /// **'查词与管理'**
  String get wordBookSubtitle;

  /// 详细统计功能标题
  ///
  /// In zh, this message translates to:
  /// **'详细统计'**
  String get detailedStats;

  /// 详细统计功能副标题
  ///
  /// In zh, this message translates to:
  /// **'查看遗忘曲线'**
  String get detailedStatsSubtitle;

  /// No description provided for @networkConnectionTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时，请检查网络设置'**
  String get networkConnectionTimeout;

  /// No description provided for @networkRequestCancelled.
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get networkRequestCancelled;

  /// No description provided for @networkConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络设置'**
  String get networkConnectionFailed;

  /// No description provided for @networkCertificateFailed.
  ///
  /// In zh, this message translates to:
  /// **'证书验证失败'**
  String get networkCertificateFailed;

  /// No description provided for @networkRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败: {message}'**
  String networkRequestFailed(String message);

  /// No description provided for @networkRequestFailedWithCode.
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败 (状态码: {code})'**
  String networkRequestFailedWithCode(Object code);

  /// No description provided for @networkBadRequest.
  ///
  /// In zh, this message translates to:
  /// **'请求参数错误'**
  String get networkBadRequest;

  /// No description provided for @networkUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'未授权，请重新登录'**
  String get networkUnauthorized;

  /// No description provided for @networkForbidden.
  ///
  /// In zh, this message translates to:
  /// **'拒绝访问'**
  String get networkForbidden;

  /// No description provided for @networkNotFound.
  ///
  /// In zh, this message translates to:
  /// **'请求的资源不存在'**
  String get networkNotFound;

  /// No description provided for @networkInternalServerError.
  ///
  /// In zh, this message translates to:
  /// **'服务器内部错误'**
  String get networkInternalServerError;

  /// No description provided for @networkBadGateway.
  ///
  /// In zh, this message translates to:
  /// **'网关错误'**
  String get networkBadGateway;

  /// No description provided for @networkServiceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'服务不可用'**
  String get networkServiceUnavailable;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String loadFailed(Object error);

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchFailed(Object error);

  /// No description provided for @submitFailed.
  ///
  /// In zh, this message translates to:
  /// **'提交失败: {error}'**
  String submitFailed(Object error);

  /// No description provided for @playAudioFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放音频失败: {error}'**
  String playAudioFailed(Object error);

  /// No description provided for @audioLoadFailedOnline.
  ///
  /// In zh, this message translates to:
  /// **'无法加载在线音频: {url}'**
  String audioLoadFailedOnline(String url);

  /// No description provided for @audioNoOnlineSource.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的在线音频: {filename}'**
  String audioNoOnlineSource(String filename);

  /// 复习模式提示点击查看答案
  ///
  /// In zh, this message translates to:
  /// **'点击查看释义'**
  String get tapToShowAnswer;

  /// 学习模式下一个单词按钮
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get nextWord;

  /// 学习模式最后一个单词完成按钮
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get finish;

  /// 初始选择页标题
  ///
  /// In zh, this message translates to:
  /// **'选择起点'**
  String get initialChoiceTitle;

  /// 初始选择页副标题
  ///
  /// In zh, this message translates to:
  /// **'选择一个单词开始探索'**
  String get initialChoiceSubtitle;

  /// 已学单词计数
  ///
  /// In zh, this message translates to:
  /// **'+{count}'**
  String learnedCount(int count);

  /// 路径结束对话框标题
  ///
  /// In zh, this message translates to:
  /// **'已探索完这条路径'**
  String get pathEndedTitle;

  /// 路径结束对话框内容
  ///
  /// In zh, this message translates to:
  /// **'当前单词没有更多关联词了，选择新的起点继续探索吧！'**
  String get pathEndedContent;

  /// 选择新路径按钮
  ///
  /// In zh, this message translates to:
  /// **'选择新路径'**
  String get chooseNewPath;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
