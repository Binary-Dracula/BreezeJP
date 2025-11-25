import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// 获取全局 AppLocalizations 实例
/// 注意：仅适用于当前单语言 (zh) 环境，多语言环境下需要传入 Context 或 Locale
AppLocalizations get l10n => lookupAppLocalizations(const Locale('zh'));
