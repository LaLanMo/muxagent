import 'package:flutter_test/flutter_test.dart';
import 'package:muxagent/data/repositories/replay_cursor_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReplayCursorRepository', () {
    late ReplayCursorRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = ReplayCursorRepository();
    });

    test('returns empty map when nothing is stored', () async {
      expect(await repository.loadAll(), isEmpty);
    });

    test('saves and restores cursors by machine id', () async {
      await repository.saveAll({
        'machine-1': const ReplayCursor(streamEpoch: 11, lastSeq: 9),
        'machine-2': const ReplayCursor(streamEpoch: 22, lastSeq: 3),
      });

      final restored = await repository.loadAll();

      expect(restored, hasLength(2));
      expect(restored['machine-1']?.streamEpoch, 11);
      expect(restored['machine-1']?.lastSeq, 9);
      expect(restored['machine-2']?.streamEpoch, 22);
      expect(restored['machine-2']?.lastSeq, 3);
    });

    test('ignores invalid stored entries', () async {
      SharedPreferences.setMockInitialValues({
        'replay_cursors': '''
          {
            "machine-1": {"stream_epoch": 5, "last_seq": 5},
            "machine-2": {"stream_epoch": 0, "last_seq": 4},
            "machine-3": {"stream_epoch": 7, "last_seq": "oops"}
          }
        ''',
      });
      repository = ReplayCursorRepository();

      final restored = await repository.loadAll();

      expect(restored.keys, ['machine-1']);
      expect(restored['machine-1']?.lastSeq, 5);
    });
  });
}
