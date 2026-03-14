import '../../../domain/model_info.dart';
import '../../../domain/mode_option.dart';
import '../../../domain/runtime_option.dart';
import '../../../domain/session_config_snapshot.dart';
import 'models/acp_session_models.dart';

class SessionConfigMapper {
  static RuntimeOption runtimeOptionFromDto(AppRuntimeInfoDto dto) {
    final snapshot = snapshotFromConfigOptions(
      runtimeId: dto.id,
      configOptions: dto.configOptions,
    );
    return RuntimeOption(
      id: dto.id,
      label: dto.label,
      ready: dto.ready,
      defaultModeId: snapshot.currentMode?.id ?? '',
      modeOptions: snapshot.availableModes,
    );
  }

  static SessionConfigSnapshot snapshotFromConfigOptions({
    required String runtimeId,
    required List<AcpSessionConfigOptionDto> configOptions,
    AcpSessionModeStateDto? modes,
  }) {
    String? modeConfigId;
    String? currentModeId = modes?.currentModeId;
    var availableModes = modes == null
        ? const <ModeOption>[]
        : ModeOption.orderedForRuntime(
            runtimeId,
            modes.availableModes.map(
              (mode) => ModeOption(
                id: mode.id,
                label: mode.name,
                description: mode.description,
              ),
            ),
          );

    String? modelConfigId;
    String? currentModel;
    var availableModels = const <ModelInfo>[];

    for (final option in configOptions) {
      switch (option.category) {
        case 'mode':
          modeConfigId = option.id;
          if (option.currentValue.isNotEmpty) {
            currentModeId = option.currentValue;
          }
          final flattened = option.options.flatten();
          availableModes = ModeOption.orderedForRuntime(
            runtimeId,
            flattened.map(
              (item) => ModeOption.fromConfigValue(
                value: item.value,
                name: item.name,
                description: item.description,
              ),
            ),
          );
        case 'model':
          modelConfigId = option.id;
          currentModel = option.currentValue;
          final flattened = option.options.flatten();
          availableModels = flattened
              .map(
                (item) => ModelInfo.fromConfigValue(
                  value: item.value,
                  name: item.name,
                  description: item.description,
                ),
              )
              .toList();
      }
    }

    ModeOption? currentMode;
    if ((currentModeId ?? '').isNotEmpty) {
      for (final option in availableModes) {
        if (option.id == currentModeId) {
          currentMode = option;
          break;
        }
      }
      currentMode ??= ModeOption.fromId(currentModeId);
    }

    return SessionConfigSnapshot(
      modeConfigId: modeConfigId,
      currentMode: currentMode,
      availableModes: availableModes,
      modelConfigId: modelConfigId,
      currentModel: currentModel,
      availableModels: availableModels,
    );
  }
}
