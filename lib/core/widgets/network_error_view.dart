import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 通用网络错误视图。
///
/// 当页面因网络超时或断网无法加载数据时显示，提供友好的图标、提示文案以及重试按钮。
/// 用法：在任何需要处理网络错误的 Widget 的 build 方法中直接返回该组件。
///
/// ```dart
/// if (state.isNetworkError) {
///   return NetworkErrorView(onRetry: () => controller.load());
/// }
/// ```
class NetworkErrorView extends StatelessWidget {
  /// 点击重试按钮时的回调。
  final VoidCallback onRetry;

  /// 可选：自定义标题（默认使用 l10n.networkErrorTitle）。
  final String? title;

  /// 可选：自定义描述（默认使用 l10n.networkErrorMessage）。
  final String? message;

  const NetworkErrorView({
    super.key,
    required this.onRetry,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = title ?? l10n.networkErrorTitle;
    final displayMessage = message ?? l10n.networkErrorMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: Color(0xFF5C8DFF),
              ),
            ),
            const SizedBox(height: 24),
            // 标题
            Text(
              displayTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 描述
            Text(
              displayMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 重试按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retryButton),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5C8DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
