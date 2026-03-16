Map<String, dynamic>? _nullableObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected "$key" to be an object or null');
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected "$key" to be a string or null');
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Expected "$key" to be a bool');
}

num _requireNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value;
  throw FormatException('Expected "$key" to be a number');
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list');
  }
  return value.map((item) {
    if (item is! Map) {
      throw FormatException('Expected "$key" items to be objects');
    }
    return Map<String, dynamic>.from(item);
  }).toList();
}

Map<String, dynamic> _withMeta(
  Map<String, dynamic> json,
  Map<String, dynamic>? meta,
) {
  if (meta != null) {
    json['_meta'] = meta;
  }
  return json;
}

class AcpSessionModeDto {
  final Map<String, dynamic>? meta;
  final String id;
  final String name;
  final String? description;

  const AcpSessionModeDto({
    required this.id,
    required this.name,
    this.description,
    this.meta,
  });

  factory AcpSessionModeDto.fromJson(Map<String, dynamic> json) {
    return AcpSessionModeDto(
      meta: _nullableObject(json, '_meta'),
      id: _requireString(json, 'id'),
      name: _requireString(json, 'name'),
      description: _nullableString(json, 'description'),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'id': id,
    'name': name,
    if (description != null) 'description': description,
  }, meta);
}

class AcpSessionModeStateDto {
  final Map<String, dynamic>? meta;
  final String currentModeId;
  final List<AcpSessionModeDto> availableModes;

  const AcpSessionModeStateDto({
    required this.currentModeId,
    required this.availableModes,
    this.meta,
  });

  factory AcpSessionModeStateDto.fromJson(Map<String, dynamic> json) {
    return AcpSessionModeStateDto(
      meta: _nullableObject(json, '_meta'),
      currentModeId: _requireString(json, 'currentModeId'),
      availableModes: _objectList(
        json,
        'availableModes',
      ).map(AcpSessionModeDto.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'currentModeId': currentModeId,
    'availableModes': availableModes.map((mode) => mode.toJson()).toList(),
  }, meta);
}

class AcpSessionConfigSelectOptionDto {
  final Map<String, dynamic>? meta;
  final String value;
  final String name;
  final String? description;

  const AcpSessionConfigSelectOptionDto({
    required this.value,
    required this.name,
    this.description,
    this.meta,
  });

  factory AcpSessionConfigSelectOptionDto.fromJson(Map<String, dynamic> json) {
    return AcpSessionConfigSelectOptionDto(
      meta: _nullableObject(json, '_meta'),
      value: _requireString(json, 'value'),
      name: _requireString(json, 'name'),
      description: _nullableString(json, 'description'),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'value': value,
    'name': name,
    if (description != null) 'description': description,
  }, meta);
}

class AcpSessionConfigSelectGroupDto {
  final Map<String, dynamic>? meta;
  final String group;
  final String name;
  final List<AcpSessionConfigSelectOptionDto> options;

  const AcpSessionConfigSelectGroupDto({
    required this.group,
    required this.name,
    required this.options,
    this.meta,
  });

  factory AcpSessionConfigSelectGroupDto.fromJson(Map<String, dynamic> json) {
    return AcpSessionConfigSelectGroupDto(
      meta: _nullableObject(json, '_meta'),
      group: _requireString(json, 'group'),
      name: _requireString(json, 'name'),
      options: _objectList(
        json,
        'options',
      ).map(AcpSessionConfigSelectOptionDto.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'group': group,
    'name': name,
    'options': options.map((option) => option.toJson()).toList(),
  }, meta);
}

class AcpSessionConfigSelectOptionsDto {
  final List<AcpSessionConfigSelectOptionDto> ungrouped;
  final List<AcpSessionConfigSelectGroupDto> grouped;

  const AcpSessionConfigSelectOptionsDto({
    this.ungrouped = const [],
    this.grouped = const [],
  });

