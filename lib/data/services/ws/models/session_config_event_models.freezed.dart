// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_config_event_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ModeChangedEventEnvelopeDto _$ModeChangedEventEnvelopeDtoFromJson(
  Map<String, dynamic> json,
) {
  return _ModeChangedEventEnvelopeDto.fromJson(json);
}

/// @nodoc
mixin _$ModeChangedEventEnvelopeDto {
  @JsonKey(fromJson: _requiredString)
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String? get sessionId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  DateTime? get at => throw _privateConstructorUsedError;
  @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
  AppModeChangedEventDataDto get modeChanged =>
      throw _privateConstructorUsedError;

  /// Create a copy of ModeChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModeChangedEventEnvelopeDtoCopyWith<ModeChangedEventEnvelopeDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModeChangedEventEnvelopeDtoCopyWith<$Res> {
  factory $ModeChangedEventEnvelopeDtoCopyWith(
    ModeChangedEventEnvelopeDto value,
    $Res Function(ModeChangedEventEnvelopeDto) then,
  ) =
      _$ModeChangedEventEnvelopeDtoCopyWithImpl<
        $Res,
        ModeChangedEventEnvelopeDto
      >;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
    AppModeChangedEventDataDto modeChanged,
  });
}

/// @nodoc
class _$ModeChangedEventEnvelopeDtoCopyWithImpl<
  $Res,
  $Val extends ModeChangedEventEnvelopeDto
>
    implements $ModeChangedEventEnvelopeDtoCopyWith<$Res> {
  _$ModeChangedEventEnvelopeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModeChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? modeChanged = null,
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
            modeChanged: null == modeChanged
                ? _value.modeChanged
                : modeChanged // ignore: cast_nullable_to_non_nullable
                      as AppModeChangedEventDataDto,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModeChangedEventEnvelopeDtoImplCopyWith<$Res>
    implements $ModeChangedEventEnvelopeDtoCopyWith<$Res> {
  factory _$$ModeChangedEventEnvelopeDtoImplCopyWith(
    _$ModeChangedEventEnvelopeDtoImpl value,
    $Res Function(_$ModeChangedEventEnvelopeDtoImpl) then,
  ) = __$$ModeChangedEventEnvelopeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
    AppModeChangedEventDataDto modeChanged,
  });
}

/// @nodoc
class __$$ModeChangedEventEnvelopeDtoImplCopyWithImpl<$Res>
    extends
        _$ModeChangedEventEnvelopeDtoCopyWithImpl<
          $Res,
          _$ModeChangedEventEnvelopeDtoImpl
        >
    implements _$$ModeChangedEventEnvelopeDtoImplCopyWith<$Res> {
  __$$ModeChangedEventEnvelopeDtoImplCopyWithImpl(
    _$ModeChangedEventEnvelopeDtoImpl _value,
    $Res Function(_$ModeChangedEventEnvelopeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModeChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? modeChanged = null,
  }) {
    return _then(
      _$ModeChangedEventEnvelopeDtoImpl(
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
        modeChanged: null == modeChanged
            ? _value.modeChanged
            : modeChanged // ignore: cast_nullable_to_non_nullable
                  as AppModeChangedEventDataDto,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$ModeChangedEventEnvelopeDtoImpl
    implements _ModeChangedEventEnvelopeDto {
  const _$ModeChangedEventEnvelopeDtoImpl({
    @JsonKey(fromJson: _requiredString) required this.type,
    @JsonKey(name: 'sessionId') this.sessionId,
    this.seq = 0,
    this.at,
    @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
    required this.modeChanged,
  });

  factory _$ModeChangedEventEnvelopeDtoImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$ModeChangedEventEnvelopeDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _requiredString)
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
  @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
  final AppModeChangedEventDataDto modeChanged;

  @override
  String toString() {
    return 'ModeChangedEventEnvelopeDto(type: $type, sessionId: $sessionId, seq: $seq, at: $at, modeChanged: $modeChanged)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModeChangedEventEnvelopeDtoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.modeChanged, modeChanged) ||
                other.modeChanged == modeChanged));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, sessionId, seq, at, modeChanged);

  /// Create a copy of ModeChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModeChangedEventEnvelopeDtoImplCopyWith<_$ModeChangedEventEnvelopeDtoImpl>
  get copyWith =>
      __$$ModeChangedEventEnvelopeDtoImplCopyWithImpl<
        _$ModeChangedEventEnvelopeDtoImpl
      >(this, _$identity);
}

abstract class _ModeChangedEventEnvelopeDto
    implements ModeChangedEventEnvelopeDto {
  const factory _ModeChangedEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required final String type,
    @JsonKey(name: 'sessionId') final String? sessionId,
    final int seq,
    final DateTime? at,
    @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
    required final AppModeChangedEventDataDto modeChanged,
  }) = _$ModeChangedEventEnvelopeDtoImpl;

  factory _ModeChangedEventEnvelopeDto.fromJson(Map<String, dynamic> json) =
      _$ModeChangedEventEnvelopeDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _requiredString)
  String get type;
  @override
  @JsonKey(name: 'sessionId')
  String? get sessionId;
  @override
  int get seq;
  @override
  DateTime? get at;
  @override
  @JsonKey(name: 'modeChanged', fromJson: _modeChangedEnvelopeFromJson)
  AppModeChangedEventDataDto get modeChanged;

  /// Create a copy of ModeChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModeChangedEventEnvelopeDtoImplCopyWith<_$ModeChangedEventEnvelopeDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ConfigChangedEventEnvelopeDto _$ConfigChangedEventEnvelopeDtoFromJson(
  Map<String, dynamic> json,
) {
  return _ConfigChangedEventEnvelopeDto.fromJson(json);
}

