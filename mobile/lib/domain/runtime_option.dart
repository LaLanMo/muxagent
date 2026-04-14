import 'mode_option.dart';

class RuntimeOption {
  final String id;
  final String label;
  final bool ready;
  final String defaultModeId;
  final List<ModeOption> modeOptions;

  const RuntimeOption({
    required this.id,
    required this.label,
    required this.ready,
    required this.defaultModeId,
    required this.modeOptions,
  });
}
