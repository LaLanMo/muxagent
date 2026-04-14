import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/domain/message.dart';

void main() {
  test('MediaPart memoizes decoded base64 bytes', () {
    final media = MediaPart(
      base64: base64Encode(Uint8List.fromList([1, 2, 3, 4])),
    );

    final first = media.decodedBytes;
    final second = media.decodedBytes;

    expect(first, isNotNull);
    expect(first, [1, 2, 3, 4]);
    expect(identical(first, second), isTrue);
  });
}