  factory AcpSessionConfigSelectOptionsDto.fromJson(Object? json) {
    if (json == null) {
      throw FormatException('Expected "options" to be a list');
    }
    if (json is! List) {
      throw FormatException('Expected "options" to be a list');
    }
    if (json.isEmpty) {
      return const AcpSessionConfigSelectOptionsDto();
    }
    final first = json.first;
    if (first is! Map) {
      throw FormatException('Expected "options" items to be objects');
    }
    if (first.containsKey('group')) {
      return AcpSessionConfigSelectOptionsDto(
        grouped: json.map((item) {
          if (item is! Map) {
            throw FormatException('Expected grouped options to be objects');
          }
          return AcpSessionConfigSelectGroupDto.fromJson(
            Map<String, dynamic>.from(item),
          );
        }).toList(),
      );
    }
    return AcpSessionConfigSelectOptionsDto(
      ungrouped: json.map((item) {
        if (item is! Map) {
          throw FormatException('Expected ungrouped options to be objects');
        }
        return AcpSessionConfigSelectOptionDto.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList(),
    );
  }

  List<AcpSessionConfigSelectOptionDto> flatten() {
    if (grouped.isEmpty) return List.of(ungrouped);
    return [for (final group in grouped) ...group.options];
  }

  List<Map<String, dynamic>> toJson() {
    if (grouped.isNotEmpty) {
      return grouped.map((group) => group.toJson()).toList();
    }
    return ungrouped.map((option) => option.toJson()).toList();
  }
}

class AcpSessionConfigOptionDto {
  final Map<String, dynamic>? meta;
  final String id;
  final String name;
  final String type;
  final String currentValue;
  final String? description;
  final String? category;
  final AcpSessionConfigSelectOptionsDto options;

  const AcpSessionConfigOptionDto({
    required this.id,
    required this.name,
    required this.type,
    required this.currentValue,
    required this.options,
    this.description,
    this.category,
    this.meta,
  });

  factory AcpSessionConfigOptionDto.fromJson(Map<String, dynamic> json) {
    return AcpSessionConfigOptionDto(
      meta: _nullableObject(json, '_meta'),
      id: _requireString(json, 'id'),
      name: _requireString(json, 'name'),
      type: _requireString(json, 'type'),
      currentValue: _requireString(json, 'currentValue'),
      description: _nullableString(json, 'description'),
      category: _nullableString(json, 'category'),
      options: AcpSessionConfigSelectOptionsDto.fromJson(json['options']),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'id': id,
    'name': name,
    'type': type,
    'currentValue': currentValue,
    if (description != null) 'description': description,
    if (category != null) 'category': category,
    'options': options.toJson(),
  }, meta);
}

class AcpNewSessionResponseDto {
  final Map<String, dynamic>? meta;
  final String sessionId;
  final List<AcpSessionConfigOptionDto>? configOptions;
  final AcpSessionModeStateDto? modes;

  const AcpNewSessionResponseDto({
    required this.sessionId,
    this.configOptions,
    this.modes,
    this.meta,
  });

  factory AcpNewSessionResponseDto.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['configOptions'];
    return AcpNewSessionResponseDto(
      meta: _nullableObject(json, '_meta'),
      sessionId: _requireString(json, 'sessionId'),
      configOptions: rawOptions == null
          ? null
          : _objectList(
              json,
              'configOptions',
            ).map(AcpSessionConfigOptionDto.fromJson).toList(),
      modes: switch (json['modes']) {
        null => null,
        final Map value => AcpSessionModeStateDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "modes" to be an object or null'),
      },
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'sessionId': sessionId,
    if (modes != null) 'modes': modes!.toJson(),
    if (configOptions != null)
      'configOptions': configOptions!.map((option) => option.toJson()).toList(),
  }, meta);
}

class AcpLoadSessionResponseDto {
  final Map<String, dynamic>? meta;
  final List<AcpSessionConfigOptionDto>? configOptions;
  final AcpSessionModeStateDto? modes;

  const AcpLoadSessionResponseDto({this.configOptions, this.modes, this.meta});

