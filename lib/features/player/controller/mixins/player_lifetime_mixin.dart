import 'dart:async';
import 'package:flutter/foundation.dart';

/// 播放器拥有的订阅和延迟任务随会话一起释放。
mixin PlayerLifetimeMixin on ChangeNotifier {
  bool _playbackDisposed = false;
  bool get playbackDisposed => _playbackDisposed;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Map<String, Timer> _timers = {};

  void trackPlaybackSubscription(StreamSubscription<dynamic> subscription) {
    _subscriptions.add(subscription);
  }

  void schedulePlaybackTask(String key, Duration delay, VoidCallback action) {
    _timers.remove(key)?.cancel();
    if (_playbackDisposed) return;
    _timers[key] = Timer(delay, () {
      _timers.remove(key);
      if (!_playbackDisposed) action();
    });
  }

  void cancelPlaybackTask(String key) => _timers.remove(key)?.cancel();

  void disposePlaybackLifetime() {
    _playbackDisposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
