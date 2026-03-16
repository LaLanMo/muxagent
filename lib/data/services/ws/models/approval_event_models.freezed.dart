// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'approval_event_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ApprovalEventEnvelopeDto _$ApprovalEventEnvelopeDtoFromJson(
  Map<String, dynamic> json,
) {
  return _ApprovalEventEnvelopeDto.fromJson(json);
}

/// @nodoc
mixin _$ApprovalEventEnvelopeDto {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String? get sessionId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  DateTime? get at => throw _privateConstructorUsedError;
  ApprovalWireDto get approval => throw _privateConstructorUsedError;

  /// Serializes this ApprovalEventEnvelopeDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApprovalEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApprovalEventEnvelopeDtoCopyWith<ApprovalEventEnvelopeDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApprovalEventEnvelopeDtoCopyWith<$Res> {
  factory $ApprovalEventEnvelopeDtoCopyWith(
    ApprovalEventEnvelopeDto value,
    $Res Function(ApprovalEventEnvelopeDto) then,
  ) = _$ApprovalEventEnvelopeDtoCopyWithImpl<$Res, ApprovalEventEnvelopeDto>;
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    ApprovalWireDto approval,
  });

  $ApprovalWireDtoCopyWith<$Res> get approval;
}

/// @nodoc
class _$ApprovalEventEnvelopeDtoCopyWithImpl<
  $Res,
  $Val extends ApprovalEventEnvelopeDto