  factory AcpLoadSessionResponseDto.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['configOptions'];
    return AcpLoadSessionResponseDto(
      meta: _nullableObject(json, '_meta'),
      configOptions: rawOptions == null
          ? null
          : _objectList(
              json,
              'configOptions',
            ).map(AcpSessionConfigOptionDto.fromJson).toList(),
      modes: switch (json['modes']) {
        null => null,
        final Map value => AcpSessionModeStateDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "modes" to be an object or null'),
      },
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    if (modes != null) 'modes': modes!.toJson(),
    if (configOptions != null)
      'configOptions': configOptions!.map((option) => option.toJson()).toList(),
  }, meta);
}

class AcpSetSessionConfigOptionResponseDto {
  final Map<String, dynamic>? meta;
  final List<AcpSessionConfigOptionDto> configOptions;

  const AcpSetSessionConfigOptionResponseDto({
    required this.configOptions,
    this.meta,
  });

  factory AcpSetSessionConfigOptionResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return AcpSetSessionConfigOptionResponseDto(
      meta: _nullableObject(json, '_meta'),
      configOptions: _objectList(
        json,
        'configOptions',
      ).map(AcpSessionConfigOptionDto.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'configOptions': configOptions.map((option) => option.toJson()).toList(),
  }, meta);
}

class AcpCurrentModeUpdateDto {
  final Map<String, dynamic>? meta;
  final String currentModeId;

  const AcpCurrentModeUpdateDto({required this.currentModeId, this.meta});

  factory AcpCurrentModeUpdateDto.fromJson(Map<String, dynamic> json) {
    return AcpCurrentModeUpdateDto(
      meta: _nullableObject(json, '_meta'),
      currentModeId: _requireString(json, 'currentModeId'),
    );
  }

  Map<String, dynamic> toJson() =>
      _withMeta({'currentModeId': currentModeId}, meta);
}

class AcpConfigOptionUpdateDto {
  final Map<String, dynamic>? meta;
  final List<AcpSessionConfigOptionDto> configOptions;

  const AcpConfigOptionUpdateDto({required this.configOptions, this.meta});

  factory AcpConfigOptionUpdateDto.fromJson(Map<String, dynamic> json) {
    return AcpConfigOptionUpdateDto(
      meta: _nullableObject(json, '_meta'),
      configOptions: _objectList(
        json,
        'configOptions',
      ).map(AcpSessionConfigOptionDto.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'configOptions': configOptions.map((option) => option.toJson()).toList(),
  }, meta);
}

class AcpPlanEntryDto {
  final Map<String, dynamic>? meta;
  final String content;
  final String priority;
  final String status;

  const AcpPlanEntryDto({
    required this.content,
    required this.priority,
    required this.status,
    this.meta,
  });

  factory AcpPlanEntryDto.fromJson(Map<String, dynamic> json) {
    return AcpPlanEntryDto(
      meta: _nullableObject(json, '_meta'),
      content: _requireString(json, 'content'),
      priority: _requireString(json, 'priority'),
      status: _requireString(json, 'status'),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    'content': content,
    'priority': priority,
    'status': status,
  }, meta);
}

class AcpPlanUpdateDto {
  final Map<String, dynamic>? meta;
  final String? sessionUpdate;
  final List<AcpPlanEntryDto> entries;

  const AcpPlanUpdateDto({
    required this.entries,
    this.sessionUpdate,
    this.meta,
  });

  factory AcpPlanUpdateDto.fromJson(Map<String, dynamic> json) {
    return AcpPlanUpdateDto(
      meta: _nullableObject(json, '_meta'),
      sessionUpdate: _nullableString(json, 'sessionUpdate'),
      entries: _objectList(
        json,
        'entries',
      ).map(AcpPlanEntryDto.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    if (sessionUpdate != null) 'sessionUpdate': sessionUpdate,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  }, meta);
}

class AcpUsageCostDto {
  final double amount;
  final String currency;

  const AcpUsageCostDto({required this.amount, required this.currency});

  factory AcpUsageCostDto.fromJson(Map<String, dynamic> json) {
    return AcpUsageCostDto(
      amount: _requireNum(json, 'amount').toDouble(),
      currency: _requireString(json, 'currency'),
    );
  }

  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};
}

class AcpUsageUpdateDto {
  final Map<String, dynamic>? meta;
  final String? sessionUpdate;
  final int used;
  final int size;
  final AcpUsageCostDto? cost;

