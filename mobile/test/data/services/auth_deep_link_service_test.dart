import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/models/auth_request.dart';
import 'package:muxagent/data/services/deep_links/auth_deep_link_service.dart';

void main() {
  late _FakeAppLinkSource linkSource;
  late List<AuthRequest> handledRequests;
  late AuthDeepLinkService service;

  setUp(() {
    linkSource = _FakeAppLinkSource();
    handledRequests = <AuthRequest>[];
    service = AuthDeepLinkService(
      linkSource: linkSource,
      onAuthRequest: handledRequests.add,
    );
  });

  tearDown(() async {
    service.onClose();
    await linkSource.close();
  });

  test('handles the initial muxagent auth link once', () async {
    linkSource.initialLink = Uri.parse(
      'muxagent://auth?id=req-1&relay=https%3A%2F%2Frelay.muxagent.com',
    );

    await service.init();

    expect(handledRequests, hasLength(1));
    expect(handledRequests.single.id, 'req-1');
    expect(handledRequests.single.relayUrl, 'https://relay.muxagent.com');
  });

  test('ignores non-auth and invalid links', () async {
    linkSource.initialLink = Uri.parse('https://example.com/nope');

    await service.init();
    linkSource.emit(
      Uri.parse('muxagent://auth?id=&relay=https%3A%2F%2Frelay.muxagent.com'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(handledRequests, isEmpty);
  });

  test(
    'deduplicates repeated auth links across initial and stream events',
    () async {
      final authLink = Uri.parse(
        'muxagent://auth?id=req-2&relay=https%3A%2F%2Frelay.muxagent.com',
      );
      linkSource.initialLink = authLink;

      await service.init();
      linkSource.emit(authLink);
      await Future<void>.delayed(Duration.zero);

      expect(handledRequests, hasLength(1));
    },
  );

  test('handles path-based auth links too', () async {
    await service.init();

    linkSource.emit(
      Uri.parse(
        'muxagent:/auth?id=req-3&relay=https%3A%2F%2Frelay.muxagent.com',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(handledRequests, hasLength(1));
    expect(handledRequests.single.id, 'req-3');
  });
}

class _FakeAppLinkSource implements AppLinkSource {
  Uri? initialLink;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void emit(Uri uri) {
    _controller.add(uri);
  }

  Future<void> close() async {
    await _controller.close();
  }
}
