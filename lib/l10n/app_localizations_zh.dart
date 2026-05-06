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

  @override
  String get retryButton => '重试';

  @override
  String get greetingMorning => '早上好 ☀️';

  @override
  String get greetingAfternoon => '下午好 👋';

  @override
  String get greetingEvening => '晚上好 🌙';

  @override
  String userGreeting(String userName) {
    return 'Hi, $userName';
  }

  @override
  String get streakDays => '连续打卡';

  @override
  String get masteredWords => '已掌握';

  @override
  String get todayDuration => '今日时长';

  @override
  String get wordBook => '单词本';

  @override
  String get wordBookSubtitle => '查词与管理';

  @override
  String get detailedStats => '详细统计';

  @override
  String get detailedStatsSubtitle => '查看遗忘曲线';

  @override
  String get networkConnectionTimeout => '连接超时，请检查网络设置';

  @override
  String get networkRequestCancelled => '请求已取消';

  @override
  String get networkConnectionFailed => '网络连接失败，请检查网络设置';

  @override
  String get networkCertificateFailed => '证书验证失败';

  @override
  String networkRequestFailed(String message) {
    return '网络请求失败: $message';
  }

  @override
  String networkRequestFailedWithCode(String code) {
    return '网络请求失败 (状态码: $code)';
  }

  @override
  String get networkBadRequest => '请求参数错误';

  @override
  String get networkUnauthorized => '未授权，请重新登录';

  @override
  String get networkForbidden => '拒绝访问';

  @override
  String get networkNotFound => '请求的资源不存在';

  @override
  String get networkInternalServerError => '服务器内部错误';

  @override
  String get networkBadGateway => '网关错误';

  @override
  String get networkServiceUnavailable => '服务不可用';

  @override
  String get networkErrorTitle => '网络连接失败';

  @override
  String get networkErrorMessage => '请检查网络设置后重试';

  @override
  String loadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String searchFailed(String error) {
    return '搜索失败: $error';
  }

  @override
  String submitFailed(String error) {
    return '提交失败: $error';
  }

  @override
  String playAudioFailed(String error) {
    return '播放音频失败: $error';
  }

  @override
  String audioLoadFailedOnline(String url) {
    return '无法加载在线音频: $url';
  }

  @override
  String audioNoOnlineSource(String filename) {
    return '没有可用的在线音频: $filename';
  }

  @override
  String get tapToShowAnswer => '点击查看释义';

  @override
  String get wordReviewTitle => '复习单词';

  @override
  String get wordReviewEmpty => '暂无待复习单词';

  @override
  String get wordReviewFinished => '今日单词复习已完成';

  @override
  String get wordReviewTitleWordMeaning => '单词 → 释义';

  @override
  String get wordReviewSubtitleWordMeaning => '点击单词 → 点击正确释义';

  @override
  String get wordReviewTitleMeaningWord => '释义 → 单词';

  @override
  String get wordReviewSubtitleMeaningWord => '点击释义 → 点击正确单词';

  @override
  String get wordReviewTitleAudioWord => '听音辨单词';

  @override
  String get wordReviewSubtitleAudioWord => '点击音频 → 点击对应单词';

  @override
  String get wordReviewTitleReadingWord => '读音 → 单词';

  @override
  String get wordReviewTitleClozeTest => '例句填空';

  @override
  String get wordReviewContinue => '继续';

  @override
  String get wordReviewSubtitleReadingWord => '点击读音 → 点击对应单词';

  @override
  String get nextWord => '下一个';

  @override
  String get finish => '完成';

  @override
  String get initialChoiceTitle => '选择起点';

  @override
  String get initialChoiceSubtitle => '选择一个单词开始探索';

  @override
  String learnedCount(int count) {
    return '+$count';
  }

  @override
  String get pathEndedTitle => '已探索完这条路径';

  @override
  String get pathEndedContent => '当前单词没有更多关联词了，选择新的起点继续探索吧！';

  @override
  String get chooseNewPath => '选择新路径';

  @override
  String get commonRetry => '重试';

  @override
  String get learnNoWordsAvailable => '没有可学习的单词';

  @override
  String get learnBatchCompletedTitle => '当前批次已完成';

  @override
  String get learnBatchCompletedContent => '这一批单词都已经处理完了，继续拉取下一批进行学习吗？';

  @override
  String get learnBatchCompletedContinue => '继续下一批';

  @override
  String get learnBatchCompletedExit => '返回首页';

  @override
  String get learnNoMoreWordsTitle => '没有更多新词了';

  @override
  String get learnNoMoreWordsContent => '这本书当前没有更多新词可学，先回到首页吧。';

  @override
  String get learnConfirmIgnoreTitle => '确认忽略这个单词？';

  @override
  String get learnConfirmIgnoreContent => '忽略后会自动进入下一个单词，后续可在单词本中恢复。';

  @override
  String get learnConfirmMasteredTitle => '确认标记为已掌握？';

  @override
  String get learnConfirmMasteredContent => '标记后会自动进入下一个单词，后续可在单词本中恢复学习。';

  @override
  String get learnConfirmCancel => '取消';

  @override
  String get learnConfirmConfirm => '确认';

  @override
  String get settingsCurrentBook => '当前辞书';

  @override
  String get settingsNoSelectedBook => '未选择辞书';

  @override
  String get learnBookUnavailableTitle => '辞书不可用';

  @override
  String get learnBookUnavailableContent => '这本辞书已经不可用于继续学习新单词，请选择其他辞书。';

  @override
  String get learnBookUnavailableSelectBook => '选择辞书';

  @override
  String kanaStrokePracticeTitle(String kana) {
    return '$kana 笔顺练习';
  }

  @override
  String get kanaStrokePlayAudio => '播放音频';

  @override
  String get kanaStrokeReplay => '重新播放';

  @override
  String get kanaStrokeWatchFirst => '先观看完整书写动画，动画结束后开始描红练习。';

  @override
  String get kanaStrokeTraceHint => '按照提示轨迹描红，每一笔都要准确。';

  @override
  String get kanaStrokeNoData => '暂无笔顺数据';

  @override
  String get kanaStrokeLoadingData => '加载笔顺数据...';

  @override
  String get kanaStrokePlayingAnimation => '正在播放笔顺动画...';

  @override
  String kanaStrokeProgress(int current, int total) {
    return '当前第 $current/$total 笔';
  }

  @override
  String get kanaStrokePracticeDone => '练习完成！';

  @override
  String get kanaStrokeStartFromAnchor => '从起笔点开始';

  @override
  String get kanaStrokeTryAgain => '再试一次';

  @override
  String get referenceTitle => '基础知识速查';

  @override
  String get referenceTabNumbers => '数字';

  @override
  String get referenceTabDates => '日期/月份';

  @override
  String get referenceTabTime => '时间';

  @override
  String get referenceTabCounters => '量词';

  @override
  String get wordActionAddToReview => '加入复习';

  @override
  String get wordActionQuickMaster => '一键掌握';

  @override
  String get wordActionIgnore => '忽略';

  @override
  String get wordActionMastered => '已掌握';

  @override
  String get wordActionRestoreLearning => '恢复学习';

  @override
  String get wordDefinition => '释义';

  @override
  String get conjugationTitle => '活用';

  @override
  String get conjugationDictionaryForm => '原形';

  @override
  String get conjugationMasuForm => 'ます形';

  @override
  String get conjugationTeForm => 'て形';

  @override
  String get conjugationTaForm => 'た形';

  @override
  String get conjugationNaiForm => 'ない形';

  @override
  String get conjugationPotentialForm => '可能形';

  @override
  String get conjugationPassiveForm => '被动形';

  @override
  String get conjugationCausativeForm => '使役形';

  @override
  String get wordAdditionalInfo => '扩展内容';

  @override
  String get wordGrammarHints => '语法提示';

  @override
  String get wordCollocations => '常见搭配';

  @override
  String get wordSimilarWords => '近义词';

  @override
  String get wordOppositeWords => '反义词';

  @override
  String get wordCommonMistakes => '易错点';

  @override
  String get wordKanjiBreakdown => '汉字拆解';

  @override
  String wordPitchAccentLabel(String value) {
    return '音调 $value';
  }

  @override
  String get wordOnyomiLabel => '音读';

  @override
  String get wordKunyomiLabel => '训读';

  @override
  String get conjugationUnknown => '未知';

  @override
  String get grammarSectionMeaning => '含义';

  @override
  String get grammarSectionUsage => '接续';

  @override
  String get grammarSectionTip => '提示';

  @override
  String get grammarSectionRestrictions => '格式与限制';

  @override
  String get vocabularyBookNoLearningWords => '还没有正在学习的单词\n快去学习新单词吧！';

  @override
  String get vocabularyBookNoMasteredWords => '还没有掌握的单词\n继续加油学习吧！';

  @override
  String get vocabularyBookNoIgnoredWords => '没有已忽略的单词';

  @override
  String get vocabularyBookNoFavoriteWords => '还没有收藏的单词\n去详情页把重要单词收进单词本吧！';

  @override
  String get vocabularyBookSearchHint => '搜索单词、假名或释义...';

  @override
  String get vocabularyBookTabLearningLabel => '学习中';

  @override
  String get vocabularyBookTabMasteredLabel => '已掌握';

  @override
  String get vocabularyBookTabIgnoredLabel => '已忽略';

  @override
  String get vocabularyBookTabFavoritesLabel => '收藏';

  @override
  String vocabularyBookTabLearning(int count) {
    return '学习中 ($count)';
  }

  @override
  String vocabularyBookTabMastered(int count) {
    return '已掌握 ($count)';
  }

  @override
  String vocabularyBookTabIgnored(int count) {
    return '已忽略 ($count)';
  }

  @override
  String vocabularyBookTabFavorites(int count) {
    return '收藏 ($count)';
  }

  @override
  String vocabularyBookCountSummary(String tab, int count) {
    return '$tab · $count 个单词';
  }

  @override
  String get goToLearn => '去学习';

  @override
  String get actionMaster => '掌握';

  @override
  String get actionRestore => '恢复';

  @override
  String get actionFavorite => '收藏';

  @override
  String get actionUnfavorite => '取消收藏';

  @override
  String get actionFavoriteSentence => '收藏例句';

  @override
  String get actionUnfavoriteSentence => '取消收藏例句';

  @override
  String get exampleFavoritesTitle => '例句收藏';

  @override
  String get exampleFavoritesSearchHint => '搜索单词、例句或释义...';

  @override
  String exampleFavoritesCountSummary(int count) {
    return '共 $count 条例句';
  }

  @override
  String get exampleFavoritesEmpty => '还没有收藏的例句\n去单词详情里把高频表达收起来吧！';

  @override
  String get wordFavoriteToggleFailed => '单词收藏操作失败，请稍后再试';

  @override
  String get exampleFavoriteToggleFailed => '例句收藏操作失败，请稍后再试';

  @override
  String get homeSectionLearning => '学习主入口';

  @override
  String get homeSectionReview => '复习模块';

  @override
  String get homeSectionStats => '学习统计';

  @override
  String get homeSectionTools => '工具区';

  @override
  String get homeExampleFavoritesSubtitle => '把常用表达单独收进例句夹';

  @override
  String get homeKanaTitle => '学习五十音图';

  @override
  String get homeKanaSubtitle => '从基础发音开始打好根基';

  @override
  String get homeEnter => '进入';

  @override
  String get homeNewWordTitle => '学习新单词';

  @override
  String get homeNewWordSubtitleNewUser => '开始学习你的第一个单词';

  @override
  String get homeNewWordSubtitle => '继续探索新词';

  @override
  String get homeGrammarTitle => '学习语法';

  @override
  String get homeGrammarSubtitle => '掌握日语核心构造与句型';

  @override
  String get homeGrammarAccent => '浏览语法库';

  @override
  String get homeReviewWordTitle => '复习单词';

  @override
  String get homeReviewWordEmpty => '还没有需要复习的单词';

  @override
  String homeReviewWordCountDescription(int count) {
    return '今日待复习：$count 个单词';
  }

  @override
  String get homeReviewKanaTitle => '复习五十音';

  @override
  String get homeReviewKanaEmpty => '还没有需要复习的假名';

  @override
  String homeReviewKanaCountDescription(int count) {
    return '今日待复习：$count 个假名';
  }

  @override
  String get statsTodayLearning => '今日学习';

  @override
  String get statsTodayReview => '今日复习';

  @override
  String statsDurationMinutes(int minutes) {
    return '$minutes分钟';
  }

  @override
  String get statsNoActivityMessage => '今天还没有开始学习，试着学一个新单词吧';

  @override
  String get homeGrammarBookTitle => '语法本';

  @override
  String get homeGrammarBookSubtitle => '查看学习中和已掌握的语法';

  @override
  String get homeReadingTitle => '阅读模式';

  @override
  String get homeReadingSubtitle => '沉浸式日语文章阅读与听力';

  @override
  String get homeReferenceSubtitle => '数字、时间、日期等常识';

  @override
  String get issueReportTitle => '报告问题';

  @override
  String get issueReportHint => '请描述你发现的问题（可选）';

  @override
  String get issueReportSubmit => '提交';

  @override
  String get issueReportSuccess => '已提交，感谢反馈！';

  @override
  String get issueReportFailed => '提交失败，请稍后再试';
}