/// @nodoc
mixin _$ConfigChangedEventEnvelopeDto {
  @JsonKey(fromJson: _requiredString)
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String? get sessionId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  DateTime? get at => throw _privateConstructorUsedError;
  @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
  AppConfigChangedEventDataDto get configChanged =>
      throw _privateConstructorUsedError;

  /// Create a copy of ConfigChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConfigChangedEventEnvelopeDtoCopyWith<ConfigChangedEventEnvelopeDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConfigChangedEventEnvelopeDtoCopyWith<$Res> {
  factory $ConfigChangedEventEnvelopeDtoCopyWith(
    ConfigChangedEventEnvelopeDto value,
    $Res Function(ConfigChangedEventEnvelopeDto) then,
  ) =
      _$ConfigChangedEventEnvelopeDtoCopyWithImpl<
        $Res,
        ConfigChangedEventEnvelopeDto
      >;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
    AppConfigChangedEventDataDto configChanged,
  });
}

/// @nodoc
class _$ConfigChangedEventEnvelopeDtoCopyWithImpl<
  $Res,
  $Val extends ConfigChangedEventEnvelopeDto
>
    implements $ConfigChangedEventEnvelopeDtoCopyWith<$Res> {
  _$ConfigChangedEventEnvelopeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConfigChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? configChanged = null,
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
            configChanged: null == configChanged
                ? _value.configChanged
                : configChanged // ignore: cast_nullable_to_non_nullable
                      as AppConfigChangedEventDataDto,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConfigChangedEventEnvelopeDtoImplCopyWith<$Res>
    implements $ConfigChangedEventEnvelopeDtoCopyWith<$Res> {
  factory _$$ConfigChangedEventEnvelopeDtoImplCopyWith(
    _$ConfigChangedEventEnvelopeDtoImpl value,
    $Res Function(_$ConfigChangedEventEnvelopeDtoImpl) then,
  ) = __$$ConfigChangedEventEnvelopeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
    AppConfigChangedEventDataDto configChanged,
  });
}

/// @nodoc
class __$$ConfigChangedEventEnvelopeDtoImplCopyWithImpl<$Res>
    extends
        _$ConfigChangedEventEnvelopeDtoCopyWithImpl<
          $Res,
          _$ConfigChangedEventEnvelopeDtoImpl
        >
    implements _$$ConfigChangedEventEnvelopeDtoImplCopyWith<$Res> {
  __$$ConfigChangedEventEnvelopeDtoImplCopyWithImpl(
    _$ConfigChangedEventEnvelopeDtoImpl _value,
    $Res Function(_$ConfigChangedEventEnvelopeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConfigChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? configChanged = null,
  }) {
    return _then(
      _$ConfigChangedEventEnvelopeDtoImpl(
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
        configChanged: null == configChanged
            ? _value.configChanged
            : configChanged // ignore: cast_nullable_to_non_nullable
                  as AppConfigChangedEventDataDto,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$ConfigChangedEventEnvelopeDtoImpl
    implements _ConfigChangedEventEnvelopeDto {
  const _$ConfigChangedEventEnvelopeDtoImpl({
    @JsonKey(fromJson: _requiredString) required this.type,
    @JsonKey(name: 'sessionId') this.sessionId,
    this.seq = 0,
    this.at,
    @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
    required this.configChanged,
  });

  factory _$ConfigChangedEventEnvelopeDtoImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$ConfigChangedEventEnvelopeDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _requiredString)
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
  @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
  final AppConfigChangedEventDataDto configChanged;

  @override
  String toString() {
    return 'ConfigChangedEventEnvelopeDto(type: $type, sessionId: $sessionId, seq: $seq, at: $at, configChanged: $configChanged)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConfigChangedEventEnvelopeDtoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.configChanged, configChanged) ||
                other.configChanged == configChanged));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, sessionId, seq, at, configChanged);

  /// Create a copy of ConfigChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConfigChangedEventEnvelopeDtoImplCopyWith<
    _$ConfigChangedEventEnvelopeDtoImpl
  >
  get copyWith =>
      __$$ConfigChangedEventEnvelopeDtoImplCopyWithImpl<
        _$ConfigChangedEventEnvelopeDtoImpl
      >(this, _$identity);
}

abstract class _ConfigChangedEventEnvelopeDto
    implements ConfigChangedEventEnvelopeDto {
  const factory _ConfigChangedEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required final String type,
    @JsonKey(name: 'sessionId') final String? sessionId,
    final int seq,
    final DateTime? at,
    @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
    required final AppConfigChangedEventDataDto configChanged,
  }) = _$ConfigChangedEventEnvelopeDtoImpl;

  factory _ConfigChangedEventEnvelopeDto.fromJson(Map<String, dynamic> json) =
      _$ConfigChangedEventEnvelopeDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _requiredString)
  String get type;
  @override
  @JsonKey(name: 'sessionId')
  String? get sessionId;
  @override
  int get seq;
  @override
  DateTime? get at;
  @override
  @JsonKey(name: 'configChanged', fromJson: _configChangedEnvelopeFromJson)
  AppConfigChangedEventDataDto get configChanged;

  /// Create a copy of ConfigChangedEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConfigChangedEventEnvelopeDtoImplCopyWith<
    _$ConfigChangedEventEnvelopeDtoImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