  const AcpUsageUpdateDto({
    required this.used,
    required this.size,
    this.cost,
    this.sessionUpdate,
    this.meta,
  });

  factory AcpUsageUpdateDto.fromJson(Map<String, dynamic> json) {
    return AcpUsageUpdateDto(
      meta: _nullableObject(json, '_meta'),
      sessionUpdate: _nullableString(json, 'sessionUpdate'),
      used: _requireNum(json, 'used').toInt(),
      size: _requireNum(json, 'size').toInt(),
      cost: switch (json['cost']) {
        null => null,
        final Map value => AcpUsageCostDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "cost" to be an object or null'),
      },
    );
  }

  Map<String, dynamic> toJson() => _withMeta({
    if (sessionUpdate != null) 'sessionUpdate': sessionUpdate,
    'used': used,
    'size': size,
    if (cost != null) 'cost': cost!.toJson(),
  }, meta);
}

class AppSessionCreateDto {
  final String runtime;
  final String cwd;

  const AppSessionCreateDto({required this.runtime, required this.cwd});

  factory AppSessionCreateDto.fromJson(Map<String, dynamic> json) {
    return AppSessionCreateDto(
      runtime: _requireString(json, 'runtime'),
      cwd: _requireString(json, 'cwd'),
    );
  }
}

class AppSessionCreateResponseDto {
  final AppSessionCreateDto app;
  final AcpNewSessionResponseDto acp;

  const AppSessionCreateResponseDto({required this.app, required this.acp});

  factory AppSessionCreateResponseDto.fromJson(Map<String, dynamic> json) {
    return AppSessionCreateResponseDto(
      app: AppSessionCreateDto.fromJson(
        Map<String, dynamic>.from(json['app'] as Map),
      ),
      acp: AcpNewSessionResponseDto.fromJson(
        Map<String, dynamic>.from(json['acp'] as Map),
      ),
    );
  }
}

class AppSessionLoadDto {
  final bool ok;
  final String runtime;

  const AppSessionLoadDto({required this.ok, required this.runtime});

  factory AppSessionLoadDto.fromJson(Map<String, dynamic> json) {
    return AppSessionLoadDto(
      ok: _requireBool(json, 'ok'),
      runtime: _requireString(json, 'runtime'),
    );
  }
}

class AppSessionLoadResponseDto {
  final AppSessionLoadDto app;
  final AcpLoadSessionResponseDto acp;

  const AppSessionLoadResponseDto({required this.app, required this.acp});

  factory AppSessionLoadResponseDto.fromJson(Map<String, dynamic> json) {
    return AppSessionLoadResponseDto(
      app: AppSessionLoadDto.fromJson(
        Map<String, dynamic>.from(json['app'] as Map),
      ),
      acp: AcpLoadSessionResponseDto.fromJson(
        Map<String, dynamic>.from(json['acp'] as Map),
      ),
    );
  }
}

class AppRuntimeInfoDto {
  final String id;
  final String label;
  final bool ready;
  final List<AcpSessionConfigOptionDto> configOptions;

  const AppRuntimeInfoDto({
    required this.id,
    required this.label,
    required this.ready,
    this.configOptions = const [],
  });

  factory AppRuntimeInfoDto.fromJson(Map<String, dynamic> json) {
    return AppRuntimeInfoDto(
      id: _requireString(json, 'id'),
      label: _requireString(json, 'label'),
      ready: _requireBool(json, 'ready'),
      configOptions: _objectList(
        json,
        'configOptions',
      ).map(AcpSessionConfigOptionDto.fromJson).toList(),
    );
  }
}

class AppRuntimeListResponseDto {
  final List<AppRuntimeInfoDto> runtimes;

  const AppRuntimeListResponseDto({this.runtimes = const []});

  factory AppRuntimeListResponseDto.fromJson(Map<String, dynamic> json) {
    return AppRuntimeListResponseDto(
      runtimes: _objectList(
        json,
        'runtimes',
      ).map(AppRuntimeInfoDto.fromJson).toList(),
    );
  }
}

class AppSessionModeChangeDto {
  final String currentModeId;

