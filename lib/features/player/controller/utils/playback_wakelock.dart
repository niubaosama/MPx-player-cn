import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/services/logger_service.dart';

class PlaybackWakelock {
  static final Set<Object> _owners = {};
  static Future<void> _pending = Future.value();
  static Future<void> setActive(Object owner, bool active) {
    final changed = active ? _owners.add(owner) : _owners.remove(owner);
    if (!changed) return _pending;
    _pending = _pending
        .then((_) => WakelockPlus.toggle(enable: _owners.isNotEmpty))
        .catchError((Object error) {
      AppLogger.w('Unable to update playback wakelock: $error');
    });
    return _pending;
  }
}
