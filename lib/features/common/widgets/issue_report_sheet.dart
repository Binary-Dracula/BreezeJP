import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/commands/issue_report_command.dart';
import '../../../data/commands/issue_report_command_provider.dart';
import '../../../l10n/app_localizations.dart';

/// 问题上报 BottomSheet
///
/// 使用方式：
/// ```dart
/// IssueReportSheet.show(
///   context: context,
///   ref: ref,
///   contentType: 'word',
///   contentId: word.id,
///   contentSnapshot: wordDetail.toSnapshot(),
/// );
/// ```
class IssueReportSheet extends ConsumerStatefulWidget {
  final String contentType;
  final String contentId;
  final Map<String, dynamic> contentSnapshot;
  final String displayTitle;

  const IssueReportSheet({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.contentSnapshot,
    required this.displayTitle,
  });

  /// 便捷方法：弹出问题上报 BottomSheet
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required String contentType,
    required String contentId,
    required Map<String, dynamic> contentSnapshot,
    required String displayTitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => IssueReportSheet(
        contentType: contentType,
        contentId: contentId,
        contentSnapshot: contentSnapshot,
        displayTitle: displayTitle,
      ),
    );
  }

  @override
  ConsumerState<IssueReportSheet> createState() => _IssueReportSheetState();
}

class _IssueReportSheetState extends ConsumerState<IssueReportSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final l10n = AppLocalizations.of(context)!;

    if (Supabase.instance.client.auth.currentSession == null) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.networkUnauthorized)));
        context.push('/login');
      }
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await ref
          .read(issueReportCommandProvider)
          .reportIssue(
            contentType: widget.contentType,
            contentId: widget.contentId,
            contentSnapshot: widget.contentSnapshot,
            message: _controller.text.trim().isEmpty
                ? null
                : _controller.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.issueReportSuccess)));
      }
    } on IssueReportAuthRequiredException {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.networkUnauthorized)));
        context.push('/login');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.issueReportFailed)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          Text(
            l10n.issueReportTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // 上报对象
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.contentType == 'word'
                      ? Icons.translate
                      : Icons.menu_book,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.displayTitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 问题描述输入框
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n.issueReportHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // 提交按钮
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.issueReportSubmit),
          ),
        ],
      ),
    );
  }
}
