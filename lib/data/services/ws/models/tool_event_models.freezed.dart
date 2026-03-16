// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_event_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ToolEventEnvelopeDto _$ToolEventEnvelopeDtoFromJson(Map<String, dynamic> json) {
  return _ToolEventEnvelopeDto.fromJson(json);
}

/// @nodoc
mixin _$ToolEventEnvelopeDto {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String? get sessionId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  DateTime? get at => throw _privateConstructorUsedError;
  ToolWireDto get tool => throw _privateConstructorUsedError;

  /// Serializes this ToolEventEnvelopeDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolEventEnvelopeDtoCopyWith<ToolEventEnvelopeDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolEventEnvelopeDtoCopyWith<$Res> {
  factory $ToolEventEnvelopeDtoCopyWith(
    ToolEventEnvelopeDto value,
    $Res Function(ToolEventEnvelopeDto) then,
  ) = _$ToolEventEnvelopeDtoCopyWithImpl<$Res, ToolEventEnvelopeDto>;
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    ToolWireDto tool,
  });

  $ToolWireDtoCopyWith<$Res> get tool;
}

/// @nodoc
class _$ToolEventEnvelopeDtoCopyWithImpl<
  $Res,
  $Val extends ToolEventEnvelopeDto
>
    implements $ToolEventEnvelopeDtoCopyWith<$Res> {
  _$ToolEventEnvelopeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? tool = null,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionId: freezed == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String?,
            seq: null == seq
                ? _value.seq
                : seq // ignore: cast_nullable_to_non_nullable
                      as int,
            at: freezed == at
                ? _value.at
                : at // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            tool: null == tool
                ? _value.tool
                : tool // ignore: cast_nullable_to_non_nullable
                      as ToolWireDto,
          )
          as $Val,
    );
  }

  /// Create a copy of ToolEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ToolWireDtoCopyWith<$Res> get tool {
    return $ToolWireDtoCopyWith<$Res>(_value.tool, (value) {
      return _then(_value.copyWith(tool: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ToolEventEnvelopeDtoImplCopyWith<$Res>
    implements $ToolEventEnvelopeDtoCopyWith<$Res> {
  factory _$$ToolEventEnvelopeDtoImplCopyWith(
    _$ToolEventEnvelopeDtoImpl value,
    $Res Function(_$ToolEventEnvelopeDtoImpl) then,
  ) = __$$ToolEventEnvelopeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    ToolWireDto tool,
  });

  @override
  $ToolWireDtoCopyWith<$Res> get tool;
}

/// @nodoc
class __$$ToolEventEnvelopeDtoImplCopyWithImpl<$Res>
    extends _$ToolEventEnvelopeDtoCopyWithImpl<$Res, _$ToolEventEnvelopeDtoImpl>
    implements _$$ToolEventEnvelopeDtoImplCopyWith<$Res> {
  __$$ToolEventEnvelopeDtoImplCopyWithImpl(
    _$ToolEventEnvelopeDtoImpl _value,
    $Res Function(_$ToolEventEnvelopeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? tool = null,
  }) {
    return _then(
      _$ToolEventEnvelopeDtoImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: freezed == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String?,
        seq: null == seq
            ? _value.seq
            : seq // ignore: cast_nullable_to_non_nullable
                  as int,
        at: freezed == at
            ? _value.at
            : at // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        tool: null == tool
            ? _value.tool
            : tool // ignore: cast_nullable_to_non_nullable
                  as ToolWireDto,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolEventEnvelopeDtoImpl implements _ToolEventEnvelopeDto {
  const _$ToolEventEnvelopeDtoImpl({
    required this.type,
    @JsonKey(name: 'sessionId') this.sessionId,
    this.seq = 0,
    this.at,
    required this.tool,
  });

  factory _$ToolEventEnvelopeDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolEventEnvelopeDtoImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'sessionId')
  final String? sessionId;
  @override
  @JsonKey()
  final int seq;
  @override
  final DateTime? at;
  @override
  final ToolWireDto tool;

  @override
  String toString() {
    return 'ToolEventEnvelopeDto(type: $type, sessionId: $sessionId, seq: $seq, at: $at, tool: $tool)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolEventEnvelopeDtoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.tool, tool) || other.tool == tool));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, sessionId, seq, at, tool);

  /// Create a copy of ToolEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolEventEnvelopeDtoImplCopyWith<_$ToolEventEnvelopeDtoImpl>
  get copyWith =>
      __$$ToolEventEnvelopeDtoImplCopyWithImpl<_$ToolEventEnvelopeDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolEventEnvelopeDtoImplToJson(this);
  }
}

abstract class _ToolEventEnvelopeDto implements ToolEventEnvelopeDto {
  const factory _ToolEventEnvelopeDto({
    required final String type,
    @JsonKey(name: 'sessionId') final String? sessionId,
    final int seq,
    final DateTime? at,
    required final ToolWireDto tool,
  }) = _$ToolEventEnvelopeDtoImpl;

  factory _ToolEventEnvelopeDto.fromJson(Map<String, dynamic> json) =
      _$ToolEventEnvelopeDtoImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'sessionId')
  String? get sessionId;
  @override
  int get seq;
  @override
  DateTime? get at;
  @override
  ToolWireDto get tool;

  /// Create a copy of ToolEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolEventEnvelopeDtoImplCopyWith<_$ToolEventEnvelopeDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ToolWireDto _$ToolWireDtoFromJson(Map<String, dynamic> json) {
  return _ToolWireDto.fromJson(json);
}

/// @nodoc
mixin _$ToolWireDto {
  ToolAppDto get app => throw _privateConstructorUsedError;
  AcpToolCallUpdateDto? get acp => throw _privateConstructorUsedError;

  /// Serializes this ToolWireDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolWireDtoCopyWith<ToolWireDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolWireDtoCopyWith<$Res> {
  factory $ToolWireDtoCopyWith(
    ToolWireDto value,
    $Res Function(ToolWireDto) then,
  ) = _$ToolWireDtoCopyWithImpl<$Res, ToolWireDto>;
  @useResult
  $Res call({ToolAppDto app, AcpToolCallUpdateDto? acp});

  $ToolAppDtoCopyWith<$Res> get app;
  $AcpToolCallUpdateDtoCopyWith<$Res>? get acp;
}

/// @nodoc
class _$ToolWireDtoCopyWithImpl<$Res, $Val extends ToolWireDto>
    implements $ToolWireDtoCopyWith<$Res> {
  _$ToolWireDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _value.copyWith(
            app: null == app
                ? _value.app
                : app // ignore: cast_nullable_to_non_nullable
                      as ToolAppDto,
            acp: freezed == acp
                ? _value.acp
                : acp // ignore: cast_nullable_to_non_nullable
                      as AcpToolCallUpdateDto?,
          )
          as $Val,
    );
  }

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ToolAppDtoCopyWith<$Res> get app {
    return $ToolAppDtoCopyWith<$Res>(_value.app, (value) {
      return _then(_value.copyWith(app: value) as $Val);
    });
  }

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AcpToolCallUpdateDtoCopyWith<$Res>? get acp {
    if (_value.acp == null) {
      return null;
    }

    return $AcpToolCallUpdateDtoCopyWith<$Res>(_value.acp!, (value) {
      return _then(_value.copyWith(acp: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ToolWireDtoImplCopyWith<$Res>
    implements $ToolWireDtoCopyWith<$Res> {
  factory _$$ToolWireDtoImplCopyWith(
    _$ToolWireDtoImpl value,
    $Res Function(_$ToolWireDtoImpl) then,
  ) = __$$ToolWireDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ToolAppDto app, AcpToolCallUpdateDto? acp});

  @override
  $ToolAppDtoCopyWith<$Res> get app;
  @override
  $AcpToolCallUpdateDtoCopyWith<$Res>? get acp;
}

/// @nodoc
class __$$ToolWireDtoImplCopyWithImpl<$Res>
    extends _$ToolWireDtoCopyWithImpl<$Res, _$ToolWireDtoImpl>
    implements _$$ToolWireDtoImplCopyWith<$Res> {
  __$$ToolWireDtoImplCopyWithImpl(
    _$ToolWireDtoImpl _value,
    $Res Function(_$ToolWireDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _$ToolWireDtoImpl(
        app: null == app
            ? _value.app
            : app // ignore: cast_nullable_to_non_nullable
                  as ToolAppDto,
        acp: freezed == acp
            ? _value.acp
            : acp // ignore: cast_nullable_to_non_nullable
                  as AcpToolCallUpdateDto?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolWireDtoImpl implements _ToolWireDto {
  const _$ToolWireDtoImpl({required this.app, this.acp});

  factory _$ToolWireDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolWireDtoImplFromJson(json);

  @override
  final ToolAppDto app;
  @override
  final AcpToolCallUpdateDto? acp;

  @override
  String toString() {
    return 'ToolWireDto(app: $app, acp: $acp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolWireDtoImpl &&
            (identical(other.app, app) || other.app == app) &&
            (identical(other.acp, acp) || other.acp == acp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, app, acp);

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolWireDtoImplCopyWith<_$ToolWireDtoImpl> get copyWith =>
      __$$ToolWireDtoImplCopyWithImpl<_$ToolWireDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolWireDtoImplToJson(this);
  }
}

abstract class _ToolWireDto implements ToolWireDto {
  const factory _ToolWireDto({
    required final ToolAppDto app,
    final AcpToolCallUpdateDto? acp,
  }) = _$ToolWireDtoImpl;

  factory _ToolWireDto.fromJson(Map<String, dynamic> json) =
      _$ToolWireDtoImpl.fromJson;

  @override
  ToolAppDto get app;
  @override
  AcpToolCallUpdateDto? get acp;

  /// Create a copy of ToolWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolWireDtoImplCopyWith<_$ToolWireDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolAppDto _$ToolAppDtoFromJson(Map<String, dynamic> json) {
  return _ToolAppDto.fromJson(json);
}

/// @nodoc
mixin _$ToolAppDto {
  @JsonKey(name: 'partId')
  String get partId => throw _privateConstructorUsedError;
  @JsonKey(name: 'messageId')
  String get messageId => throw _privateConstructorUsedError;
  @JsonKey(name: 'callId')
  String get callId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get kind => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  ToolInputDto? get input => throw _privateConstructorUsedError;
  String? get output => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  List<ToolDiffDto> get diffs => throw _privateConstructorUsedError;
  @JsonKey(name: 'claudeCode')
  ClaudeCodeToolDto? get claudeCode => throw _privateConstructorUsedError;
  List<ToolLocationDto> get locations => throw _privateConstructorUsedError;

  /// Serializes this ToolAppDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolAppDtoCopyWith<ToolAppDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolAppDtoCopyWith<$Res> {
  factory $ToolAppDtoCopyWith(
    ToolAppDto value,
    $Res Function(ToolAppDto) then,
  ) = _$ToolAppDtoCopyWithImpl<$Res, ToolAppDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'partId') String partId,
    @JsonKey(name: 'messageId') String messageId,
    @JsonKey(name: 'callId') String callId,
    String name,
    String? kind,
    String? title,
    String status,
    ToolInputDto? input,
    String? output,
    String? error,
    List<ToolDiffDto> diffs,
    @JsonKey(name: 'claudeCode') ClaudeCodeToolDto? claudeCode,
    List<ToolLocationDto> locations,
  });

  $ToolInputDtoCopyWith<$Res>? get input;
  $ClaudeCodeToolDtoCopyWith<$Res>? get claudeCode;
}

/// @nodoc
class _$ToolAppDtoCopyWithImpl<$Res, $Val extends ToolAppDto>
    implements $ToolAppDtoCopyWith<$Res> {
  _$ToolAppDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? partId = null,
    Object? messageId = null,
    Object? callId = null,
    Object? name = null,
    Object? kind = freezed,
    Object? title = freezed,
    Object? status = null,
    Object? input = freezed,
    Object? output = freezed,
    Object? error = freezed,
    Object? diffs = null,
    Object? claudeCode = freezed,
    Object? locations = null,
  }) {
    return _then(
      _value.copyWith(
            partId: null == partId
                ? _value.partId
                : partId // ignore: cast_nullable_to_non_nullable
                      as String,
            messageId: null == messageId
                ? _value.messageId
                : messageId // ignore: cast_nullable_to_non_nullable
                      as String,
            callId: null == callId
                ? _value.callId
                : callId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            kind: freezed == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            input: freezed == input
                ? _value.input
                : input // ignore: cast_nullable_to_non_nullable
                      as ToolInputDto?,
            output: freezed == output
                ? _value.output
                : output // ignore: cast_nullable_to_non_nullable
                      as String?,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            diffs: null == diffs
                ? _value.diffs
                : diffs // ignore: cast_nullable_to_non_nullable
                      as List<ToolDiffDto>,
            claudeCode: freezed == claudeCode
                ? _value.claudeCode
                : claudeCode // ignore: cast_nullable_to_non_nullable
                      as ClaudeCodeToolDto?,
            locations: null == locations
                ? _value.locations
                : locations // ignore: cast_nullable_to_non_nullable
                      as List<ToolLocationDto>,
          )
          as $Val,
    );
  }

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ToolInputDtoCopyWith<$Res>? get input {
    if (_value.input == null) {
      return null;
    }

    return $ToolInputDtoCopyWith<$Res>(_value.input!, (value) {
      return _then(_value.copyWith(input: value) as $Val);
    });
  }

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ClaudeCodeToolDtoCopyWith<$Res>? get claudeCode {
    if (_value.claudeCode == null) {
      return null;
    }

    return $ClaudeCodeToolDtoCopyWith<$Res>(_value.claudeCode!, (value) {
      return _then(_value.copyWith(claudeCode: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ToolAppDtoImplCopyWith<$Res>
    implements $ToolAppDtoCopyWith<$Res> {
  factory _$$ToolAppDtoImplCopyWith(
    _$ToolAppDtoImpl value,
    $Res Function(_$ToolAppDtoImpl) then,
  ) = __$$ToolAppDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'partId') String partId,
    @JsonKey(name: 'messageId') String messageId,
    @JsonKey(name: 'callId') String callId,
    String name,
    String? kind,
    String? title,
    String status,
    ToolInputDto? input,
    String? output,
    String? error,
    List<ToolDiffDto> diffs,
    @JsonKey(name: 'claudeCode') ClaudeCodeToolDto? claudeCode,
    List<ToolLocationDto> locations,
  });

  @override
  $ToolInputDtoCopyWith<$Res>? get input;
  @override
  $ClaudeCodeToolDtoCopyWith<$Res>? get claudeCode;
}

/// @nodoc
class __$$ToolAppDtoImplCopyWithImpl<$Res>
    extends _$ToolAppDtoCopyWithImpl<$Res, _$ToolAppDtoImpl>
    implements _$$ToolAppDtoImplCopyWith<$Res> {
  __$$ToolAppDtoImplCopyWithImpl(
    _$ToolAppDtoImpl _value,
    $Res Function(_$ToolAppDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? partId = null,
    Object? messageId = null,
    Object? callId = null,
    Object? name = null,
    Object? kind = freezed,
    Object? title = freezed,
    Object? status = null,
    Object? input = freezed,
    Object? output = freezed,
    Object? error = freezed,
    Object? diffs = null,
    Object? claudeCode = freezed,
    Object? locations = null,
  }) {
    return _then(
      _$ToolAppDtoImpl(
        partId: null == partId
            ? _value.partId
            : partId // ignore: cast_nullable_to_non_nullable
                  as String,
        messageId: null == messageId
            ? _value.messageId
            : messageId // ignore: cast_nullable_to_non_nullable
                  as String,
        callId: null == callId
            ? _value.callId
            : callId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: freezed == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        input: freezed == input
            ? _value.input
            : input // ignore: cast_nullable_to_non_nullable
                  as ToolInputDto?,
        output: freezed == output
            ? _value.output
            : output // ignore: cast_nullable_to_non_nullable
                  as String?,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        diffs: null == diffs
            ? _value._diffs
            : diffs // ignore: cast_nullable_to_non_nullable
                  as List<ToolDiffDto>,
        claudeCode: freezed == claudeCode
            ? _value.claudeCode
            : claudeCode // ignore: cast_nullable_to_non_nullable
                  as ClaudeCodeToolDto?,
        locations: null == locations
            ? _value._locations
            : locations // ignore: cast_nullable_to_non_nullable
                  as List<ToolLocationDto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolAppDtoImpl implements _ToolAppDto {
  const _$ToolAppDtoImpl({
    @JsonKey(name: 'partId') required this.partId,
    @JsonKey(name: 'messageId') required this.messageId,
    @JsonKey(name: 'callId') required this.callId,
    required this.name,
    this.kind,
    this.title,
    required this.status,
    this.input,
    this.output,
    this.error,
    final List<ToolDiffDto> diffs = const <ToolDiffDto>[],
    @JsonKey(name: 'claudeCode') this.claudeCode,
    final List<ToolLocationDto> locations = const <ToolLocationDto>[],
  }) : _diffs = diffs,
       _locations = locations;

  factory _$ToolAppDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolAppDtoImplFromJson(json);

  @override
  @JsonKey(name: 'partId')
  final String partId;
  @override
  @JsonKey(name: 'messageId')
  final String messageId;
  @override
  @JsonKey(name: 'callId')
  final String callId;
  @override
  final String name;
  @override
  final String? kind;
  @override
  final String? title;
  @override
  final String status;
  @override
  final ToolInputDto? input;
  @override
  final String? output;
  @override
  final String? error;
  final List<ToolDiffDto> _diffs;
  @override
  @JsonKey()
  List<ToolDiffDto> get diffs {
    if (_diffs is EqualUnmodifiableListView) return _diffs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_diffs);
  }

  @override
  @JsonKey(name: 'claudeCode')
  final ClaudeCodeToolDto? claudeCode;
  final List<ToolLocationDto> _locations;
  @override
  @JsonKey()
  List<ToolLocationDto> get locations {
    if (_locations is EqualUnmodifiableListView) return _locations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locations);
  }

  @override
  String toString() {
    return 'ToolAppDto(partId: $partId, messageId: $messageId, callId: $callId, name: $name, kind: $kind, title: $title, status: $status, input: $input, output: $output, error: $error, diffs: $diffs, claudeCode: $claudeCode, locations: $locations)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolAppDtoImpl &&
            (identical(other.partId, partId) || other.partId == partId) &&
            (identical(other.messageId, messageId) ||
                other.messageId == messageId) &&
            (identical(other.callId, callId) || other.callId == callId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.input, input) || other.input == input) &&
            (identical(other.output, output) || other.output == output) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality().equals(other._diffs, _diffs) &&
            (identical(other.claudeCode, claudeCode) ||
                other.claudeCode == claudeCode) &&
            const DeepCollectionEquality().equals(
              other._locations,
              _locations,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    partId,
    messageId,
    callId,
    name,
    kind,
    title,
    status,
    input,
    output,
    error,
    const DeepCollectionEquality().hash(_diffs),
    claudeCode,
    const DeepCollectionEquality().hash(_locations),
  );

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolAppDtoImplCopyWith<_$ToolAppDtoImpl> get copyWith =>
      __$$ToolAppDtoImplCopyWithImpl<_$ToolAppDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolAppDtoImplToJson(this);
  }
}

abstract class _ToolAppDto implements ToolAppDto {
  const factory _ToolAppDto({
    @JsonKey(name: 'partId') required final String partId,
    @JsonKey(name: 'messageId') required final String messageId,
    @JsonKey(name: 'callId') required final String callId,
    required final String name,
    final String? kind,
    final String? title,
    required final String status,
    final ToolInputDto? input,
    final String? output,
    final String? error,
    final List<ToolDiffDto> diffs,
    @JsonKey(name: 'claudeCode') final ClaudeCodeToolDto? claudeCode,
    final List<ToolLocationDto> locations,
  }) = _$ToolAppDtoImpl;

  factory _ToolAppDto.fromJson(Map<String, dynamic> json) =
      _$ToolAppDtoImpl.fromJson;

  @override
  @JsonKey(name: 'partId')
  String get partId;
  @override
  @JsonKey(name: 'messageId')
  String get messageId;
  @override
  @JsonKey(name: 'callId')
  String get callId;
  @override
  String get name;
  @override
  String? get kind;
  @override
  String? get title;
  @override
  String get status;
  @override
  ToolInputDto? get input;
  @override
  String? get output;
  @override
  String? get error;
  @override
  List<ToolDiffDto> get diffs;
  @override
  @JsonKey(name: 'claudeCode')
  ClaudeCodeToolDto? get claudeCode;
  @override
  List<ToolLocationDto> get locations;

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolAppDtoImplCopyWith<_$ToolAppDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolInputDto _$ToolInputDtoFromJson(Map<String, dynamic> json) {
  return _ToolInputDto.fromJson(json);
}

/// @nodoc
mixin _$ToolInputDto {
  String? get description => throw _privateConstructorUsedError;
  ToolCommandDto? get command => throw _privateConstructorUsedError;
  @JsonKey(name: 'filePath')
  String? get filePath => throw _privateConstructorUsedError;
  @JsonKey(name: 'sourcePath')
  String? get sourcePath => throw _privateConstructorUsedError;
  @JsonKey(name: 'targetPath')
  String? get targetPath => throw _privateConstructorUsedError;
  String? get pattern => throw _privateConstructorUsedError;
  String? get url => throw _privateConstructorUsedError;
  String? get mode => throw _privateConstructorUsedError;
  ToolEditInputDto? get edit => throw _privateConstructorUsedError;
  @JsonKey(name: 'rawInputJson')
  String? get rawInputJson => throw _privateConstructorUsedError;

  /// Serializes this ToolInputDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolInputDtoCopyWith<ToolInputDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolInputDtoCopyWith<$Res> {
  factory $ToolInputDtoCopyWith(
    ToolInputDto value,
    $Res Function(ToolInputDto) then,
  ) = _$ToolInputDtoCopyWithImpl<$Res, ToolInputDto>;
  @useResult
  $Res call({
    String? description,
    ToolCommandDto? command,
    @JsonKey(name: 'filePath') String? filePath,
    @JsonKey(name: 'sourcePath') String? sourcePath,
    @JsonKey(name: 'targetPath') String? targetPath,
    String? pattern,
    String? url,
    String? mode,
    ToolEditInputDto? edit,
    @JsonKey(name: 'rawInputJson') String? rawInputJson,
  });

  $ToolCommandDtoCopyWith<$Res>? get command;
  $ToolEditInputDtoCopyWith<$Res>? get edit;
}

/// @nodoc
class _$ToolInputDtoCopyWithImpl<$Res, $Val extends ToolInputDto>
    implements $ToolInputDtoCopyWith<$Res> {
  _$ToolInputDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? description = freezed,
    Object? command = freezed,
    Object? filePath = freezed,
    Object? sourcePath = freezed,
    Object? targetPath = freezed,
    Object? pattern = freezed,
    Object? url = freezed,
    Object? mode = freezed,
    Object? edit = freezed,
    Object? rawInputJson = freezed,
  }) {
    return _then(
      _value.copyWith(
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            command: freezed == command
                ? _value.command
                : command // ignore: cast_nullable_to_non_nullable
                      as ToolCommandDto?,
            filePath: freezed == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            sourcePath: freezed == sourcePath
                ? _value.sourcePath
                : sourcePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            targetPath: freezed == targetPath
                ? _value.targetPath
                : targetPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            pattern: freezed == pattern
                ? _value.pattern
                : pattern // ignore: cast_nullable_to_non_nullable
                      as String?,
            url: freezed == url
                ? _value.url
                : url // ignore: cast_nullable_to_non_nullable
                      as String?,
            mode: freezed == mode
                ? _value.mode
                : mode // ignore: cast_nullable_to_non_nullable
                      as String?,
            edit: freezed == edit
                ? _value.edit
                : edit // ignore: cast_nullable_to_non_nullable
                      as ToolEditInputDto?,
            rawInputJson: freezed == rawInputJson
                ? _value.rawInputJson
                : rawInputJson // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ToolCommandDtoCopyWith<$Res>? get command {
    if (_value.command == null) {
      return null;
    }

    return $ToolCommandDtoCopyWith<$Res>(_value.command!, (value) {
      return _then(_value.copyWith(command: value) as $Val);
    });
  }

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ToolEditInputDtoCopyWith<$Res>? get edit {
    if (_value.edit == null) {
      return null;
    }

    return $ToolEditInputDtoCopyWith<$Res>(_value.edit!, (value) {
      return _then(_value.copyWith(edit: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ToolInputDtoImplCopyWith<$Res>
    implements $ToolInputDtoCopyWith<$Res> {
  factory _$$ToolInputDtoImplCopyWith(
    _$ToolInputDtoImpl value,
    $Res Function(_$ToolInputDtoImpl) then,
  ) = __$$ToolInputDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? description,
    ToolCommandDto? command,
    @JsonKey(name: 'filePath') String? filePath,
    @JsonKey(name: 'sourcePath') String? sourcePath,
    @JsonKey(name: 'targetPath') String? targetPath,
    String? pattern,
    String? url,
    String? mode,
    ToolEditInputDto? edit,
    @JsonKey(name: 'rawInputJson') String? rawInputJson,
  });

  @override
  $ToolCommandDtoCopyWith<$Res>? get command;
  @override
  $ToolEditInputDtoCopyWith<$Res>? get edit;
}

/// @nodoc
class __$$ToolInputDtoImplCopyWithImpl<$Res>
    extends _$ToolInputDtoCopyWithImpl<$Res, _$ToolInputDtoImpl>
    implements _$$ToolInputDtoImplCopyWith<$Res> {
  __$$ToolInputDtoImplCopyWithImpl(
    _$ToolInputDtoImpl _value,
    $Res Function(_$ToolInputDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? description = freezed,
    Object? command = freezed,
    Object? filePath = freezed,
    Object? sourcePath = freezed,
    Object? targetPath = freezed,
    Object? pattern = freezed,
    Object? url = freezed,
    Object? mode = freezed,
    Object? edit = freezed,
    Object? rawInputJson = freezed,
  }) {
    return _then(
      _$ToolInputDtoImpl(
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        command: freezed == command
            ? _value.command
            : command // ignore: cast_nullable_to_non_nullable
                  as ToolCommandDto?,
        filePath: freezed == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourcePath: freezed == sourcePath
            ? _value.sourcePath
            : sourcePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        targetPath: freezed == targetPath
            ? _value.targetPath
            : targetPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        pattern: freezed == pattern
            ? _value.pattern
            : pattern // ignore: cast_nullable_to_non_nullable
                  as String?,
        url: freezed == url
            ? _value.url
            : url // ignore: cast_nullable_to_non_nullable
                  as String?,
        mode: freezed == mode
            ? _value.mode
            : mode // ignore: cast_nullable_to_non_nullable
                  as String?,
        edit: freezed == edit
            ? _value.edit
            : edit // ignore: cast_nullable_to_non_nullable
                  as ToolEditInputDto?,
        rawInputJson: freezed == rawInputJson
            ? _value.rawInputJson
            : rawInputJson // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolInputDtoImpl implements _ToolInputDto {
  const _$ToolInputDtoImpl({
    this.description,
    this.command,
    @JsonKey(name: 'filePath') this.filePath,
    @JsonKey(name: 'sourcePath') this.sourcePath,
    @JsonKey(name: 'targetPath') this.targetPath,
    this.pattern,
    this.url,
    this.mode,
    this.edit,
    @JsonKey(name: 'rawInputJson') this.rawInputJson,
  });

  factory _$ToolInputDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolInputDtoImplFromJson(json);

  @override
  final String? description;
  @override
  final ToolCommandDto? command;
  @override
  @JsonKey(name: 'filePath')
  final String? filePath;
  @override
  @JsonKey(name: 'sourcePath')
  final String? sourcePath;
  @override
  @JsonKey(name: 'targetPath')
  final String? targetPath;
  @override
  final String? pattern;
  @override
  final String? url;
  @override
  final String? mode;
  @override
  final ToolEditInputDto? edit;
  @override
  @JsonKey(name: 'rawInputJson')
  final String? rawInputJson;

  @override
  String toString() {
    return 'ToolInputDto(description: $description, command: $command, filePath: $filePath, sourcePath: $sourcePath, targetPath: $targetPath, pattern: $pattern, url: $url, mode: $mode, edit: $edit, rawInputJson: $rawInputJson)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolInputDtoImpl &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.command, command) || other.command == command) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.sourcePath, sourcePath) ||
                other.sourcePath == sourcePath) &&
            (identical(other.targetPath, targetPath) ||
                other.targetPath == targetPath) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.edit, edit) || other.edit == edit) &&
            (identical(other.rawInputJson, rawInputJson) ||
                other.rawInputJson == rawInputJson));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    description,
    command,
    filePath,
    sourcePath,
    targetPath,
    pattern,
    url,
    mode,
    edit,
    rawInputJson,
  );

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolInputDtoImplCopyWith<_$ToolInputDtoImpl> get copyWith =>
      __$$ToolInputDtoImplCopyWithImpl<_$ToolInputDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolInputDtoImplToJson(this);
  }
}

abstract class _ToolInputDto implements ToolInputDto {
  const factory _ToolInputDto({
    final String? description,
    final ToolCommandDto? command,
    @JsonKey(name: 'filePath') final String? filePath,
    @JsonKey(name: 'sourcePath') final String? sourcePath,
    @JsonKey(name: 'targetPath') final String? targetPath,
    final String? pattern,
    final String? url,
    final String? mode,
    final ToolEditInputDto? edit,
    @JsonKey(name: 'rawInputJson') final String? rawInputJson,
  }) = _$ToolInputDtoImpl;

  factory _ToolInputDto.fromJson(Map<String, dynamic> json) =
      _$ToolInputDtoImpl.fromJson;

  @override
  String? get description;
  @override
  ToolCommandDto? get command;
  @override
  @JsonKey(name: 'filePath')
  String? get filePath;
  @override
  @JsonKey(name: 'sourcePath')
  String? get sourcePath;
  @override
  @JsonKey(name: 'targetPath')
  String? get targetPath;
  @override
  String? get pattern;
  @override
  String? get url;
  @override
  String? get mode;
  @override
  ToolEditInputDto? get edit;
  @override
  @JsonKey(name: 'rawInputJson')
  String? get rawInputJson;

  /// Create a copy of ToolInputDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolInputDtoImplCopyWith<_$ToolInputDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolCommandDto _$ToolCommandDtoFromJson(Map<String, dynamic> json) {
  return _ToolCommandDto.fromJson(json);
}

/// @nodoc
mixin _$ToolCommandDto {
  List<String> get argv => throw _privateConstructorUsedError;
  String? get display => throw _privateConstructorUsedError;

  /// Serializes this ToolCommandDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolCommandDtoCopyWith<ToolCommandDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolCommandDtoCopyWith<$Res> {
  factory $ToolCommandDtoCopyWith(
    ToolCommandDto value,
    $Res Function(ToolCommandDto) then,
  ) = _$ToolCommandDtoCopyWithImpl<$Res, ToolCommandDto>;
  @useResult
  $Res call({List<String> argv, String? display});
}

/// @nodoc
class _$ToolCommandDtoCopyWithImpl<$Res, $Val extends ToolCommandDto>
    implements $ToolCommandDtoCopyWith<$Res> {
  _$ToolCommandDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? argv = null, Object? display = freezed}) {
    return _then(
      _value.copyWith(
            argv: null == argv
                ? _value.argv
                : argv // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            display: freezed == display
                ? _value.display
                : display // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ToolCommandDtoImplCopyWith<$Res>
    implements $ToolCommandDtoCopyWith<$Res> {
  factory _$$ToolCommandDtoImplCopyWith(
    _$ToolCommandDtoImpl value,
    $Res Function(_$ToolCommandDtoImpl) then,
  ) = __$$ToolCommandDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> argv, String? display});
}

/// @nodoc
class __$$ToolCommandDtoImplCopyWithImpl<$Res>
    extends _$ToolCommandDtoCopyWithImpl<$Res, _$ToolCommandDtoImpl>
    implements _$$ToolCommandDtoImplCopyWith<$Res> {
  __$$ToolCommandDtoImplCopyWithImpl(
    _$ToolCommandDtoImpl _value,
    $Res Function(_$ToolCommandDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? argv = null, Object? display = freezed}) {
    return _then(
      _$ToolCommandDtoImpl(
        argv: null == argv
            ? _value._argv
            : argv // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        display: freezed == display
            ? _value.display
            : display // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolCommandDtoImpl implements _ToolCommandDto {
  const _$ToolCommandDtoImpl({
    final List<String> argv = const <String>[],
    this.display,
  }) : _argv = argv;

  factory _$ToolCommandDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolCommandDtoImplFromJson(json);

  final List<String> _argv;
  @override
  @JsonKey()
  List<String> get argv {
    if (_argv is EqualUnmodifiableListView) return _argv;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_argv);
  }

  @override
  final String? display;

  @override
  String toString() {
    return 'ToolCommandDto(argv: $argv, display: $display)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolCommandDtoImpl &&
            const DeepCollectionEquality().equals(other._argv, _argv) &&
            (identical(other.display, display) || other.display == display));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_argv),
    display,
  );

  /// Create a copy of ToolCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolCommandDtoImplCopyWith<_$ToolCommandDtoImpl> get copyWith =>
      __$$ToolCommandDtoImplCopyWithImpl<_$ToolCommandDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolCommandDtoImplToJson(this);
  }
}

abstract class _ToolCommandDto implements ToolCommandDto {
  const factory _ToolCommandDto({
    final List<String> argv,
    final String? display,
  }) = _$ToolCommandDtoImpl;

  factory _ToolCommandDto.fromJson(Map<String, dynamic> json) =
      _$ToolCommandDtoImpl.fromJson;

  @override
  List<String> get argv;
  @override
  String? get display;

  /// Create a copy of ToolCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolCommandDtoImplCopyWith<_$ToolCommandDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolEditInputDto _$ToolEditInputDtoFromJson(Map<String, dynamic> json) {
  return _ToolEditInputDto.fromJson(json);
}

/// @nodoc
mixin _$ToolEditInputDto {
  @JsonKey(name: 'filePath')
  String? get filePath => throw _privateConstructorUsedError;
  @JsonKey(name: 'oldString')
  String? get oldString => throw _privateConstructorUsedError;
  @JsonKey(name: 'newString')
  String? get newString => throw _privateConstructorUsedError;

  /// Serializes this ToolEditInputDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolEditInputDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolEditInputDtoCopyWith<ToolEditInputDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolEditInputDtoCopyWith<$Res> {
  factory $ToolEditInputDtoCopyWith(
    ToolEditInputDto value,
    $Res Function(ToolEditInputDto) then,
  ) = _$ToolEditInputDtoCopyWithImpl<$Res, ToolEditInputDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'filePath') String? filePath,
    @JsonKey(name: 'oldString') String? oldString,
    @JsonKey(name: 'newString') String? newString,
  });
}

/// @nodoc
class _$ToolEditInputDtoCopyWithImpl<$Res, $Val extends ToolEditInputDto>
    implements $ToolEditInputDtoCopyWith<$Res> {
  _$ToolEditInputDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolEditInputDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filePath = freezed,
    Object? oldString = freezed,
    Object? newString = freezed,
  }) {
    return _then(
      _value.copyWith(
            filePath: freezed == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            oldString: freezed == oldString
                ? _value.oldString
                : oldString // ignore: cast_nullable_to_non_nullable
                      as String?,
            newString: freezed == newString
                ? _value.newString
                : newString // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ToolEditInputDtoImplCopyWith<$Res>
    implements $ToolEditInputDtoCopyWith<$Res> {
  factory _$$ToolEditInputDtoImplCopyWith(
    _$ToolEditInputDtoImpl value,
    $Res Function(_$ToolEditInputDtoImpl) then,
  ) = __$$ToolEditInputDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'filePath') String? filePath,
    @JsonKey(name: 'oldString') String? oldString,
    @JsonKey(name: 'newString') String? newString,
  });
}

/// @nodoc
class __$$ToolEditInputDtoImplCopyWithImpl<$Res>
    extends _$ToolEditInputDtoCopyWithImpl<$Res, _$ToolEditInputDtoImpl>
    implements _$$ToolEditInputDtoImplCopyWith<$Res> {
  __$$ToolEditInputDtoImplCopyWithImpl(
    _$ToolEditInputDtoImpl _value,
    $Res Function(_$ToolEditInputDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolEditInputDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? filePath = freezed,
    Object? oldString = freezed,
    Object? newString = freezed,
  }) {
    return _then(
      _$ToolEditInputDtoImpl(
        filePath: freezed == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        oldString: freezed == oldString
            ? _value.oldString
            : oldString // ignore: cast_nullable_to_non_nullable
                  as String?,
        newString: freezed == newString
            ? _value.newString
            : newString // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolEditInputDtoImpl implements _ToolEditInputDto {
  const _$ToolEditInputDtoImpl({
    @JsonKey(name: 'filePath') this.filePath,
    @JsonKey(name: 'oldString') this.oldString,
    @JsonKey(name: 'newString') this.newString,
  });

  factory _$ToolEditInputDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolEditInputDtoImplFromJson(json);

  @override
  @JsonKey(name: 'filePath')
  final String? filePath;
  @override
  @JsonKey(name: 'oldString')
  final String? oldString;
  @override
  @JsonKey(name: 'newString')
  final String? newString;

  @override
  String toString() {
    return 'ToolEditInputDto(filePath: $filePath, oldString: $oldString, newString: $newString)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolEditInputDtoImpl &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.oldString, oldString) ||
                other.oldString == oldString) &&
            (identical(other.newString, newString) ||
                other.newString == newString));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, filePath, oldString, newString);

  /// Create a copy of ToolEditInputDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolEditInputDtoImplCopyWith<_$ToolEditInputDtoImpl> get copyWith =>
      __$$ToolEditInputDtoImplCopyWithImpl<_$ToolEditInputDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolEditInputDtoImplToJson(this);
  }
}

abstract class _ToolEditInputDto implements ToolEditInputDto {
  const factory _ToolEditInputDto({
    @JsonKey(name: 'filePath') final String? filePath,
    @JsonKey(name: 'oldString') final String? oldString,
    @JsonKey(name: 'newString') final String? newString,
  }) = _$ToolEditInputDtoImpl;

  factory _ToolEditInputDto.fromJson(Map<String, dynamic> json) =
      _$ToolEditInputDtoImpl.fromJson;

  @override
  @JsonKey(name: 'filePath')
  String? get filePath;
  @override
  @JsonKey(name: 'oldString')
  String? get oldString;
  @override
  @JsonKey(name: 'newString')
  String? get newString;

  /// Create a copy of ToolEditInputDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolEditInputDtoImplCopyWith<_$ToolEditInputDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ClaudeCodeToolDto _$ClaudeCodeToolDtoFromJson(Map<String, dynamic> json) {
  return _ClaudeCodeToolDto.fromJson(json);
}

/// @nodoc
mixin _$ClaudeCodeToolDto {
  @JsonKey(name: 'parentToolUseId')
  String? get parentToolUseId => throw _privateConstructorUsedError;
  @JsonKey(name: 'toolName')
  String? get toolName => throw _privateConstructorUsedError;

  /// Serializes this ClaudeCodeToolDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ClaudeCodeToolDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClaudeCodeToolDtoCopyWith<ClaudeCodeToolDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClaudeCodeToolDtoCopyWith<$Res> {
  factory $ClaudeCodeToolDtoCopyWith(
    ClaudeCodeToolDto value,
    $Res Function(ClaudeCodeToolDto) then,
  ) = _$ClaudeCodeToolDtoCopyWithImpl<$Res, ClaudeCodeToolDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'parentToolUseId') String? parentToolUseId,
    @JsonKey(name: 'toolName') String? toolName,
  });
}

/// @nodoc
class _$ClaudeCodeToolDtoCopyWithImpl<$Res, $Val extends ClaudeCodeToolDto>
    implements $ClaudeCodeToolDtoCopyWith<$Res> {
  _$ClaudeCodeToolDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClaudeCodeToolDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? parentToolUseId = freezed, Object? toolName = freezed}) {
    return _then(
      _value.copyWith(
            parentToolUseId: freezed == parentToolUseId
                ? _value.parentToolUseId
                : parentToolUseId // ignore: cast_nullable_to_non_nullable
                      as String?,
            toolName: freezed == toolName
                ? _value.toolName
                : toolName // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ClaudeCodeToolDtoImplCopyWith<$Res>
    implements $ClaudeCodeToolDtoCopyWith<$Res> {
  factory _$$ClaudeCodeToolDtoImplCopyWith(
    _$ClaudeCodeToolDtoImpl value,
    $Res Function(_$ClaudeCodeToolDtoImpl) then,
  ) = __$$ClaudeCodeToolDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'parentToolUseId') String? parentToolUseId,
    @JsonKey(name: 'toolName') String? toolName,
  });
}

/// @nodoc
class __$$ClaudeCodeToolDtoImplCopyWithImpl<$Res>
    extends _$ClaudeCodeToolDtoCopyWithImpl<$Res, _$ClaudeCodeToolDtoImpl>
    implements _$$ClaudeCodeToolDtoImplCopyWith<$Res> {
  __$$ClaudeCodeToolDtoImplCopyWithImpl(
    _$ClaudeCodeToolDtoImpl _value,
    $Res Function(_$ClaudeCodeToolDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ClaudeCodeToolDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? parentToolUseId = freezed, Object? toolName = freezed}) {
    return _then(
      _$ClaudeCodeToolDtoImpl(
        parentToolUseId: freezed == parentToolUseId
            ? _value.parentToolUseId
            : parentToolUseId // ignore: cast_nullable_to_non_nullable
                  as String?,
        toolName: freezed == toolName
            ? _value.toolName
            : toolName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ClaudeCodeToolDtoImpl implements _ClaudeCodeToolDto {
  const _$ClaudeCodeToolDtoImpl({
    @JsonKey(name: 'parentToolUseId') this.parentToolUseId,
    @JsonKey(name: 'toolName') this.toolName,
  });

  factory _$ClaudeCodeToolDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClaudeCodeToolDtoImplFromJson(json);

  @override
  @JsonKey(name: 'parentToolUseId')
  final String? parentToolUseId;
  @override
  @JsonKey(name: 'toolName')
  final String? toolName;

  @override
  String toString() {
    return 'ClaudeCodeToolDto(parentToolUseId: $parentToolUseId, toolName: $toolName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClaudeCodeToolDtoImpl &&
            (identical(other.parentToolUseId, parentToolUseId) ||
                other.parentToolUseId == parentToolUseId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, parentToolUseId, toolName);

  /// Create a copy of ClaudeCodeToolDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClaudeCodeToolDtoImplCopyWith<_$ClaudeCodeToolDtoImpl> get copyWith =>
      __$$ClaudeCodeToolDtoImplCopyWithImpl<_$ClaudeCodeToolDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ClaudeCodeToolDtoImplToJson(this);
  }
}

abstract class _ClaudeCodeToolDto implements ClaudeCodeToolDto {
  const factory _ClaudeCodeToolDto({
    @JsonKey(name: 'parentToolUseId') final String? parentToolUseId,
    @JsonKey(name: 'toolName') final String? toolName,
  }) = _$ClaudeCodeToolDtoImpl;

  factory _ClaudeCodeToolDto.fromJson(Map<String, dynamic> json) =
      _$ClaudeCodeToolDtoImpl.fromJson;

  @override
  @JsonKey(name: 'parentToolUseId')
  String? get parentToolUseId;
  @override
  @JsonKey(name: 'toolName')
  String? get toolName;

  /// Create a copy of ClaudeCodeToolDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClaudeCodeToolDtoImplCopyWith<_$ClaudeCodeToolDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolDiffDto _$ToolDiffDtoFromJson(Map<String, dynamic> json) {
  return _ToolDiffDto.fromJson(json);
}

/// @nodoc
mixin _$ToolDiffDto {
  String get path => throw _privateConstructorUsedError;
  @JsonKey(name: 'oldText')
  String? get oldText => throw _privateConstructorUsedError;
  @JsonKey(name: 'newText')
  String get newText => throw _privateConstructorUsedError;

  /// Serializes this ToolDiffDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolDiffDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolDiffDtoCopyWith<ToolDiffDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolDiffDtoCopyWith<$Res> {
  factory $ToolDiffDtoCopyWith(
    ToolDiffDto value,
    $Res Function(ToolDiffDto) then,
  ) = _$ToolDiffDtoCopyWithImpl<$Res, ToolDiffDto>;
  @useResult
  $Res call({
    String path,
    @JsonKey(name: 'oldText') String? oldText,
    @JsonKey(name: 'newText') String newText,
  });
}

/// @nodoc
class _$ToolDiffDtoCopyWithImpl<$Res, $Val extends ToolDiffDto>
    implements $ToolDiffDtoCopyWith<$Res> {
  _$ToolDiffDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolDiffDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? oldText = freezed,
    Object? newText = null,
  }) {
    return _then(
      _value.copyWith(
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            oldText: freezed == oldText
                ? _value.oldText
                : oldText // ignore: cast_nullable_to_non_nullable
                      as String?,
            newText: null == newText
                ? _value.newText
                : newText // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ToolDiffDtoImplCopyWith<$Res>
    implements $ToolDiffDtoCopyWith<$Res> {
  factory _$$ToolDiffDtoImplCopyWith(
    _$ToolDiffDtoImpl value,
    $Res Function(_$ToolDiffDtoImpl) then,
  ) = __$$ToolDiffDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String path,
    @JsonKey(name: 'oldText') String? oldText,
    @JsonKey(name: 'newText') String newText,
  });
}

/// @nodoc
class __$$ToolDiffDtoImplCopyWithImpl<$Res>
    extends _$ToolDiffDtoCopyWithImpl<$Res, _$ToolDiffDtoImpl>
    implements _$$ToolDiffDtoImplCopyWith<$Res> {
  __$$ToolDiffDtoImplCopyWithImpl(
    _$ToolDiffDtoImpl _value,
    $Res Function(_$ToolDiffDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolDiffDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? oldText = freezed,
    Object? newText = null,
  }) {
    return _then(
      _$ToolDiffDtoImpl(
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        oldText: freezed == oldText
            ? _value.oldText
            : oldText // ignore: cast_nullable_to_non_nullable
                  as String?,
        newText: null == newText
            ? _value.newText
            : newText // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolDiffDtoImpl implements _ToolDiffDto {
  const _$ToolDiffDtoImpl({
    required this.path,
    @JsonKey(name: 'oldText') this.oldText,
    @JsonKey(name: 'newText') required this.newText,
  });

  factory _$ToolDiffDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolDiffDtoImplFromJson(json);

  @override
  final String path;
  @override
  @JsonKey(name: 'oldText')
  final String? oldText;
  @override
  @JsonKey(name: 'newText')
  final String newText;

  @override
  String toString() {
    return 'ToolDiffDto(path: $path, oldText: $oldText, newText: $newText)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolDiffDtoImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.oldText, oldText) || other.oldText == oldText) &&
            (identical(other.newText, newText) || other.newText == newText));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, path, oldText, newText);

  /// Create a copy of ToolDiffDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolDiffDtoImplCopyWith<_$ToolDiffDtoImpl> get copyWith =>
      __$$ToolDiffDtoImplCopyWithImpl<_$ToolDiffDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolDiffDtoImplToJson(this);
  }
}

abstract class _ToolDiffDto implements ToolDiffDto {
  const factory _ToolDiffDto({
    required final String path,
    @JsonKey(name: 'oldText') final String? oldText,
    @JsonKey(name: 'newText') required final String newText,
  }) = _$ToolDiffDtoImpl;

  factory _ToolDiffDto.fromJson(Map<String, dynamic> json) =
      _$ToolDiffDtoImpl.fromJson;

  @override
  String get path;
  @override
  @JsonKey(name: 'oldText')
  String? get oldText;
  @override
  @JsonKey(name: 'newText')
  String get newText;

  /// Create a copy of ToolDiffDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolDiffDtoImplCopyWith<_$ToolDiffDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ToolLocationDto _$ToolLocationDtoFromJson(Map<String, dynamic> json) {
  return _ToolLocationDto.fromJson(json);
}

/// @nodoc
mixin _$ToolLocationDto {
  String get path => throw _privateConstructorUsedError;
  int? get line => throw _privateConstructorUsedError;

  /// Serializes this ToolLocationDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ToolLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ToolLocationDtoCopyWith<ToolLocationDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ToolLocationDtoCopyWith<$Res> {
  factory $ToolLocationDtoCopyWith(
    ToolLocationDto value,
    $Res Function(ToolLocationDto) then,
  ) = _$ToolLocationDtoCopyWithImpl<$Res, ToolLocationDto>;
  @useResult
  $Res call({String path, int? line});
}

/// @nodoc
class _$ToolLocationDtoCopyWithImpl<$Res, $Val extends ToolLocationDto>
    implements $ToolLocationDtoCopyWith<$Res> {
  _$ToolLocationDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ToolLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? path = null, Object? line = freezed}) {
    return _then(
      _value.copyWith(
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            line: freezed == line
                ? _value.line
                : line // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ToolLocationDtoImplCopyWith<$Res>
    implements $ToolLocationDtoCopyWith<$Res> {
  factory _$$ToolLocationDtoImplCopyWith(
    _$ToolLocationDtoImpl value,
    $Res Function(_$ToolLocationDtoImpl) then,
  ) = __$$ToolLocationDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String path, int? line});
}

/// @nodoc
class __$$ToolLocationDtoImplCopyWithImpl<$Res>
    extends _$ToolLocationDtoCopyWithImpl<$Res, _$ToolLocationDtoImpl>
    implements _$$ToolLocationDtoImplCopyWith<$Res> {
  __$$ToolLocationDtoImplCopyWithImpl(
    _$ToolLocationDtoImpl _value,
    $Res Function(_$ToolLocationDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ToolLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? path = null, Object? line = freezed}) {
    return _then(
      _$ToolLocationDtoImpl(
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        line: freezed == line
            ? _value.line
            : line // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ToolLocationDtoImpl implements _ToolLocationDto {
  const _$ToolLocationDtoImpl({required this.path, this.line});

  factory _$ToolLocationDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ToolLocationDtoImplFromJson(json);

  @override
  final String path;
  @override
  final int? line;

  @override
  String toString() {
    return 'ToolLocationDto(path: $path, line: $line)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ToolLocationDtoImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.line, line) || other.line == line));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, path, line);

  /// Create a copy of ToolLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ToolLocationDtoImplCopyWith<_$ToolLocationDtoImpl> get copyWith =>
      __$$ToolLocationDtoImplCopyWithImpl<_$ToolLocationDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ToolLocationDtoImplToJson(this);
  }
}

abstract class _ToolLocationDto implements ToolLocationDto {
  const factory _ToolLocationDto({
    required final String path,
    final int? line,
  }) = _$ToolLocationDtoImpl;

  factory _ToolLocationDto.fromJson(Map<String, dynamic> json) =
      _$ToolLocationDtoImpl.fromJson;

  @override
  String get path;
  @override
  int? get line;

  /// Create a copy of ToolLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolLocationDtoImplCopyWith<_$ToolLocationDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
