import 'mode_option.dart';
import 'model_info.dart';

class SessionConfigSnapshot {
  final String? modeConfigId;
  final ModeOption? currentMode;
  final List<ModeOption> availableModes;
  final String? modelConfigId;
  final String? currentModel;
  final List<ModelInfo> availableModels;

  const SessionConfigSnapshot({
    this.modeConfigId,
    this.currentMode,
    this.availableModes = const [],
    this.modelConfigId,
    this.currentModel,
    this.availableModels = const [],
  });

  SessionConfigSnapshot copyWith({
    String? modeConfigId,
    bool clearModeConfigId = false,
    ModeOption? currentMode,
    bool clearCurrentMode = false,
    List<ModeOption>? availableModes,
    String? modelConfigId,
    bool clearModelConfigId = false,
    String? currentModel,
    bool clearCurrentModel = false,
    List<ModelInfo>? availableModels,
  }) {
    return SessionConfigSnapshot(
      modeConfigId: clearModeConfigId
          ? null
          : modeConfigId ?? this.modeConfigId,
      currentMode: clearCurrentMode ? null : currentMode ?? this.currentMode,
      availableModes: availableModes ?? this.availableModes,
      modelConfigId: clearModelConfigId
          ? null
          : modelConfigId ?? this.modelConfigId,
      currentModel: clearCurrentModel
          ? null
          : currentModel ?? this.currentModel,
      availableModels: availableModels ?? this.availableModels,
    );
  }
}
