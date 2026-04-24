import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'issue_report_command.dart';

/// IssueReportCommand Provider
final issueReportCommandProvider = Provider<IssueReportCommand>((ref) {
  return IssueReportCommand();
});
