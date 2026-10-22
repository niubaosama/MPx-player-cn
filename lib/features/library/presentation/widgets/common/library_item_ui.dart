import 'package:flutter/widgets.dart';
import 'package:mpx/core/l10n/app_localizations.dart';
import '../../../domain/entities/file_item.dart';
import '../../../domain/entities/video_file.dart';

class LibraryItemUi {
  static String relativeDate(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return context.tr('today');
    if (diff.inDays == 1) return context.tr('yesterday');
    if (diff.inDays < 7) return context.tr('{value0}d ago', {'value0': diff.inDays});
    if (diff.inDays < 30) return context.tr('{value0}w ago', {'value0': diff.inDays ~/ 7});
    if (diff.inDays < 365) return context.tr('{value0}mo ago', {'value0': diff.inDays ~/ 30});
    return context.tr('{value0}y ago', {'value0': diff.inDays ~/ 365});
  }

  static String parentFolderName(String path) {
    final lastSeparator = path.lastIndexOf('/');
    if (lastSeparator <= 0) {
      return '/';
    }
    return path.substring(0, lastSeparator).split('/').last;
  }

  static String parentFolderPath(String path) {
    final lastSeparator = path.lastIndexOf('/');
    if (lastSeparator <= 0) {
      return '/';
    }
    return path.substring(0, lastSeparator);
  }

  static String folderVideoLabel(BuildContext context, int? count) {
    if (count == null) {
      return context.tr('Folder');
    }
    return count == 1 ? context.tr('1 video') : context.tr('{value0} videos', {'value0': count});
  }

  static VideoFile videoFromFileItem(FileItem item) {
    return VideoFile.fromFileItem(item, parentFolderPath(item.path));
  }

  static VideoFile videoFromPath(String path, {DateTime? modified}) {
    final item = FileItem(
      path: path,
      name: path.split('/').last,
      isDirectory: false,
      size: 0,
      modified: modified ?? DateTime.now(),
    );
    return videoFromFileItem(item);
  }
}
