import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/services/pairing_deep_link_coordinator.dart';

class _FakePreferenceStore implements StringPreferenceStore {
  _FakePreferenceStore([Map<String, String> values = const {}])
    : _values = Map<String, String>.from(values);

  final Map<String, String> _values;

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativePreferencePairingLinkSource', () {
    test(
      'consumes an initial deeplink written by native startup handling',
      () async {
        const rawUri =
            'muxagent://auth?id=req-initial-123&relay=https%3A%2F%2Frelay.test';
        final preferences = _FakePreferenceStore({
          NativePreferencePairingLinkSource.pendingPairingLinkKey: rawUri,
        });
        final source = NativePreferencePairingLinkSource(
          preferences: preferences,
          enabled: true,
        );

        expect(await source.getInitialUri(), Uri.parse(rawUri));
        expect(
          await preferences.getString(
            NativePreferencePairingLinkSource.pendingPairingLinkKey,
          ),
          isNull,
        );
      },
    );

    test('emits live deeplinks written after startup', () async {
      final preferences = _FakePreferenceStore();
      final source = NativePreferencePairingLinkSource(
        preferences: preferences,
        enabled: true,
        pollInterval: const Duration(milliseconds: 10),
      );

      final pendingUri = source.uriStream.first.timeout(
        const Duration(seconds: 1),
      );

      await preferences.setString(
        NativePreferencePairingLinkSource.pendingPairingLinkKey,
        'muxagent://auth?id=req-live-456&relay=https%3A%2F%2Frelay.test',
      );

      expect(
        await pendingUri,
        Uri.parse(
          'muxagent://auth?id=req-live-456&relay=https%3A%2F%2Frelay.test',
        ),
      );
      expect(
        await preferences.getString(
          NativePreferencePairingLinkSource.pendingPairingLinkKey,
        ),
        isNull,
      );
    });
  });
}
