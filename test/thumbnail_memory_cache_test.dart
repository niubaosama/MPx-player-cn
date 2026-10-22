import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpx/features/library/services/thumbnail_cache.dart';

void main() {
  test('oversized thumbnail cannot exceed the cache memory budget', () {
    final cache = ThumbnailMemoryCache();
    cache.clear();
    cache.put('small', Uint8List.fromList([1, 2, 3]));
    cache.put('oversized', Uint8List(51 * 1024 * 1024));
    expect(cache.get('oversized'), isNull);
    expect(cache.get('small'), [1, 2, 3]);
    expect(cache.stats['entries'], 1);
    cache.clear();
  });
  test('thumbnail cache evicts least recently used entries', () {
    final cache = ThumbnailMemoryCache();
    cache.clear();
    for (var i = 0; i < 200; i++) {
      cache.put('$i', Uint8List(1));
    }
    cache.get('0');
    cache.put('new', Uint8List(1));
    expect(cache.get('1'), isNull);
    expect(cache.get('0'), isNotNull);
    expect(cache.stats['entries'], 200);
    cache.clear();
  });
}
