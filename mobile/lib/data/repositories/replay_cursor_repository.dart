import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReplayCursor {
  final int streamEpoch;
  final int lastSeq;

  const ReplayCursor({required this.streamEpoch, required this.lastSeq});

  Map<String, dynamic> toJson() => {
    'stream_epoch': streamEpoch,
    'last_seq': lastSeq,
  };

  static ReplayCursor? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final streamEpoch = json['stream_epoch'];
    final lastSeq = json['last_seq'];
    if (streamEpoch is! num || lastSeq is! num) return null;
    final epoch = streamEpoch.toInt();
    final seq = lastSeq.toInt();
    if (epoch <= 0 || seq < 0) return null;
    return ReplayCursor(streamEpoch: epoch, lastSeq: seq);
  }
}

class ReplayCursorRepository {
  static const _storageKey = 'replay_cursors';

  Future<Map<String, ReplayCursor>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <String, ReplayCursor>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const <String, ReplayCursor>{};
    }

    final cursors = <String, ReplayCursor>{};
    decoded.forEach((key, value) {
      if (key is! String || key.isEmpty) return;
      final cursor = ReplayCursor.fromJson(value);
      if (cursor == null) return;
      cursors[key] = cursor;
    });
    return cursors;
  }

  Future<void> saveAll(Map<String, ReplayCursor> cursors) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = <String, dynamic>{};
    cursors.forEach((machineId, cursor) {
      if (machineId.isEmpty) return;
      normalized[machineId] = cursor.toJson();
    });
    await prefs.setString(_storageKey, jsonEncode(normalized));
  }
}
