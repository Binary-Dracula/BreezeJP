import '../study_log.dart';

class StudyLogItem {
  final StudyLog log;

  const StudyLogItem({required this.log});

  factory StudyLogItem.fromMap(Map<String, dynamic> map) {
    return StudyLogItem(log: StudyLog.fromMap(map));
  }
}
