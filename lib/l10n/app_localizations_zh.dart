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
}
