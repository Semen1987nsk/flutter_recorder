import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buffers handed to Dart are allocated with malloc', () {
    // Dart releases them through flutter_recorder_nativeFree, which calls
    // free(); memory from new[] must be released with delete[] instead.
    final capture = File('src/capture.cpp').readAsStringSync();
    final nativeFree = File('src/flutter_recorder.cpp').readAsStringSync();

    expect(
      nativeFree,
      matches(
        RegExp(
          r'flutter_recorder_nativeFree\(void \*pointer\)\s*\{\s*'
          r'free\(pointer\);',
        ),
      ),
    );
    expect(capture, contains('nativeStreamDataCallback('));
    expect(
      capture,
      isNot(contains('new unsigned char[')),
      reason: 'new[] paired with free() is undefined behaviour.',
    );
  });

  test('event callbacks are created once per isolate', () {
    // init() calls setDartEventCallbacks on every start; a fresh
    // NativeCallable.listener each time keeps the isolate alive and leaks
    // the previous pair, which is never closed.
    final io = File('lib/src/bindings/recorder_io.dart').readAsStringSync();
    final start = io.indexOf('Future<void> setDartEventCallbacks()');
    final end = io.indexOf('@override', start);
    expect(start, greaterThanOrEqualTo(0));
    final body = io.substring(start, end);

    expect(body, isNot(contains('final nativeSilenceChangedCallable')));
    expect(body, isNot(contains('final nativeStreamDataCallable')));
    expect(body, contains('_silenceChangedCallable ??='));
    expect(body, contains('_streamDataCallable ??='));
  });
}
