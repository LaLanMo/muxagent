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
}
