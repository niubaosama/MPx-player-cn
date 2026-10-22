import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'messages_zh.dart';

/// 应用语言。存储枚举名称，避免把翻译后的文字写入设置。
enum AppLanguage { system, zh, en }

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [Locale('en'), Locale('zh')];
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
  static final _placeholderPattern = RegExp(r'\{(\w+)\}');

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// 英文原文作为资源键；动态内容使用占位符，文件名等原值不参与翻译。
  String text(String message, [Map<String, Object?> values = const {}]) {
    final result = locale.languageCode == 'zh'
        ? (zhMessages[message] ?? message)
        : message;
    return result.replaceAllMapped(_placeholderPattern, (match) {
      final key = match.group(1)!;
      return values.containsKey(key) ? '${values[key]}' : match.group(0)!;
    });
  }

  String relativeDate(DateTime date, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(date);
    if (diff.inMinutes < 1) return text('Just now');
    if (diff.inHours < 1) {
      return text('{count} min ago', {'count': diff.inMinutes});
    }
    if (diff.inDays < 1) {
      return text('{count} hours ago', {'count': diff.inHours});
    }
    if (diff.inDays == 1) return text('Yesterday');
    if (diff.inDays < 7) {
      return text('{count} days ago', {'count': diff.inDays});
    }
    if (diff.inDays < 30) {
      return text('{count} weeks ago', {'count': diff.inDays ~/ 7});
    }
    if (diff.inDays < 365) {
      return text('{count} months ago', {'count': diff.inDays ~/ 30});
    }
    return text('{count} years ago', {'count': diff.inDays ~/ 365});
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String message, [Map<String, Object?> values = const {}]) =>
      l10n.text(message, values);
}
