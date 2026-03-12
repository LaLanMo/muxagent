import 'mode_option.dart';

class RuntimeOption {
  final String id;
  final String label;
  final bool ready;
  final bool isDefault;
  final String defaultModeId;
  final List<ModeOption> modeOptions;

  const RuntimeOption({
    required this.id,
    required this.label,
    required this.ready,
    required this.isDefault,
    required this.defaultModeId,
    required this.modeOptions,
  });

  factory RuntimeOption.fromJson(Map<String, dynamic> json) {
    final rawConfigOptions = json['configOptions'] as List? ?? const [];
    var defaultModeId = '';
    var modeOptions = const <ModeOption>[];

    for (final raw in rawConfigOptions) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if ((item['category'] as String? ?? '') != 'mode') continue;
      defaultModeId = item['currentValue'] as String? ?? '';
      final rawValues = item['options'] as List? ?? const [];
      modeOptions = rawValues
          .whereType<Map>()
          .map((value) => ModeOption.fromJson(Map<String, dynamic>.from(value)))
          .toList();
      break;
    }

    return RuntimeOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      ready: json['ready'] as bool? ?? false,
      isDefault: json['default'] as bool? ?? false,
      defaultModeId: defaultModeId,
      modeOptions: modeOptions,
    );
  }
}
