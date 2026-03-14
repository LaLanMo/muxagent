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
  Map<String, dynamic>? get input => throw _privateConstructorUsedError;
  String? get output => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  List<ToolDiffDto> get diffs => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
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
    Map<String, dynamic>? input,
    String? output,
    String? error,
    List<ToolDiffDto> diffs,
    Map<String, dynamic>? metadata,
    List<ToolLocationDto> locations,
  });
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
    Object? metadata = freezed,
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
                      as Map<String, dynamic>?,
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
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            locations: null == locations
                ? _value.locations
                : locations // ignore: cast_nullable_to_non_nullable
                      as List<ToolLocationDto>,
          )
          as $Val,
    );
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
    Map<String, dynamic>? input,
    String? output,
    String? error,
    List<ToolDiffDto> diffs,
    Map<String, dynamic>? metadata,
    List<ToolLocationDto> locations,
  });
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
    Object? metadata = freezed,
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
            ? _value._input
            : input // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
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
        metadata: freezed == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
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
    final Map<String, dynamic>? input,
    this.output,
    this.error,
    final List<ToolDiffDto> diffs = const <ToolDiffDto>[],
    final Map<String, dynamic>? metadata,
    final List<ToolLocationDto> locations = const <ToolLocationDto>[],
  }) : _input = input,
       _diffs = diffs,
       _metadata = metadata,
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
  final Map<String, dynamic>? _input;
  @override
  Map<String, dynamic>? get input {
    final value = _input;
    if (value == null) return null;
    if (_input is EqualUnmodifiableMapView) return _input;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

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

  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

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
    return 'ToolAppDto(partId: $partId, messageId: $messageId, callId: $callId, name: $name, kind: $kind, title: $title, status: $status, input: $input, output: $output, error: $error, diffs: $diffs, metadata: $metadata, locations: $locations)';
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
            const DeepCollectionEquality().equals(other._input, _input) &&
            (identical(other.output, output) || other.output == output) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality().equals(other._diffs, _diffs) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
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
    const DeepCollectionEquality().hash(_input),
    output,
    error,
    const DeepCollectionEquality().hash(_diffs),
    const DeepCollectionEquality().hash(_metadata),
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
    final Map<String, dynamic>? input,
    final String? output,
    final String? error,
    final List<ToolDiffDto> diffs,
    final Map<String, dynamic>? metadata,
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
  Map<String, dynamic>? get input;
  @override
  String? get output;
  @override
  String? get error;
  @override
  List<ToolDiffDto> get diffs;
  @override
  Map<String, dynamic>? get metadata;
  @override
  List<ToolLocationDto> get locations;

  /// Create a copy of ToolAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ToolAppDtoImplCopyWith<_$ToolAppDtoImpl> get copyWith =>
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