  const AppSessionModeChangeDto({required this.currentModeId});

  factory AppSessionModeChangeDto.fromJson(Map<String, dynamic> json) {
    return AppSessionModeChangeDto(
      currentModeId: _requireString(json, 'currentModeId'),
    );
  }
}

class AppSessionConfigValueDto {
  final String value;
  final String name;
  final String? description;

  const AppSessionConfigValueDto({
    required this.value,
    required this.name,
    this.description,
  });

  factory AppSessionConfigValueDto.fromJson(Map<String, dynamic> json) {
    return AppSessionConfigValueDto(
      value: _requireString(json, 'value'),
      name: _requireString(json, 'name'),
      description: _nullableString(json, 'description'),
    );
  }
}

class AppSessionConfigChangeDto {
  final String configId;
  final String currentValue;
  final String? category;
  final List<AppSessionConfigValueDto> values;

  const AppSessionConfigChangeDto({
    required this.configId,
    required this.currentValue,
    required this.values,
    this.category,
  });

  factory AppSessionConfigChangeDto.fromJson(Map<String, dynamic> json) {
    return AppSessionConfigChangeDto(
      configId: _requireString(json, 'configId'),
      currentValue: _requireString(json, 'currentValue'),
      category: _nullableString(json, 'category'),
      values: _objectList(
        json,
        'values',
      ).map(AppSessionConfigValueDto.fromJson).toList(),
    );
  }
}

class AppModeChangedEventDataDto {
  final AppSessionModeChangeDto app;
  final AcpModeChangeSourceDto? acp;

  const AppModeChangedEventDataDto({required this.app, this.acp});

  factory AppModeChangedEventDataDto.fromJson(Map<String, dynamic> json) {
    return AppModeChangedEventDataDto(
      app: AppSessionModeChangeDto.fromJson(
        Map<String, dynamic>.from(json['app'] as Map),
      ),
      acp: switch (json['acp']) {
        null => null,
        final Map value => AcpModeChangeSourceDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "acp" to be an object or null'),
      },
    );
  }
}

class AcpModeChangeSourceDto {
  final AcpCurrentModeUpdateDto? currentModeUpdate;
  final AcpConfigOptionUpdateDto? configOptionUpdate;

  const AcpModeChangeSourceDto._({
    this.currentModeUpdate,
    this.configOptionUpdate,
  });

  factory AcpModeChangeSourceDto.currentMode(AcpCurrentModeUpdateDto dto) {
    return AcpModeChangeSourceDto._(currentModeUpdate: dto);
  }

  factory AcpModeChangeSourceDto.configOption(AcpConfigOptionUpdateDto dto) {
    return AcpModeChangeSourceDto._(configOptionUpdate: dto);
  }

  factory AcpModeChangeSourceDto.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('currentModeId')) {
      return AcpModeChangeSourceDto.currentMode(
        AcpCurrentModeUpdateDto.fromJson(json),
      );
    }
    if (json.containsKey('configOptions')) {
      return AcpModeChangeSourceDto.configOption(
        AcpConfigOptionUpdateDto.fromJson(json),
      );
    }
    throw FormatException(
      'Expected mode change ACP payload to be current_mode_update or config_option_update',
    );
  }
}

class AppConfigChangedEventDataDto {
  final AppSessionConfigChangeDto app;
  final AcpConfigOptionUpdateDto? acp;

  const AppConfigChangedEventDataDto({required this.app, this.acp});

  factory AppConfigChangedEventDataDto.fromJson(Map<String, dynamic> json) {
    return AppConfigChangedEventDataDto(
      app: AppSessionConfigChangeDto.fromJson(
        Map<String, dynamic>.from(json['app'] as Map),
      ),
      acp: switch (json['acp']) {
        null => null,
        final Map value => AcpConfigOptionUpdateDto.fromJson(
          Map<String, dynamic>.from(value),
        ),
        _ => throw FormatException('Expected "acp" to be an object or null'),
      },
    );
  }
}
