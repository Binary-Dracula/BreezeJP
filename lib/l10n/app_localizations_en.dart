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

  @override
  String get homeTodayGoal => 'Today\'s Goal';

  @override
  String get homeWordsUnit => 'Words';

  @override
  String get homeReview => 'Review';

  @override
  String get homeNewWords => 'New Words';

  @override
  String get loading => 'Loading...';

  @override
  String get learning => 'Learning';

  @override
  String get learnWords => 'Learn Words';

  @override
  String get loadingWords => 'Loading words...';

  @override
  String get noWordsToLearn => 'No words to learn';

  @override
  String get examples => 'Examples';

  @override
  String get ratingAgain => 'Again';

  @override
  String get ratingAgainSub => 'Again';

  @override
  String get ratingHard => 'Hard';

  @override
  String get ratingHardSub => 'Hard';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingGoodSub => 'Good';

  @override
  String get ratingEasy => 'Easy';

  @override
  String get ratingEasySub => 'Easy';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get learningFinished => 'Learning Finished!';

  @override
  String get learningFinishedDesc => 'You have completed this session.';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get continueLearningTitle => 'Continue Learning?';

  @override
  String get continueLearningContent =>
      'You have finished the current queue. Do you want to load more words?';

  @override
  String get restABit => 'No, take a break';

  @override
  String get continueLearning => 'Continue Learning';
}
