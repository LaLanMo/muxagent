import '../../../domain/model_info.dart';
import '../../../domain/mode_option.dart';
import '../../../domain/session_config_snapshot.dart';

Map<String, dynamic> serializeSessionConfigSnapshot(
  SessionConfigSnapshot snapshot,
) {
  return {
    'modeConfigId': snapshot.modeConfigId ?? '',
    'modelConfigId': snapshot.modelConfigId ?? '',
    'currentModel': snapshot.currentModel,
    'currentMode': snapshot.currentMode == null
        ? null
        : _serializeMode(snapshot.currentMode!),
    'availableModels': snapshot.availableModels.map(_serializeModel).toList(),
    'availableModes': snapshot.availableModes.map(_serializeMode).toList(),
  };
}

SessionConfigSnapshot? deserializeSessionConfigSnapshot(
  Map<String, dynamic> json,
) {
  final modeConfigIdRaw = json['modeConfigId'];
  final modelConfigIdRaw = json['modelConfigId'];
  if ((modeConfigIdRaw != null && modeConfigIdRaw is! String) ||
      (modelConfigIdRaw != null && modelConfigIdRaw is! String) ||
      json['availableModels'] is! List ||
      json['availableModes'] is! List) {
    return null;
  }

  final availableModels = <ModelInfo>[];
  for (final rawModel in json['availableModels'] as List) {
    if (rawModel is! Map) {
      return null;
    }
    final value = rawModel['value'] as String?;
    final name = rawModel['name'] as String?;
    if (value == null || name == null) {
      return null;
    }
    availableModels.add(
      ModelInfo(
        value: value,
        name: name,
        description: rawModel['description'] as String?,
      ),
    );
  }

  final availableModes = <ModeOption>[];
  for (final rawMode in json['availableModes'] as List) {
    if (rawMode is! Map) {
      return null;
    }
    final id = rawMode['id'] as String?;
    final label = rawMode['label'] as String?;
    if (id == null || label == null) {
      return null;
    }
    availableModes.add(
      ModeOption(
        id: id,
        label: label,
        description: rawMode['description'] as String?,
      ),
    );
  }

  final currentModeRaw = json['currentMode'];
  ModeOption? currentMode;
  if (currentModeRaw is Map) {
    final id = currentModeRaw['id'] as String?;
    final label = currentModeRaw['label'] as String?;
    if (id == null || label == null) {
      return null;
    }
    currentMode = ModeOption(
      id: id,
      label: label,
      description: currentModeRaw['description'] as String?,
    );
  }

  return SessionConfigSnapshot(
    modeConfigId: (modeConfigIdRaw ?? '').toString().isEmpty
        ? null
        : modeConfigIdRaw as String?,
    modelConfigId: (modelConfigIdRaw ?? '').toString().isEmpty
        ? null
        : modelConfigIdRaw as String?,
    currentModel: json['currentModel'] as String?,
    currentMode: currentMode,
    availableModels: availableModels,
    availableModes: availableModes,
  );
}

Map<String, dynamic> _serializeModel(ModelInfo model) {
  return {
    'value': model.value,
    'name': model.name,
    'description': model.description,
  };
}

Map<String, dynamic> _serializeMode(ModeOption mode) {
  return {'id': mode.id, 'label': mode.label, 'description': mode.description};
}