>
    implements $ApprovalEventEnvelopeDtoCopyWith<$Res> {
  _$ApprovalEventEnvelopeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApprovalEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? approval = null,
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
            approval: null == approval
                ? _value.approval
                : approval // ignore: cast_nullable_to_non_nullable
                      as ApprovalWireDto,
          )
          as $Val,
    );
  }

  /// Create a copy of ApprovalEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ApprovalWireDtoCopyWith<$Res> get approval {
    return $ApprovalWireDtoCopyWith<$Res>(_value.approval, (value) {
      return _then(_value.copyWith(approval: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ApprovalEventEnvelopeDtoImplCopyWith<$Res>
    implements $ApprovalEventEnvelopeDtoCopyWith<$Res> {
  factory _$$ApprovalEventEnvelopeDtoImplCopyWith(
    _$ApprovalEventEnvelopeDtoImpl value,
    $Res Function(_$ApprovalEventEnvelopeDtoImpl) then,
  ) = __$$ApprovalEventEnvelopeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    ApprovalWireDto approval,
  });

  @override
  $ApprovalWireDtoCopyWith<$Res> get approval;
}

/// @nodoc
class __$$ApprovalEventEnvelopeDtoImplCopyWithImpl<$Res>
    extends
        _$ApprovalEventEnvelopeDtoCopyWithImpl<
          $Res,
          _$ApprovalEventEnvelopeDtoImpl
        >
    implements _$$ApprovalEventEnvelopeDtoImplCopyWith<$Res> {
  __$$ApprovalEventEnvelopeDtoImplCopyWithImpl(
    _$ApprovalEventEnvelopeDtoImpl _value,
    $Res Function(_$ApprovalEventEnvelopeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApprovalEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? approval = null,
  }) {
    return _then(
      _$ApprovalEventEnvelopeDtoImpl(
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
        approval: null == approval
            ? _value.approval
            : approval // ignore: cast_nullable_to_non_nullable
                  as ApprovalWireDto,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApprovalEventEnvelopeDtoImpl implements _ApprovalEventEnvelopeDto {
  const _$ApprovalEventEnvelopeDtoImpl({
    required this.type,
    @JsonKey(name: 'sessionId') this.sessionId,
    this.seq = 0,
    this.at,
    required this.approval,
  });

  factory _$ApprovalEventEnvelopeDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApprovalEventEnvelopeDtoImplFromJson(json);

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
  final ApprovalWireDto approval;

  @override
  String toString() {
    return 'ApprovalEventEnvelopeDto(type: $type, sessionId: $sessionId, seq: $seq, at: $at, approval: $approval)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApprovalEventEnvelopeDtoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.approval, approval) ||
                other.approval == approval));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, sessionId, seq, at, approval);

  /// Create a copy of ApprovalEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApprovalEventEnvelopeDtoImplCopyWith<_$ApprovalEventEnvelopeDtoImpl>
  get copyWith =>
      __$$ApprovalEventEnvelopeDtoImplCopyWithImpl<
        _$ApprovalEventEnvelopeDtoImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ApprovalEventEnvelopeDtoImplToJson(this);
  }
}

abstract class _ApprovalEventEnvelopeDto implements ApprovalEventEnvelopeDto {
  const factory _ApprovalEventEnvelopeDto({
    required final String type,
    @JsonKey(name: 'sessionId') final String? sessionId,
    final int seq,
    final DateTime? at,
    required final ApprovalWireDto approval,
  }) = _$ApprovalEventEnvelopeDtoImpl;

  factory _ApprovalEventEnvelopeDto.fromJson(Map<String, dynamic> json) =
      _$ApprovalEventEnvelopeDtoImpl.fromJson;

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
  ApprovalWireDto get approval;

  /// Create a copy of ApprovalEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApprovalEventEnvelopeDtoImplCopyWith<_$ApprovalEventEnvelopeDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ApprovalWireDto _$ApprovalWireDtoFromJson(Map<String, dynamic> json) {
  return _ApprovalWireDto.fromJson(json);
}

/// @nodoc
mixin _$ApprovalWireDto {
  ApprovalAppDto get app => throw _privateConstructorUsedError;
  AcpRequestPermissionRequestDto? get acp => throw _privateConstructorUsedError;

  /// Serializes this ApprovalWireDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApprovalWireDtoCopyWith<ApprovalWireDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApprovalWireDtoCopyWith<$Res> {
  factory $ApprovalWireDtoCopyWith(
    ApprovalWireDto value,
    $Res Function(ApprovalWireDto) then,
  ) = _$ApprovalWireDtoCopyWithImpl<$Res, ApprovalWireDto>;
  @useResult
  $Res call({ApprovalAppDto app, AcpRequestPermissionRequestDto? acp});

  $ApprovalAppDtoCopyWith<$Res> get app;
  $AcpRequestPermissionRequestDtoCopyWith<$Res>? get acp;
}

/// @nodoc
class _$ApprovalWireDtoCopyWithImpl<$Res, $Val extends ApprovalWireDto>
    implements $ApprovalWireDtoCopyWith<$Res> {
  _$ApprovalWireDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _value.copyWith(
            app: null == app
                ? _value.app
                : app // ignore: cast_nullable_to_non_nullable
                      as ApprovalAppDto,
            acp: freezed == acp
                ? _value.acp
                : acp // ignore: cast_nullable_to_non_nullable
                      as AcpRequestPermissionRequestDto?,
          )
          as $Val,
    );
  }

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ApprovalAppDtoCopyWith<$Res> get app {
    return $ApprovalAppDtoCopyWith<$Res>(_value.app, (value) {
      return _then(_value.copyWith(app: value) as $Val);
    });
  }

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AcpRequestPermissionRequestDtoCopyWith<$Res>? get acp {
    if (_value.acp == null) {
      return null;
    }

    return $AcpRequestPermissionRequestDtoCopyWith<$Res>(_value.acp!, (value) {
      return _then(_value.copyWith(acp: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ApprovalWireDtoImplCopyWith<$Res>
    implements $ApprovalWireDtoCopyWith<$Res> {
  factory _$$ApprovalWireDtoImplCopyWith(
    _$ApprovalWireDtoImpl value,
    $Res Function(_$ApprovalWireDtoImpl) then,
  ) = __$$ApprovalWireDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({ApprovalAppDto app, AcpRequestPermissionRequestDto? acp});

  @override
  $ApprovalAppDtoCopyWith<$Res> get app;
  @override
  $AcpRequestPermissionRequestDtoCopyWith<$Res>? get acp;
}

/// @nodoc
class __$$ApprovalWireDtoImplCopyWithImpl<$Res>
    extends _$ApprovalWireDtoCopyWithImpl<$Res, _$ApprovalWireDtoImpl>
    implements _$$ApprovalWireDtoImplCopyWith<$Res> {
  __$$ApprovalWireDtoImplCopyWithImpl(
    _$ApprovalWireDtoImpl _value,
    $Res Function(_$ApprovalWireDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _$ApprovalWireDtoImpl(
        app: null == app
            ? _value.app
            : app // ignore: cast_nullable_to_non_nullable
                  as ApprovalAppDto,
        acp: freezed == acp
            ? _value.acp
            : acp // ignore: cast_nullable_to_non_nullable
                  as AcpRequestPermissionRequestDto?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApprovalWireDtoImpl implements _ApprovalWireDto {
  const _$ApprovalWireDtoImpl({required this.app, this.acp});

  factory _$ApprovalWireDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApprovalWireDtoImplFromJson(json);

  @override
  final ApprovalAppDto app;
  @override
  final AcpRequestPermissionRequestDto? acp;

  @override
  String toString() {
    return 'ApprovalWireDto(app: $app, acp: $acp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApprovalWireDtoImpl &&
            (identical(other.app, app) || other.app == app) &&
            (identical(other.acp, acp) || other.acp == acp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, app, acp);

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApprovalWireDtoImplCopyWith<_$ApprovalWireDtoImpl> get copyWith =>
      __$$ApprovalWireDtoImplCopyWithImpl<_$ApprovalWireDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ApprovalWireDtoImplToJson(this);
  }
}

abstract class _ApprovalWireDto implements ApprovalWireDto {
  const factory _ApprovalWireDto({
    required final ApprovalAppDto app,
    final AcpRequestPermissionRequestDto? acp,
  }) = _$ApprovalWireDtoImpl;

  factory _ApprovalWireDto.fromJson(Map<String, dynamic> json) =
      _$ApprovalWireDtoImpl.fromJson;

  @override
  ApprovalAppDto get app;
  @override
  AcpRequestPermissionRequestDto? get acp;

  /// Create a copy of ApprovalWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApprovalWireDtoImplCopyWith<_$ApprovalWireDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ApprovalAppDto _$ApprovalAppDtoFromJson(Map<String, dynamic> json) {
  return _ApprovalAppDto.fromJson(json);
}

/// @nodoc
mixin _$ApprovalAppDto {
  @JsonKey(name: 'requestId')
  String get requestId => throw _privateConstructorUsedError;
  @JsonKey(name: 'createdAt')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  String? get runtime => throw _privateConstructorUsedError;
  @JsonKey(name: 'toolCallId')
  String? get toolCallId => throw _privateConstructorUsedError;
  @JsonKey(name: 'toolKind')
  String? get toolKind => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'bodyText')
  String? get bodyText => throw _privateConstructorUsedError;
  ApprovalCommandDto? get command => throw _privateConstructorUsedError;
  String? get cwd => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  ApprovalPlanDto? get plan => throw _privateConstructorUsedError;

  /// Serializes this ApprovalAppDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApprovalAppDtoCopyWith<ApprovalAppDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApprovalAppDtoCopyWith<$Res> {
  factory $ApprovalAppDtoCopyWith(
    ApprovalAppDto value,
    $Res Function(ApprovalAppDto) then,
  ) = _$ApprovalAppDtoCopyWithImpl<$Res, ApprovalAppDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'requestId') String requestId,
    @JsonKey(name: 'createdAt') DateTime? createdAt,
    String? runtime,
    @JsonKey(name: 'toolCallId') String? toolCallId,
    @JsonKey(name: 'toolKind') String? toolKind,
    String? title,
    @JsonKey(name: 'bodyText') String? bodyText,
    ApprovalCommandDto? command,
    String? cwd,
    String? reason,
    ApprovalPlanDto? plan,
  });

  $ApprovalCommandDtoCopyWith<$Res>? get command;
  $ApprovalPlanDtoCopyWith<$Res>? get plan;
}

/// @nodoc
class _$ApprovalAppDtoCopyWithImpl<$Res, $Val extends ApprovalAppDto>
    implements $ApprovalAppDtoCopyWith<$Res> {
  _$ApprovalAppDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requestId = null,
    Object? createdAt = freezed,
    Object? runtime = freezed,
    Object? toolCallId = freezed,
    Object? toolKind = freezed,
    Object? title = freezed,
    Object? bodyText = freezed,
    Object? command = freezed,
    Object? cwd = freezed,
    Object? reason = freezed,
    Object? plan = freezed,
  }) {
    return _then(
      _value.copyWith(
            requestId: null == requestId
                ? _value.requestId
                : requestId // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            runtime: freezed == runtime
                ? _value.runtime
                : runtime // ignore: cast_nullable_to_non_nullable
                      as String?,
            toolCallId: freezed == toolCallId
                ? _value.toolCallId
                : toolCallId // ignore: cast_nullable_to_non_nullable
                      as String?,
            toolKind: freezed == toolKind
                ? _value.toolKind
                : toolKind // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            bodyText: freezed == bodyText
                ? _value.bodyText
                : bodyText // ignore: cast_nullable_to_non_nullable
                      as String?,
            command: freezed == command
                ? _value.command
                : command // ignore: cast_nullable_to_non_nullable
                      as ApprovalCommandDto?,
            cwd: freezed == cwd
                ? _value.cwd
                : cwd // ignore: cast_nullable_to_non_nullable
                      as String?,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
            plan: freezed == plan
                ? _value.plan
                : plan // ignore: cast_nullable_to_non_nullable
                      as ApprovalPlanDto?,
          )
          as $Val,
    );
  }

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ApprovalCommandDtoCopyWith<$Res>? get command {
    if (_value.command == null) {
      return null;
    }

    return $ApprovalCommandDtoCopyWith<$Res>(_value.command!, (value) {
      return _then(_value.copyWith(command: value) as $Val);
    });
  }

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ApprovalPlanDtoCopyWith<$Res>? get plan {
    if (_value.plan == null) {
      return null;
    }

    return $ApprovalPlanDtoCopyWith<$Res>(_value.plan!, (value) {
      return _then(_value.copyWith(plan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ApprovalAppDtoImplCopyWith<$Res>
    implements $ApprovalAppDtoCopyWith<$Res> {
  factory _$$ApprovalAppDtoImplCopyWith(
    _$ApprovalAppDtoImpl value,
    $Res Function(_$ApprovalAppDtoImpl) then,
  ) = __$$ApprovalAppDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'requestId') String requestId,
    @JsonKey(name: 'createdAt') DateTime? createdAt,
    String? runtime,
    @JsonKey(name: 'toolCallId') String? toolCallId,
    @JsonKey(name: 'toolKind') String? toolKind,
    String? title,
    @JsonKey(name: 'bodyText') String? bodyText,
    ApprovalCommandDto? command,
    String? cwd,
    String? reason,
    ApprovalPlanDto? plan,
  });

  @override
  $ApprovalCommandDtoCopyWith<$Res>? get command;
  @override
  $ApprovalPlanDtoCopyWith<$Res>? get plan;
}

/// @nodoc
class __$$ApprovalAppDtoImplCopyWithImpl<$Res>
    extends _$ApprovalAppDtoCopyWithImpl<$Res, _$ApprovalAppDtoImpl>
    implements _$$ApprovalAppDtoImplCopyWith<$Res> {
  __$$ApprovalAppDtoImplCopyWithImpl(
    _$ApprovalAppDtoImpl _value,
    $Res Function(_$ApprovalAppDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? requestId = null,
    Object? createdAt = freezed,
    Object? runtime = freezed,
    Object? toolCallId = freezed,
    Object? toolKind = freezed,
    Object? title = freezed,
    Object? bodyText = freezed,
    Object? command = freezed,
    Object? cwd = freezed,
    Object? reason = freezed,
    Object? plan = freezed,
  }) {
    return _then(
      _$ApprovalAppDtoImpl(
        requestId: null == requestId
            ? _value.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        runtime: freezed == runtime
            ? _value.runtime
            : runtime // ignore: cast_nullable_to_non_nullable
                  as String?,
        toolCallId: freezed == toolCallId
            ? _value.toolCallId
            : toolCallId // ignore: cast_nullable_to_non_nullable
                  as String?,
        toolKind: freezed == toolKind
            ? _value.toolKind
            : toolKind // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        bodyText: freezed == bodyText
            ? _value.bodyText
            : bodyText // ignore: cast_nullable_to_non_nullable
                  as String?,
        command: freezed == command
            ? _value.command
            : command // ignore: cast_nullable_to_non_nullable
                  as ApprovalCommandDto?,
        cwd: freezed == cwd
            ? _value.cwd
            : cwd // ignore: cast_nullable_to_non_nullable
                  as String?,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
        plan: freezed == plan
            ? _value.plan
            : plan // ignore: cast_nullable_to_non_nullable
                  as ApprovalPlanDto?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApprovalAppDtoImpl implements _ApprovalAppDto {
  const _$ApprovalAppDtoImpl({
    @JsonKey(name: 'requestId') required this.requestId,
    @JsonKey(name: 'createdAt') this.createdAt,
    this.runtime,
    @JsonKey(name: 'toolCallId') this.toolCallId,
    @JsonKey(name: 'toolKind') this.toolKind,
    this.title,
    @JsonKey(name: 'bodyText') this.bodyText,
    this.command,
    this.cwd,
    this.reason,
    this.plan,
  });

  factory _$ApprovalAppDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApprovalAppDtoImplFromJson(json);

  @override
  @JsonKey(name: 'requestId')
  final String requestId;
  @override
  @JsonKey(name: 'createdAt')
  final DateTime? createdAt;
  @override
  final String? runtime;
  @override
  @JsonKey(name: 'toolCallId')
  final String? toolCallId;
  @override
  @JsonKey(name: 'toolKind')
  final String? toolKind;
  @override
  final String? title;
  @override
  @JsonKey(name: 'bodyText')
  final String? bodyText;
  @override
  final ApprovalCommandDto? command;
  @override
  final String? cwd;
  @override
  final String? reason;
  @override
  final ApprovalPlanDto? plan;

  @override
  String toString() {
    return 'ApprovalAppDto(requestId: $requestId, createdAt: $createdAt, runtime: $runtime, toolCallId: $toolCallId, toolKind: $toolKind, title: $title, bodyText: $bodyText, command: $command, cwd: $cwd, reason: $reason, plan: $plan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApprovalAppDtoImpl &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.runtime, runtime) || other.runtime == runtime) &&
            (identical(other.toolCallId, toolCallId) ||
                other.toolCallId == toolCallId) &&
            (identical(other.toolKind, toolKind) ||
                other.toolKind == toolKind) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.bodyText, bodyText) ||
                other.bodyText == bodyText) &&
            (identical(other.command, command) || other.command == command) &&
            (identical(other.cwd, cwd) || other.cwd == cwd) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.plan, plan) || other.plan == plan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    requestId,
    createdAt,
    runtime,
    toolCallId,
    toolKind,
    title,
    bodyText,
    command,
    cwd,
    reason,
    plan,
  );

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApprovalAppDtoImplCopyWith<_$ApprovalAppDtoImpl> get copyWith =>
      __$$ApprovalAppDtoImplCopyWithImpl<_$ApprovalAppDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ApprovalAppDtoImplToJson(this);
  }
}

abstract class _ApprovalAppDto implements ApprovalAppDto {
  const factory _ApprovalAppDto({
    @JsonKey(name: 'requestId') required final String requestId,
    @JsonKey(name: 'createdAt') final DateTime? createdAt,
    final String? runtime,
    @JsonKey(name: 'toolCallId') final String? toolCallId,
    @JsonKey(name: 'toolKind') final String? toolKind,
    final String? title,
    @JsonKey(name: 'bodyText') final String? bodyText,
    final ApprovalCommandDto? command,
    final String? cwd,
    final String? reason,
    final ApprovalPlanDto? plan,
  }) = _$ApprovalAppDtoImpl;

  factory _ApprovalAppDto.fromJson(Map<String, dynamic> json) =
      _$ApprovalAppDtoImpl.fromJson;

  @override
  @JsonKey(name: 'requestId')
  String get requestId;
  @override
  @JsonKey(name: 'createdAt')
  DateTime? get createdAt;
  @override
  String? get runtime;
  @override
  @JsonKey(name: 'toolCallId')
  String? get toolCallId;
  @override
  @JsonKey(name: 'toolKind')
  String? get toolKind;
  @override
  String? get title;
  @override
  @JsonKey(name: 'bodyText')
  String? get bodyText;
  @override
  ApprovalCommandDto? get command;
  @override
  String? get cwd;
  @override
  String? get reason;
  @override
  ApprovalPlanDto? get plan;

  /// Create a copy of ApprovalAppDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApprovalAppDtoImplCopyWith<_$ApprovalAppDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ApprovalCommandDto _$ApprovalCommandDtoFromJson(Map<String, dynamic> json) {
  return _ApprovalCommandDto.fromJson(json);
}

/// @nodoc
mixin _$ApprovalCommandDto {
  List<String> get argv => throw _privateConstructorUsedError;
  String? get display => throw _privateConstructorUsedError;

  /// Serializes this ApprovalCommandDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApprovalCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApprovalCommandDtoCopyWith<ApprovalCommandDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApprovalCommandDtoCopyWith<$Res> {
  factory $ApprovalCommandDtoCopyWith(
    ApprovalCommandDto value,
    $Res Function(ApprovalCommandDto) then,
  ) = _$ApprovalCommandDtoCopyWithImpl<$Res, ApprovalCommandDto>;
  @useResult
  $Res call({List<String> argv, String? display});
}

/// @nodoc
class _$ApprovalCommandDtoCopyWithImpl<$Res, $Val extends ApprovalCommandDto>
    implements $ApprovalCommandDtoCopyWith<$Res> {
  _$ApprovalCommandDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApprovalCommandDto
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
abstract class _$$ApprovalCommandDtoImplCopyWith<$Res>
    implements $ApprovalCommandDtoCopyWith<$Res> {
  factory _$$ApprovalCommandDtoImplCopyWith(
    _$ApprovalCommandDtoImpl value,
    $Res Function(_$ApprovalCommandDtoImpl) then,
  ) = __$$ApprovalCommandDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<String> argv, String? display});
}

/// @nodoc
class __$$ApprovalCommandDtoImplCopyWithImpl<$Res>
    extends _$ApprovalCommandDtoCopyWithImpl<$Res, _$ApprovalCommandDtoImpl>
    implements _$$ApprovalCommandDtoImplCopyWith<$Res> {
  __$$ApprovalCommandDtoImplCopyWithImpl(
    _$ApprovalCommandDtoImpl _value,
    $Res Function(_$ApprovalCommandDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApprovalCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? argv = null, Object? display = freezed}) {
    return _then(
      _$ApprovalCommandDtoImpl(
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
class _$ApprovalCommandDtoImpl implements _ApprovalCommandDto {
  const _$ApprovalCommandDtoImpl({
    final List<String> argv = const <String>[],
    this.display,
  }) : _argv = argv;

  factory _$ApprovalCommandDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApprovalCommandDtoImplFromJson(json);

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
    return 'ApprovalCommandDto(argv: $argv, display: $display)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApprovalCommandDtoImpl &&
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

  /// Create a copy of ApprovalCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApprovalCommandDtoImplCopyWith<_$ApprovalCommandDtoImpl> get copyWith =>
      __$$ApprovalCommandDtoImplCopyWithImpl<_$ApprovalCommandDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ApprovalCommandDtoImplToJson(this);
  }
}

abstract class _ApprovalCommandDto implements ApprovalCommandDto {
  const factory _ApprovalCommandDto({
    final List<String> argv,
    final String? display,
  }) = _$ApprovalCommandDtoImpl;

  factory _ApprovalCommandDto.fromJson(Map<String, dynamic> json) =
      _$ApprovalCommandDtoImpl.fromJson;

  @override
  List<String> get argv;
  @override
  String? get display;

  /// Create a copy of ApprovalCommandDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApprovalCommandDtoImplCopyWith<_$ApprovalCommandDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ApprovalPlanDto _$ApprovalPlanDtoFromJson(Map<String, dynamic> json) {
  return _ApprovalPlanDto.fromJson(json);
}

/// @nodoc
mixin _$ApprovalPlanDto {
  String? get markdown => throw _privateConstructorUsedError;
  @JsonKey(name: 'allowedPrompts')
  List<ApprovalAllowedPromptDto> get allowedPrompts =>
      throw _privateConstructorUsedError;

  /// Serializes this ApprovalPlanDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApprovalPlanDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApprovalPlanDtoCopyWith<ApprovalPlanDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApprovalPlanDtoCopyWith<$Res> {
  factory $ApprovalPlanDtoCopyWith(
    ApprovalPlanDto value,
    $Res Function(ApprovalPlanDto) then,
  ) = _$ApprovalPlanDtoCopyWithImpl<$Res, ApprovalPlanDto>;
  @useResult
  $Res call({
    String? markdown,
    @JsonKey(name: 'allowedPrompts')
    List<ApprovalAllowedPromptDto> allowedPrompts,
  });
}

/// @nodoc
class _$ApprovalPlanDtoCopyWithImpl<$Res, $Val extends ApprovalPlanDto>
    implements $ApprovalPlanDtoCopyWith<$Res> {
  _$ApprovalPlanDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApprovalPlanDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? markdown = freezed, Object? allowedPrompts = null}) {
    return _then(
      _value.copyWith(
            markdown: freezed == markdown
                ? _value.markdown
                : markdown // ignore: cast_nullable_to_non_nullable
                      as String?,
            allowedPrompts: null == allowedPrompts
                ? _value.allowedPrompts
                : allowedPrompts // ignore: cast_nullable_to_non_nullable
                      as List<ApprovalAllowedPromptDto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ApprovalPlanDtoImplCopyWith<$Res>
    implements $ApprovalPlanDtoCopyWith<$Res> {
  factory _$$ApprovalPlanDtoImplCopyWith(
    _$ApprovalPlanDtoImpl value,
    $Res Function(_$ApprovalPlanDtoImpl) then,
  ) = __$$ApprovalPlanDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? markdown,
    @JsonKey(name: 'allowedPrompts')
    List<ApprovalAllowedPromptDto> allowedPrompts,
  });
}

/// @nodoc
class __$$ApprovalPlanDtoImplCopyWithImpl<$Res>
    extends _$ApprovalPlanDtoCopyWithImpl<$Res, _$ApprovalPlanDtoImpl>
    implements _$$ApprovalPlanDtoImplCopyWith<$Res> {
  __$$ApprovalPlanDtoImplCopyWithImpl(
    _$ApprovalPlanDtoImpl _value,
    $Res Function(_$ApprovalPlanDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApprovalPlanDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? markdown = freezed, Object? allowedPrompts = null}) {
    return _then(
      _$ApprovalPlanDtoImpl(
        markdown: freezed == markdown
            ? _value.markdown
            : markdown // ignore: cast_nullable_to_non_nullable
                  as String?,
        allowedPrompts: null == allowedPrompts
            ? _value._allowedPrompts
            : allowedPrompts // ignore: cast_nullable_to_non_nullable
                  as List<ApprovalAllowedPromptDto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApprovalPlanDtoImpl implements _ApprovalPlanDto {
  const _$ApprovalPlanDtoImpl({
    this.markdown,
    @JsonKey(name: 'allowedPrompts')
    final List<ApprovalAllowedPromptDto> allowedPrompts =
        const <ApprovalAllowedPromptDto>[],
  }) : _allowedPrompts = allowedPrompts;

  factory _$ApprovalPlanDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApprovalPlanDtoImplFromJson(json);

  @override
  final String? markdown;
  final List<ApprovalAllowedPromptDto> _allowedPrompts;
  @override
  @JsonKey(name: 'allowedPrompts')
  List<ApprovalAllowedPromptDto> get allowedPrompts {
    if (_allowedPrompts is EqualUnmodifiableListView) return _allowedPrompts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allowedPrompts);
  }

  @override
  String toString() {
    return 'ApprovalPlanDto(markdown: $markdown, allowedPrompts: $allowedPrompts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApprovalPlanDtoImpl &&
            (identical(other.markdown, markdown) ||
                other.markdown == markdown) &&
            const DeepCollectionEquality().equals(
              other._allowedPrompts,
              _allowedPrompts,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    markdown,
    const DeepCollectionEquality().hash(_allowedPrompts),
  );

  /// Create a copy of ApprovalPlanDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApprovalPlanDtoImplCopyWith<_$ApprovalPlanDtoImpl> get copyWith =>
      __$$ApprovalPlanDtoImplCopyWithImpl<_$ApprovalPlanDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ApprovalPlanDtoImplToJson(this);
  }
}

abstract class _ApprovalPlanDto implements ApprovalPlanDto {
  const factory _ApprovalPlanDto({
    final String? markdown,
    @JsonKey(name: 'allowedPrompts')
    final List<ApprovalAllowedPromptDto> allowedPrompts,
  }) = _$ApprovalPlanDtoImpl;

  factory _ApprovalPlanDto.fromJson(Map<String, dynamic> json) =
      _$ApprovalPlanDtoImpl.fromJson;

  @override
  String? get markdown;
  @override
  @JsonKey(name: 'allowedPrompts')
  List<ApprovalAllowedPromptDto> get allowedPrompts;

  /// Create a copy of ApprovalPlanDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApprovalPlanDtoImplCopyWith<_$ApprovalPlanDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ApprovalAllowedPromptDto _$ApprovalAllowedPromptDtoFromJson(
  Map<String, dynamic> json,
) {
  return _ApprovalAllowedPromptDto.fromJson(json);
}

/// @nodoc
mixin _$ApprovalAllowedPromptDto {
  String get prompt => throw _privateConstructorUsedError;

  /// Serializes this ApprovalAllowedPromptDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ApprovalAllowedPromptDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ApprovalAllowedPromptDtoCopyWith<ApprovalAllowedPromptDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApprovalAllowedPromptDtoCopyWith<$Res> {
  factory $ApprovalAllowedPromptDtoCopyWith(
    ApprovalAllowedPromptDto value,
    $Res Function(ApprovalAllowedPromptDto) then,
  ) = _$ApprovalAllowedPromptDtoCopyWithImpl<$Res, ApprovalAllowedPromptDto>;
  @useResult
  $Res call({String prompt});
}

/// @nodoc
class _$ApprovalAllowedPromptDtoCopyWithImpl<
  $Res,
  $Val extends ApprovalAllowedPromptDto
>
    implements $ApprovalAllowedPromptDtoCopyWith<$Res> {
  _$ApprovalAllowedPromptDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApprovalAllowedPromptDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? prompt = null}) {
    return _then(
      _value.copyWith(
            prompt: null == prompt
                ? _value.prompt
                : prompt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ApprovalAllowedPromptDtoImplCopyWith<$Res>
    implements $ApprovalAllowedPromptDtoCopyWith<$Res> {
  factory _$$ApprovalAllowedPromptDtoImplCopyWith(
    _$ApprovalAllowedPromptDtoImpl value,
    $Res Function(_$ApprovalAllowedPromptDtoImpl) then,
  ) = __$$ApprovalAllowedPromptDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String prompt});
}

/// @nodoc
class __$$ApprovalAllowedPromptDtoImplCopyWithImpl<$Res>
    extends
        _$ApprovalAllowedPromptDtoCopyWithImpl<
          $Res,
          _$ApprovalAllowedPromptDtoImpl
        >
    implements _$$ApprovalAllowedPromptDtoImplCopyWith<$Res> {
  __$$ApprovalAllowedPromptDtoImplCopyWithImpl(
    _$ApprovalAllowedPromptDtoImpl _value,
    $Res Function(_$ApprovalAllowedPromptDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApprovalAllowedPromptDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? prompt = null}) {
    return _then(
      _$ApprovalAllowedPromptDtoImpl(
        prompt: null == prompt
            ? _value.prompt
            : prompt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ApprovalAllowedPromptDtoImpl implements _ApprovalAllowedPromptDto {
  const _$ApprovalAllowedPromptDtoImpl({required this.prompt});

  factory _$ApprovalAllowedPromptDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ApprovalAllowedPromptDtoImplFromJson(json);

  @override
  final String prompt;

  @override
  String toString() {
    return 'ApprovalAllowedPromptDto(prompt: $prompt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApprovalAllowedPromptDtoImpl &&
            (identical(other.prompt, prompt) || other.prompt == prompt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, prompt);

  /// Create a copy of ApprovalAllowedPromptDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApprovalAllowedPromptDtoImplCopyWith<_$ApprovalAllowedPromptDtoImpl>
  get copyWith =>
      __$$ApprovalAllowedPromptDtoImplCopyWithImpl<
        _$ApprovalAllowedPromptDtoImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ApprovalAllowedPromptDtoImplToJson(this);
  }
}

abstract class _ApprovalAllowedPromptDto implements ApprovalAllowedPromptDto {
  const factory _ApprovalAllowedPromptDto({required final String prompt}) =
      _$ApprovalAllowedPromptDtoImpl;

  factory _ApprovalAllowedPromptDto.fromJson(Map<String, dynamic> json) =
      _$ApprovalAllowedPromptDtoImpl.fromJson;

  @override
  String get prompt;

  /// Create a copy of ApprovalAllowedPromptDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApprovalAllowedPromptDtoImplCopyWith<_$ApprovalAllowedPromptDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AcpRequestPermissionRequestDto _$AcpRequestPermissionRequestDtoFromJson(
  Map<String, dynamic> json,
) {
  return _AcpRequestPermissionRequestDto.fromJson(json);
}

/// @nodoc
mixin _$AcpRequestPermissionRequestDto {
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String get sessionId => throw _privateConstructorUsedError;
  @JsonKey(name: 'toolCall')
  AcpToolCallUpdateDto get toolCall => throw _privateConstructorUsedError;
  List<AcpPermissionOptionDto> get options =>
      throw _privateConstructorUsedError;

  /// Serializes this AcpRequestPermissionRequestDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcpRequestPermissionRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcpRequestPermissionRequestDtoCopyWith<AcpRequestPermissionRequestDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcpRequestPermissionRequestDtoCopyWith<$Res> {
  factory $AcpRequestPermissionRequestDtoCopyWith(
    AcpRequestPermissionRequestDto value,
    $Res Function(AcpRequestPermissionRequestDto) then,
  ) =
      _$AcpRequestPermissionRequestDtoCopyWithImpl<
        $Res,
        AcpRequestPermissionRequestDto
      >;
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'sessionId') String sessionId,
    @JsonKey(name: 'toolCall') AcpToolCallUpdateDto toolCall,
    List<AcpPermissionOptionDto> options,
  });

  $AcpToolCallUpdateDtoCopyWith<$Res> get toolCall;
}

/// @nodoc
class _$AcpRequestPermissionRequestDtoCopyWithImpl<
  $Res,
  $Val extends AcpRequestPermissionRequestDto
>
    implements $AcpRequestPermissionRequestDtoCopyWith<$Res> {
  _$AcpRequestPermissionRequestDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcpRequestPermissionRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? sessionId = null,
    Object? toolCall = null,
    Object? options = null,
  }) {
    return _then(
      _value.copyWith(
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            toolCall: null == toolCall
                ? _value.toolCall
                : toolCall // ignore: cast_nullable_to_non_nullable
                      as AcpToolCallUpdateDto,
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as List<AcpPermissionOptionDto>,
          )
          as $Val,
    );
  }

  /// Create a copy of AcpRequestPermissionRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AcpToolCallUpdateDtoCopyWith<$Res> get toolCall {
    return $AcpToolCallUpdateDtoCopyWith<$Res>(_value.toolCall, (value) {
      return _then(_value.copyWith(toolCall: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AcpRequestPermissionRequestDtoImplCopyWith<$Res>
    implements $AcpRequestPermissionRequestDtoCopyWith<$Res> {
  factory _$$AcpRequestPermissionRequestDtoImplCopyWith(
    _$AcpRequestPermissionRequestDtoImpl value,
    $Res Function(_$AcpRequestPermissionRequestDtoImpl) then,
  ) = __$$AcpRequestPermissionRequestDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'sessionId') String sessionId,
    @JsonKey(name: 'toolCall') AcpToolCallUpdateDto toolCall,
    List<AcpPermissionOptionDto> options,
  });

  @override
  $AcpToolCallUpdateDtoCopyWith<$Res> get toolCall;
}

/// @nodoc
class __$$AcpRequestPermissionRequestDtoImplCopyWithImpl<$Res>
    extends
        _$AcpRequestPermissionRequestDtoCopyWithImpl<
          $Res,
          _$AcpRequestPermissionRequestDtoImpl
        >
    implements _$$AcpRequestPermissionRequestDtoImplCopyWith<$Res> {
  __$$AcpRequestPermissionRequestDtoImplCopyWithImpl(
    _$AcpRequestPermissionRequestDtoImpl _value,
    $Res Function(_$AcpRequestPermissionRequestDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AcpRequestPermissionRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? sessionId = null,
    Object? toolCall = null,
    Object? options = null,
  }) {
    return _then(
      _$AcpRequestPermissionRequestDtoImpl(
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        toolCall: null == toolCall
            ? _value.toolCall
            : toolCall // ignore: cast_nullable_to_non_nullable
                  as AcpToolCallUpdateDto,
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as List<AcpPermissionOptionDto>,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _$AcpRequestPermissionRequestDtoImpl
    implements _AcpRequestPermissionRequestDto {
  const _$AcpRequestPermissionRequestDtoImpl({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    @JsonKey(name: 'sessionId') required this.sessionId,
    @JsonKey(name: 'toolCall') required this.toolCall,
    final List<AcpPermissionOptionDto> options =
        const <AcpPermissionOptionDto>[],
  }) : _meta = meta,
       _options = options;

  factory _$AcpRequestPermissionRequestDtoImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$AcpRequestPermissionRequestDtoImplFromJson(json);

  final Map<String, dynamic>? _meta;
  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta {
    final value = _meta;
    if (value == null) return null;
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'sessionId')
  final String sessionId;
  @override
  @JsonKey(name: 'toolCall')
  final AcpToolCallUpdateDto toolCall;
  final List<AcpPermissionOptionDto> _options;
  @override
  @JsonKey()
  List<AcpPermissionOptionDto> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  String toString() {
    return 'AcpRequestPermissionRequestDto(meta: $meta, sessionId: $sessionId, toolCall: $toolCall, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcpRequestPermissionRequestDtoImpl &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.toolCall, toolCall) ||
                other.toolCall == toolCall) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_meta),
    sessionId,
    toolCall,
    const DeepCollectionEquality().hash(_options),
  );

  /// Create a copy of AcpRequestPermissionRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcpRequestPermissionRequestDtoImplCopyWith<
    _$AcpRequestPermissionRequestDtoImpl
  >
  get copyWith =>
      __$$AcpRequestPermissionRequestDtoImplCopyWithImpl<
        _$AcpRequestPermissionRequestDtoImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AcpRequestPermissionRequestDtoImplToJson(this);
  }
}

abstract class _AcpRequestPermissionRequestDto
    implements AcpRequestPermissionRequestDto {
  const factory _AcpRequestPermissionRequestDto({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    @JsonKey(name: 'sessionId') required final String sessionId,
    @JsonKey(name: 'toolCall') required final AcpToolCallUpdateDto toolCall,
    final List<AcpPermissionOptionDto> options,
  }) = _$AcpRequestPermissionRequestDtoImpl;

  factory _AcpRequestPermissionRequestDto.fromJson(Map<String, dynamic> json) =
      _$AcpRequestPermissionRequestDtoImpl.fromJson;

  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta;
  @override
  @JsonKey(name: 'sessionId')
  String get sessionId;
  @override
  @JsonKey(name: 'toolCall')
  AcpToolCallUpdateDto get toolCall;
  @override
  List<AcpPermissionOptionDto> get options;

  /// Create a copy of AcpRequestPermissionRequestDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcpRequestPermissionRequestDtoImplCopyWith<
    _$AcpRequestPermissionRequestDtoImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

AcpPermissionOptionDto _$AcpPermissionOptionDtoFromJson(
  Map<String, dynamic> json,
) {
  return _AcpPermissionOptionDto.fromJson(json);
}

/// @nodoc
mixin _$AcpPermissionOptionDto {
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  @JsonKey(name: 'optionId')
  String get optionId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get kind => throw _privateConstructorUsedError;

  /// Serializes this AcpPermissionOptionDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcpPermissionOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcpPermissionOptionDtoCopyWith<AcpPermissionOptionDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcpPermissionOptionDtoCopyWith<$Res> {
  factory $AcpPermissionOptionDtoCopyWith(
    AcpPermissionOptionDto value,
    $Res Function(AcpPermissionOptionDto) then,
  ) = _$AcpPermissionOptionDtoCopyWithImpl<$Res, AcpPermissionOptionDto>;
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'optionId') String optionId,
    String name,
    String kind,
  });
}

/// @nodoc
class _$AcpPermissionOptionDtoCopyWithImpl<
  $Res,
  $Val extends AcpPermissionOptionDto
>
    implements $AcpPermissionOptionDtoCopyWith<$Res> {
  _$AcpPermissionOptionDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcpPermissionOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? optionId = null,
    Object? name = null,
    Object? kind = null,
  }) {
    return _then(
      _value.copyWith(
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            optionId: null == optionId
                ? _value.optionId
                : optionId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AcpPermissionOptionDtoImplCopyWith<$Res>
    implements $AcpPermissionOptionDtoCopyWith<$Res> {
  factory _$$AcpPermissionOptionDtoImplCopyWith(
    _$AcpPermissionOptionDtoImpl value,
    $Res Function(_$AcpPermissionOptionDtoImpl) then,
  ) = __$$AcpPermissionOptionDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'optionId') String optionId,
    String name,
    String kind,
  });
}

/// @nodoc
class __$$AcpPermissionOptionDtoImplCopyWithImpl<$Res>
    extends
        _$AcpPermissionOptionDtoCopyWithImpl<$Res, _$AcpPermissionOptionDtoImpl>
    implements _$$AcpPermissionOptionDtoImplCopyWith<$Res> {
  __$$AcpPermissionOptionDtoImplCopyWithImpl(
    _$AcpPermissionOptionDtoImpl _value,
    $Res Function(_$AcpPermissionOptionDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AcpPermissionOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? optionId = null,
    Object? name = null,
    Object? kind = null,
  }) {
    return _then(
      _$AcpPermissionOptionDtoImpl(
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        optionId: null == optionId
            ? _value.optionId
            : optionId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _$AcpPermissionOptionDtoImpl implements _AcpPermissionOptionDto {
  const _$AcpPermissionOptionDtoImpl({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    @JsonKey(name: 'optionId') required this.optionId,
    required this.name,
    required this.kind,
  }) : _meta = meta;

  factory _$AcpPermissionOptionDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AcpPermissionOptionDtoImplFromJson(json);

  final Map<String, dynamic>? _meta;
  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta {
    final value = _meta;
    if (value == null) return null;
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'optionId')
  final String optionId;
  @override
  final String name;
  @override
  final String kind;

  @override
  String toString() {
    return 'AcpPermissionOptionDto(meta: $meta, optionId: $optionId, name: $name, kind: $kind)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcpPermissionOptionDtoImpl &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.optionId, optionId) ||
                other.optionId == optionId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.kind, kind) || other.kind == kind));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_meta),
    optionId,
    name,
    kind,
  );

  /// Create a copy of AcpPermissionOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcpPermissionOptionDtoImplCopyWith<_$AcpPermissionOptionDtoImpl>
  get copyWith =>
      __$$AcpPermissionOptionDtoImplCopyWithImpl<_$AcpPermissionOptionDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AcpPermissionOptionDtoImplToJson(this);
  }
}

abstract class _AcpPermissionOptionDto implements AcpPermissionOptionDto {
  const factory _AcpPermissionOptionDto({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    @JsonKey(name: 'optionId') required final String optionId,
    required final String name,
    required final String kind,
  }) = _$AcpPermissionOptionDtoImpl;

  factory _AcpPermissionOptionDto.fromJson(Map<String, dynamic> json) =
      _$AcpPermissionOptionDtoImpl.fromJson;

  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta;
  @override
  @JsonKey(name: 'optionId')
  String get optionId;
  @override
  String get name;
  @override
  String get kind;

  /// Create a copy of AcpPermissionOptionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcpPermissionOptionDtoImplCopyWith<_$AcpPermissionOptionDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AcpRequestPermissionResponseDto _$AcpRequestPermissionResponseDtoFromJson(
  Map<String, dynamic> json,
) {
  return _AcpRequestPermissionResponseDto.fromJson(json);
}

/// @nodoc
mixin _$AcpRequestPermissionResponseDto {
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  AcpRequestPermissionOutcomeDto get outcome =>
      throw _privateConstructorUsedError;

  /// Serializes this AcpRequestPermissionResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcpRequestPermissionResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcpRequestPermissionResponseDtoCopyWith<AcpRequestPermissionResponseDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcpRequestPermissionResponseDtoCopyWith<$Res> {
  factory $AcpRequestPermissionResponseDtoCopyWith(
    AcpRequestPermissionResponseDto value,
    $Res Function(AcpRequestPermissionResponseDto) then,
  ) =
      _$AcpRequestPermissionResponseDtoCopyWithImpl<
        $Res,
        AcpRequestPermissionResponseDto
      >;
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    AcpRequestPermissionOutcomeDto outcome,
  });

  $AcpRequestPermissionOutcomeDtoCopyWith<$Res> get outcome;
}

/// @nodoc
class _$AcpRequestPermissionResponseDtoCopyWithImpl<
  $Res,
  $Val extends AcpRequestPermissionResponseDto
>
    implements $AcpRequestPermissionResponseDtoCopyWith<$Res> {
  _$AcpRequestPermissionResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcpRequestPermissionResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? meta = freezed, Object? outcome = null}) {
    return _then(
      _value.copyWith(
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            outcome: null == outcome
                ? _value.outcome
                : outcome // ignore: cast_nullable_to_non_nullable
                      as AcpRequestPermissionOutcomeDto,
          )
          as $Val,
    );
  }

  /// Create a copy of AcpRequestPermissionResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AcpRequestPermissionOutcomeDtoCopyWith<$Res> get outcome {
    return $AcpRequestPermissionOutcomeDtoCopyWith<$Res>(_value.outcome, (
      value,
    ) {
      return _then(_value.copyWith(outcome: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AcpRequestPermissionResponseDtoImplCopyWith<$Res>
    implements $AcpRequestPermissionResponseDtoCopyWith<$Res> {
  factory _$$AcpRequestPermissionResponseDtoImplCopyWith(
    _$AcpRequestPermissionResponseDtoImpl value,
    $Res Function(_$AcpRequestPermissionResponseDtoImpl) then,
  ) = __$$AcpRequestPermissionResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    AcpRequestPermissionOutcomeDto outcome,
  });

  @override
  $AcpRequestPermissionOutcomeDtoCopyWith<$Res> get outcome;
}

/// @nodoc
class __$$AcpRequestPermissionResponseDtoImplCopyWithImpl<$Res>
    extends
        _$AcpRequestPermissionResponseDtoCopyWithImpl<
          $Res,
          _$AcpRequestPermissionResponseDtoImpl
        >
    implements _$$AcpRequestPermissionResponseDtoImplCopyWith<$Res> {
  __$$AcpRequestPermissionResponseDtoImplCopyWithImpl(
    _$AcpRequestPermissionResponseDtoImpl _value,
    $Res Function(_$AcpRequestPermissionResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AcpRequestPermissionResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? meta = freezed, Object? outcome = null}) {
    return _then(
      _$AcpRequestPermissionResponseDtoImpl(
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        outcome: null == outcome
            ? _value.outcome
            : outcome // ignore: cast_nullable_to_non_nullable
                  as AcpRequestPermissionOutcomeDto,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _$AcpRequestPermissionResponseDtoImpl
    implements _AcpRequestPermissionResponseDto {
  const _$AcpRequestPermissionResponseDtoImpl({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    required this.outcome,
  }) : _meta = meta;

  factory _$AcpRequestPermissionResponseDtoImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$AcpRequestPermissionResponseDtoImplFromJson(json);

  final Map<String, dynamic>? _meta;
  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta {
    final value = _meta;
    if (value == null) return null;
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final AcpRequestPermissionOutcomeDto outcome;

  @override
  String toString() {
    return 'AcpRequestPermissionResponseDto(meta: $meta, outcome: $outcome)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcpRequestPermissionResponseDtoImpl &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.outcome, outcome) || other.outcome == outcome));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_meta),
    outcome,
  );

  /// Create a copy of AcpRequestPermissionResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcpRequestPermissionResponseDtoImplCopyWith<
    _$AcpRequestPermissionResponseDtoImpl
  >
  get copyWith =>
      __$$AcpRequestPermissionResponseDtoImplCopyWithImpl<
        _$AcpRequestPermissionResponseDtoImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AcpRequestPermissionResponseDtoImplToJson(this);
  }
}

abstract class _AcpRequestPermissionResponseDto
    implements AcpRequestPermissionResponseDto {
  const factory _AcpRequestPermissionResponseDto({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    required final AcpRequestPermissionOutcomeDto outcome,
  }) = _$AcpRequestPermissionResponseDtoImpl;

  factory _AcpRequestPermissionResponseDto.fromJson(Map<String, dynamic> json) =
      _$AcpRequestPermissionResponseDtoImpl.fromJson;

  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta;
  @override
  AcpRequestPermissionOutcomeDto get outcome;

  /// Create a copy of AcpRequestPermissionResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcpRequestPermissionResponseDtoImplCopyWith<
    _$AcpRequestPermissionResponseDtoImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

AcpRequestPermissionOutcomeDto _$AcpRequestPermissionOutcomeDtoFromJson(
  Map<String, dynamic> json,
) {
  return _AcpRequestPermissionOutcomeDto.fromJson(json);
}

/// @nodoc
mixin _$AcpRequestPermissionOutcomeDto {
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  String get outcome => throw _privateConstructorUsedError;
  @JsonKey(name: 'optionId')
  String? get optionId => throw _privateConstructorUsedError;

  /// Serializes this AcpRequestPermissionOutcomeDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcpRequestPermissionOutcomeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcpRequestPermissionOutcomeDtoCopyWith<AcpRequestPermissionOutcomeDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcpRequestPermissionOutcomeDtoCopyWith<$Res> {
  factory $AcpRequestPermissionOutcomeDtoCopyWith(
    AcpRequestPermissionOutcomeDto value,
    $Res Function(AcpRequestPermissionOutcomeDto) then,
  ) =
      _$AcpRequestPermissionOutcomeDtoCopyWithImpl<
        $Res,
        AcpRequestPermissionOutcomeDto
      >;
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    String outcome,
    @JsonKey(name: 'optionId') String? optionId,
  });
}

/// @nodoc
class _$AcpRequestPermissionOutcomeDtoCopyWithImpl<
  $Res,
  $Val extends AcpRequestPermissionOutcomeDto
>
    implements $AcpRequestPermissionOutcomeDtoCopyWith<$Res> {
  _$AcpRequestPermissionOutcomeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcpRequestPermissionOutcomeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? outcome = null,
    Object? optionId = freezed,
  }) {
    return _then(
      _value.copyWith(
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            outcome: null == outcome
                ? _value.outcome
                : outcome // ignore: cast_nullable_to_non_nullable
                      as String,
            optionId: freezed == optionId
                ? _value.optionId
                : optionId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AcpRequestPermissionOutcomeDtoImplCopyWith<$Res>
    implements $AcpRequestPermissionOutcomeDtoCopyWith<$Res> {
  factory _$$AcpRequestPermissionOutcomeDtoImplCopyWith(
    _$AcpRequestPermissionOutcomeDtoImpl value,
    $Res Function(_$AcpRequestPermissionOutcomeDtoImpl) then,
  ) = __$$AcpRequestPermissionOutcomeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    String outcome,
    @JsonKey(name: 'optionId') String? optionId,
  });
}

/// @nodoc
class __$$AcpRequestPermissionOutcomeDtoImplCopyWithImpl<$Res>
    extends
        _$AcpRequestPermissionOutcomeDtoCopyWithImpl<
          $Res,
          _$AcpRequestPermissionOutcomeDtoImpl
        >
    implements _$$AcpRequestPermissionOutcomeDtoImplCopyWith<$Res> {
  __$$AcpRequestPermissionOutcomeDtoImplCopyWithImpl(
    _$AcpRequestPermissionOutcomeDtoImpl _value,
    $Res Function(_$AcpRequestPermissionOutcomeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AcpRequestPermissionOutcomeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? outcome = null,
    Object? optionId = freezed,
  }) {
    return _then(
      _$AcpRequestPermissionOutcomeDtoImpl(
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        outcome: null == outcome
            ? _value.outcome
            : outcome // ignore: cast_nullable_to_non_nullable
                  as String,
        optionId: freezed == optionId
            ? _value.optionId
            : optionId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _$AcpRequestPermissionOutcomeDtoImpl
    implements _AcpRequestPermissionOutcomeDto {
  const _$AcpRequestPermissionOutcomeDtoImpl({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    required this.outcome,
    @JsonKey(name: 'optionId') this.optionId,
  }) : _meta = meta;

  factory _$AcpRequestPermissionOutcomeDtoImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$AcpRequestPermissionOutcomeDtoImplFromJson(json);

  final Map<String, dynamic>? _meta;
  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta {
    final value = _meta;
    if (value == null) return null;
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String outcome;
  @override
  @JsonKey(name: 'optionId')
  final String? optionId;

  @override
  String toString() {
    return 'AcpRequestPermissionOutcomeDto(meta: $meta, outcome: $outcome, optionId: $optionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcpRequestPermissionOutcomeDtoImpl &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.outcome, outcome) || other.outcome == outcome) &&
            (identical(other.optionId, optionId) ||
                other.optionId == optionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_meta),
    outcome,
    optionId,
  );

  /// Create a copy of AcpRequestPermissionOutcomeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcpRequestPermissionOutcomeDtoImplCopyWith<
    _$AcpRequestPermissionOutcomeDtoImpl
  >
  get copyWith =>
      __$$AcpRequestPermissionOutcomeDtoImplCopyWithImpl<
        _$AcpRequestPermissionOutcomeDtoImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AcpRequestPermissionOutcomeDtoImplToJson(this);
  }
}

abstract class _AcpRequestPermissionOutcomeDto
    implements AcpRequestPermissionOutcomeDto {
  const factory _AcpRequestPermissionOutcomeDto({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    required final String outcome,
    @JsonKey(name: 'optionId') final String? optionId,
  }) = _$AcpRequestPermissionOutcomeDtoImpl;

  factory _AcpRequestPermissionOutcomeDto.fromJson(Map<String, dynamic> json) =
      _$AcpRequestPermissionOutcomeDtoImpl.fromJson;

  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta;
  @override
  String get outcome;
  @override
  @JsonKey(name: 'optionId')
  String? get optionId;

  /// Create a copy of AcpRequestPermissionOutcomeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcpRequestPermissionOutcomeDtoImplCopyWith<
    _$AcpRequestPermissionOutcomeDtoImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
