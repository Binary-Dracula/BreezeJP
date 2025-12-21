class StudySessionContext {
  final int userId;

  int durationMs = 0;

  int learned = 0;
  int reviewed = 0;
  int failed = 0;
  int mastered = 0;

  StudySessionContext({required this.userId});

  void addDuration(int ms) {
    durationMs += ms;
  }

  void markLearned() => learned++;
  void markReviewed() => reviewed++;
  void markFailed() => failed++;
  void markMastered() => mastered++;
}
