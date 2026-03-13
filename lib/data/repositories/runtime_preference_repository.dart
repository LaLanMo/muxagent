import 'package:shared_preferences/shared_preferences.dart';

class RuntimePreferenceRepository {
  static const _lastSelectedRuntimeKey = 'last_selected_runtime_id';
  static const _lastSelectedModePrefix = 'last_selected_mode_id.';

  Future<String?> getLastSelectedRuntimeId() async {
    final prefs = await SharedPreferences.getInstance();
    final runtimeId = prefs.getString(_lastSelectedRuntimeKey);
    if (runtimeId == null || runtimeId.isEmpty) {
      return null;
    }
    return runtimeId;
  }

  Future<void> setLastSelectedRuntimeId(String runtimeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedRuntimeKey, runtimeId);
  }

  Future<String?> getLastSelectedModeId(String runtimeId) async {
    if (runtimeId.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final modeId = prefs.getString('$_lastSelectedModePrefix$runtimeId');
    if (modeId == null || modeId.isEmpty) {
      return null;
    }
    return modeId;
  }

  Future<Map<String, String>> getLastSelectedModeIds(
    Iterable<String> runtimeIds,
  ) async {
    final ids = runtimeIds.where((runtimeId) => runtimeId.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return const <String, String>{};
    }

    final prefs = await SharedPreferences.getInstance();
    final modeIds = <String, String>{};
    for (final runtimeId in ids) {
      final modeId = prefs.getString('$_lastSelectedModePrefix$runtimeId');
      if (modeId == null || modeId.isEmpty) continue;
      modeIds[runtimeId] = modeId;
    }
    return modeIds;
  }

  Future<void> setLastSelectedModeId({
    required String runtimeId,
    required String modeId,
  }) async {
    if (runtimeId.isEmpty || modeId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_lastSelectedModePrefix$runtimeId', modeId);
  }
}
