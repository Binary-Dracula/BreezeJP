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

  /// 首页今日目标标签
  ///
  /// In zh, this message translates to:
  /// **'今日目标'**
  String get homeTodayGoal;

  /// 单词数量单位
  ///
  /// In zh, this message translates to:
  /// **'词'**
  String get homeWordsUnit;

  /// 首页复习标签
  ///
  /// In zh, this message translates to:
  /// **'复习'**
  String get homeReview;

  /// 首页新词标签
  ///
  /// In zh, this message translates to:
  /// **'新词'**
  String get homeNewWords;

  /// 通用加载提示
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// 学习状态标签
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get learning;

  /// 学习单词按钮
  ///
  /// In zh, this message translates to:
  /// **'学习单词'**
  String get learnWords;

  /// 加载单词提示
  ///
  /// In zh, this message translates to:
  /// **'正在加载单词...'**
  String get loadingWords;

  /// 无单词可学提示
  ///
  /// In zh, this message translates to:
  /// **'没有需要学习的单词'**
  String get noWordsToLearn;

  /// 例句标签
  ///
  /// In zh, this message translates to:
  /// **'例句'**
  String get examples;

  /// 评分按钮-重来
  ///
  /// In zh, this message translates to:
  /// **'重来'**
  String get ratingAgain;

  /// 评分按钮-重来副标题
  ///
  /// In zh, this message translates to:
  /// **'忘记'**
  String get ratingAgainSub;

  /// 评分按钮-困难
  ///
  /// In zh, this message translates to:
  /// **'困难'**
  String get ratingHard;

  /// 评分按钮-困难副标题
  ///
  /// In zh, this message translates to:
  /// **'模糊'**
  String get ratingHardSub;

  /// 评分按钮-良好
  ///
  /// In zh, this message translates to:
  /// **'良好'**
  String get ratingGood;

  /// 评分按钮-良好副标题
  ///
  /// In zh, this message translates to:
  /// **'记得'**
  String get ratingGoodSub;

  /// 评分按钮-简单
  ///
  /// In zh, this message translates to:
  /// **'简单'**
  String get ratingEasy;

  /// 评分按钮-简单副标题
  ///
  /// In zh, this message translates to:
  /// **'熟练'**
  String get ratingEasySub;

  /// 上一个按钮
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get previous;

  /// 下一个按钮
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get next;

  /// 学习完成标题
  ///
  /// In zh, this message translates to:
  /// **'学习完成！'**
  String get learningFinished;

  /// 学习完成描述
  ///
  /// In zh, this message translates to:
  /// **'你已完成本次学习。'**
  String get learningFinishedDesc;

  /// 返回主页按钮
  ///
  /// In zh, this message translates to:
  /// **'返回主页'**
  String get backToHome;

  /// 继续学习对话框标题
  ///
  /// In zh, this message translates to:
  /// **'继续学习？'**
  String get continueLearningTitle;

  /// 继续学习对话框内容
  ///
  /// In zh, this message translates to:
  /// **'你已完成当前队列。是否加载更多单词？'**
  String get continueLearningContent;

  /// 休息按钮
  ///
  /// In zh, this message translates to:
  /// **'休息一下'**
  String get restABit;

  /// 继续学习按钮
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

  /// 网络连接超时错误
  ///
  /// In zh, this message translates to:
  /// **'连接超时，请检查网络设置'**
  String get networkConnectionTimeout;

  /// 网络请求取消提示
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get networkRequestCancelled;

  /// 网络连接失败错误
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络设置'**
  String get networkConnectionFailed;

  /// SSL证书验证失败错误
  ///
  /// In zh, this message translates to:
  /// **'证书验证失败'**
  String get networkCertificateFailed;

  /// 网络请求失败错误
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败: {message}'**
  String networkRequestFailed(String message);

  /// 带状态码的网络请求失败错误
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败 (状态码: {code})'**
  String networkRequestFailedWithCode(String code);

  /// HTTP 400 错误
  ///
  /// In zh, this message translates to:
  /// **'请求参数错误'**
  String get networkBadRequest;

  /// HTTP 401 错误
  ///
  /// In zh, this message translates to:
  /// **'未授权，请重新登录'**
  String get networkUnauthorized;

  /// HTTP 403 错误
  ///
  /// In zh, this message translates to:
  /// **'拒绝访问'**
  String get networkForbidden;

  /// HTTP 404 错误
  ///
  /// In zh, this message translates to:
  /// **'请求的资源不存在'**
  String get networkNotFound;

  /// HTTP 500 错误
  ///
  /// In zh, this message translates to:
  /// **'服务器内部错误'**
  String get networkInternalServerError;

  /// HTTP 502 错误
  ///
  /// In zh, this message translates to:
  /// **'网关错误'**
  String get networkBadGateway;

  /// HTTP 503 错误
  ///
  /// In zh, this message translates to:
  /// **'服务不可用'**
  String get networkServiceUnavailable;

  /// 通用加载失败错误
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String loadFailed(String error);

  /// 搜索失败错误
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchFailed(String error);

  /// 提交失败错误
  ///
  /// In zh, this message translates to:
  /// **'提交失败: {error}'**
  String submitFailed(String error);

  /// 音频播放失败错误
  ///
  /// In zh, this message translates to:
  /// **'播放音频失败: {error}'**
  String playAudioFailed(String error);

  /// 在线音频加载失败错误
  ///
  /// In zh, this message translates to:
  /// **'无法加载在线音频: {url}'**
  String audioLoadFailedOnline(String url);

  /// 无在线音频源错误
  ///
  /// In zh, this message translates to:
  /// **'没有可用的在线音频: {filename}'**
  String audioNoOnlineSource(String filename);

  /// 复习模式提示点击查看答案
  ///
  /// In zh, this message translates to:
  /// **'点击查看释义'**
  String get tapToShowAnswer;

  /// 单词复习页面标题
  ///
  /// In zh, this message translates to:
  /// **'复习单词'**
  String get wordReviewTitle;

  /// 单词复习空状态
  ///
  /// In zh, this message translates to:
  /// **'暂无待复习单词'**
  String get wordReviewEmpty;

  /// 单词复习完成提示
  ///
  /// In zh, this message translates to:
  /// **'今日单词复习已完成'**
  String get wordReviewFinished;

  /// 单词复习题型标题-单词到释义
  ///
  /// In zh, this message translates to:
  /// **'单词 → 释义'**
  String get wordReviewTitleWordMeaning;

  /// 单词复习题型说明-单词到释义
  ///
  /// In zh, this message translates to:
  /// **'点击单词 → 点击正确释义'**
  String get wordReviewSubtitleWordMeaning;

  /// 单词复习题型标题-释义到单词
  ///
  /// In zh, this message translates to:
  /// **'释义 → 单词'**
  String get wordReviewTitleMeaningWord;

  /// 单词复习题型说明-释义到单词
  ///
  /// In zh, this message translates to:
  /// **'点击释义 → 点击正确单词'**
  String get wordReviewSubtitleMeaningWord;

  /// 单词复习题型标题-听音到单词
  ///
  /// In zh, this message translates to:
  /// **'听音辨单词'**
  String get wordReviewTitleAudioWord;

  /// 单词复习题型说明-听音到单词
  ///
  /// In zh, this message translates to:
  /// **'点击音频 → 点击对应单词'**
  String get wordReviewSubtitleAudioWord;

  /// 单词复习题型标题-读音到单词
  ///
  /// In zh, this message translates to:
  /// **'读音 → 单词'**
  String get wordReviewTitleReadingWord;

  /// 单词复习题型说明-读音到单词
  ///
  /// In zh, this message translates to:
  /// **'点击读音 → 点击对应单词'**
  String get wordReviewSubtitleReadingWord;

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

  /// 笔顺练习页面标题
  ///
  /// In zh, this message translates to:
  /// **'{kana} 笔顺练习'**
  String kanaStrokePracticeTitle(String kana);

  /// 笔顺练习播放音频按钮
  ///
  /// In zh, this message translates to:
  /// **'播放音频'**
  String get kanaStrokePlayAudio;

  /// 笔顺练习重新播放动画按钮
  ///
  /// In zh, this message translates to:
  /// **'重新播放'**
  String get kanaStrokeReplay;

  /// 提示先观看动画
  ///
  /// In zh, this message translates to:
  /// **'先观看完整书写动画，动画结束后开始描红练习。'**
  String get kanaStrokeWatchFirst;

  /// 描红阶段提示
  ///
  /// In zh, this message translates to:
  /// **'按照提示轨迹描红，每一笔都要准确。'**
  String get kanaStrokeTraceHint;

  /// 无笔顺数据提示
  ///
  /// In zh, this message translates to:
  /// **'暂无笔顺数据'**
  String get kanaStrokeNoData;

  /// 笔顺数据加载提示
  ///
  /// In zh, this message translates to:
  /// **'加载笔顺数据...'**
  String get kanaStrokeLoadingData;

  /// 动画播放提示
  ///
  /// In zh, this message translates to:
  /// **'正在播放笔顺动画...'**
  String get kanaStrokePlayingAnimation;

  /// 描红进度提示
  ///
  /// In zh, this message translates to:
  /// **'当前第 {current}/{total} 笔'**
  String kanaStrokeProgress(int current, int total);

  /// 描红完成提示
  ///
  /// In zh, this message translates to:
  /// **'练习完成！'**
  String get kanaStrokePracticeDone;

  /// 提示需要从起笔点开始描红
  ///
  /// In zh, this message translates to:
  /// **'从起笔点开始'**
  String get kanaStrokeStartFromAnchor;

  /// 提示重试描红
  ///
  /// In zh, this message translates to:
  /// **'再试一次'**
  String get kanaStrokeTryAgain;
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
