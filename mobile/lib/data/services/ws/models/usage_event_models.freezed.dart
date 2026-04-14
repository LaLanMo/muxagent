// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'usage_event_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppUsageUpdateDto _$AppUsageUpdateDtoFromJson(Map<String, dynamic> json) {
  return _AppUsageUpdateDto.fromJson(json);
}

/// @nodoc
mixin _$AppUsageUpdateDto {
  @JsonKey(name: 'contextUsed', fromJson: _requiredNum)
  num get contextUsed => throw _privateConstructorUsedError;
  @JsonKey(name: 'contextSize', fromJson: _requiredNum)
  num get contextSize => throw _privateConstructorUsedError;
  @JsonKey(name: 'costAmount', fromJson: _nullableDouble)
  double? get costAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'costCurrency', fromJson: _nullableString)
  String? get costCurrency => throw _privateConstructorUsedError;

  /// Create a copy of AppUsageUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUsageUpdateDtoCopyWith<AppUsageUpdateDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUsageUpdateDtoCopyWith<$Res> {
  factory $AppUsageUpdateDtoCopyWith(
    AppUsageUpdateDto value,
    $Res Function(AppUsageUpdateDto) then,
  ) = _$AppUsageUpdateDtoCopyWithImpl<$Res, AppUsageUpdateDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'contextUsed', fromJson: _requiredNum) num contextUsed,
    @JsonKey(name: 'contextSize', fromJson: _requiredNum) num contextSize,
    @JsonKey(name: 'costAmount', fromJson: _nullableDouble) double? costAmount,
    @JsonKey(name: 'costCurrency', fromJson: _nullableString)
    String? costCurrency,
  });
}

/// @nodoc
class _$AppUsageUpdateDtoCopyWithImpl<$Res, $Val extends AppUsageUpdateDto>
    implements $AppUsageUpdateDtoCopyWith<$Res> {
  _$AppUsageUpdateDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUsageUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contextUsed = null,
    Object? contextSize = null,
    Object? costAmount = freezed,
    Object? costCurrency = freezed,
  }) {
    return _then(
      _value.copyWith(
            contextUsed: null == contextUsed
                ? _value.contextUsed
                : contextUsed // ignore: cast_nullable_to_non_nullable
                      as num,
            contextSize: null == contextSize
                ? _value.contextSize
                : contextSize // ignore: cast_nullable_to_non_nullable
                      as num,
            costAmount: freezed == costAmount
                ? _value.costAmount
                : costAmount // ignore: cast_nullable_to_non_nullable
                      as double?,
            costCurrency: freezed == costCurrency
                ? _value.costCurrency
                : costCurrency // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppUsageUpdateDtoImplCopyWith<$Res>
    implements $AppUsageUpdateDtoCopyWith<$Res> {
  factory _$$AppUsageUpdateDtoImplCopyWith(
    _$AppUsageUpdateDtoImpl value,
    $Res Function(_$AppUsageUpdateDtoImpl) then,
  ) = __$$AppUsageUpdateDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'contextUsed', fromJson: _requiredNum) num contextUsed,
    @JsonKey(name: 'contextSize', fromJson: _requiredNum) num contextSize,
    @JsonKey(name: 'costAmount', fromJson: _nullableDouble) double? costAmount,
    @JsonKey(name: 'costCurrency', fromJson: _nullableString)
    String? costCurrency,
  });
}

/// @nodoc
class __$$AppUsageUpdateDtoImplCopyWithImpl<$Res>
    extends _$AppUsageUpdateDtoCopyWithImpl<$Res, _$AppUsageUpdateDtoImpl>
    implements _$$AppUsageUpdateDtoImplCopyWith<$Res> {
  __$$AppUsageUpdateDtoImplCopyWithImpl(
    _$AppUsageUpdateDtoImpl _value,
    $Res Function(_$AppUsageUpdateDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUsageUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contextUsed = null,
    Object? contextSize = null,
    Object? costAmount = freezed,
    Object? costCurrency = freezed,
  }) {
    return _then(
      _$AppUsageUpdateDtoImpl(
        contextUsed: null == contextUsed
            ? _value.contextUsed
            : contextUsed // ignore: cast_nullable_to_non_nullable
                  as num,
        contextSize: null == contextSize
            ? _value.contextSize
            : contextSize // ignore: cast_nullable_to_non_nullable
                  as num,
        costAmount: freezed == costAmount
            ? _value.costAmount
            : costAmount // ignore: cast_nullable_to_non_nullable
                  as double?,
        costCurrency: freezed == costCurrency
            ? _value.costCurrency
            : costCurrency // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$AppUsageUpdateDtoImpl implements _AppUsageUpdateDto {
  const _$AppUsageUpdateDtoImpl({
    @JsonKey(name: 'contextUsed', fromJson: _requiredNum)
    required this.contextUsed,
    @JsonKey(name: 'contextSize', fromJson: _requiredNum)
    required this.contextSize,
    @JsonKey(name: 'costAmount', fromJson: _nullableDouble) this.costAmount,
    @JsonKey(name: 'costCurrency', fromJson: _nullableString) this.costCurrency,
  });

  factory _$AppUsageUpdateDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUsageUpdateDtoImplFromJson(json);

  @override
  @JsonKey(name: 'contextUsed', fromJson: _requiredNum)
  final num contextUsed;
  @override
  @JsonKey(name: 'contextSize', fromJson: _requiredNum)
  final num contextSize;
  @override
  @JsonKey(name: 'costAmount', fromJson: _nullableDouble)
  final double? costAmount;
  @override
  @JsonKey(name: 'costCurrency', fromJson: _nullableString)
  final String? costCurrency;

  @override
  String toString() {
    return 'AppUsageUpdateDto(contextUsed: $contextUsed, contextSize: $contextSize, costAmount: $costAmount, costCurrency: $costCurrency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUsageUpdateDtoImpl &&
            (identical(other.contextUsed, contextUsed) ||
                other.contextUsed == contextUsed) &&
            (identical(other.contextSize, contextSize) ||
                other.contextSize == contextSize) &&
            (identical(other.costAmount, costAmount) ||
                other.costAmount == costAmount) &&
            (identical(other.costCurrency, costCurrency) ||
                other.costCurrency == costCurrency));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    contextUsed,
    contextSize,
    costAmount,
    costCurrency,
  );

  /// Create a copy of AppUsageUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUsageUpdateDtoImplCopyWith<_$AppUsageUpdateDtoImpl> get copyWith =>
      __$$AppUsageUpdateDtoImplCopyWithImpl<_$AppUsageUpdateDtoImpl>(
        this,
        _$identity,
      );
}

abstract class _AppUsageUpdateDto implements AppUsageUpdateDto {
  const factory _AppUsageUpdateDto({
    @JsonKey(name: 'contextUsed', fromJson: _requiredNum)
    required final num contextUsed,
    @JsonKey(name: 'contextSize', fromJson: _requiredNum)
    required final num contextSize,
    @JsonKey(name: 'costAmount', fromJson: _nullableDouble)
    final double? costAmount,
    @JsonKey(name: 'costCurrency', fromJson: _nullableString)
    final String? costCurrency,
  }) = _$AppUsageUpdateDtoImpl;

  factory _AppUsageUpdateDto.fromJson(Map<String, dynamic> json) =
      _$AppUsageUpdateDtoImpl.fromJson;

  @override
  @JsonKey(name: 'contextUsed', fromJson: _requiredNum)
  num get contextUsed;
  @override
  @JsonKey(name: 'contextSize', fromJson: _requiredNum)
  num get contextSize;
  @override
  @JsonKey(name: 'costAmount', fromJson: _nullableDouble)
  double? get costAmount;
  @override
  @JsonKey(name: 'costCurrency', fromJson: _nullableString)
  String? get costCurrency;

  /// Create a copy of AppUsageUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUsageUpdateDtoImplCopyWith<_$AppUsageUpdateDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UsageWireDto _$UsageWireDtoFromJson(Map<String, dynamic> json) {
  return _UsageWireDto.fromJson(json);
}

/// @nodoc
mixin _$UsageWireDto {
  @JsonKey(fromJson: _appUsageFromJson)
  AppUsageUpdateDto get app => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableAcpUsage)
  AcpUsageUpdateDto? get acp => throw _privateConstructorUsedError;

  /// Create a copy of UsageWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UsageWireDtoCopyWith<UsageWireDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsageWireDtoCopyWith<$Res> {
  factory $UsageWireDtoCopyWith(
    UsageWireDto value,
    $Res Function(UsageWireDto) then,
  ) = _$UsageWireDtoCopyWithImpl<$Res, UsageWireDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _appUsageFromJson) AppUsageUpdateDto app,
    @JsonKey(fromJson: _nullableAcpUsage) AcpUsageUpdateDto? acp,
  });

  $AppUsageUpdateDtoCopyWith<$Res> get app;
}

/// @nodoc
class _$UsageWireDtoCopyWithImpl<$Res, $Val extends UsageWireDto>
    implements $UsageWireDtoCopyWith<$Res> {
  _$UsageWireDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UsageWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _value.copyWith(
            app: null == app
                ? _value.app
                : app // ignore: cast_nullable_to_non_nullable
                      as AppUsageUpdateDto,
            acp: freezed == acp
                ? _value.acp
                : acp // ignore: cast_nullable_to_non_nullable
                      as AcpUsageUpdateDto?,
          )
          as $Val,
    );
  }

  /// Create a copy of UsageWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppUsageUpdateDtoCopyWith<$Res> get app {
    return $AppUsageUpdateDtoCopyWith<$Res>(_value.app, (value) {
      return _then(_value.copyWith(app: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UsageWireDtoImplCopyWith<$Res>
    implements $UsageWireDtoCopyWith<$Res> {
  factory _$$UsageWireDtoImplCopyWith(
    _$UsageWireDtoImpl value,
    $Res Function(_$UsageWireDtoImpl) then,
  ) = __$$UsageWireDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _appUsageFromJson) AppUsageUpdateDto app,
    @JsonKey(fromJson: _nullableAcpUsage) AcpUsageUpdateDto? acp,
  });

  @override
  $AppUsageUpdateDtoCopyWith<$Res> get app;
}

/// @nodoc
class __$$UsageWireDtoImplCopyWithImpl<$Res>
    extends _$UsageWireDtoCopyWithImpl<$Res, _$UsageWireDtoImpl>
    implements _$$UsageWireDtoImplCopyWith<$Res> {
  __$$UsageWireDtoImplCopyWithImpl(
    _$UsageWireDtoImpl _value,
    $Res Function(_$UsageWireDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UsageWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _$UsageWireDtoImpl(
        app: null == app
            ? _value.app
            : app // ignore: cast_nullable_to_non_nullable
                  as AppUsageUpdateDto,
        acp: freezed == acp
            ? _value.acp
            : acp // ignore: cast_nullable_to_non_nullable
                  as AcpUsageUpdateDto?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$UsageWireDtoImpl implements _UsageWireDto {
  const _$UsageWireDtoImpl({
    @JsonKey(fromJson: _appUsageFromJson) required this.app,
    @JsonKey(fromJson: _nullableAcpUsage) this.acp,
  });

  factory _$UsageWireDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$UsageWireDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _appUsageFromJson)
  final AppUsageUpdateDto app;
  @override
  @JsonKey(fromJson: _nullableAcpUsage)
  final AcpUsageUpdateDto? acp;

  @override
  String toString() {
    return 'UsageWireDto(app: $app, acp: $acp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsageWireDtoImpl &&
            (identical(other.app, app) || other.app == app) &&
            (identical(other.acp, acp) || other.acp == acp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, app, acp);

  /// Create a copy of UsageWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageWireDtoImplCopyWith<_$UsageWireDtoImpl> get copyWith =>
      __$$UsageWireDtoImplCopyWithImpl<_$UsageWireDtoImpl>(this, _$identity);
}

abstract class _UsageWireDto implements UsageWireDto {
  const factory _UsageWireDto({
    @JsonKey(fromJson: _appUsageFromJson) required final AppUsageUpdateDto app,
    @JsonKey(fromJson: _nullableAcpUsage) final AcpUsageUpdateDto? acp,
  }) = _$UsageWireDtoImpl;

  factory _UsageWireDto.fromJson(Map<String, dynamic> json) =
      _$UsageWireDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _appUsageFromJson)
  AppUsageUpdateDto get app;
  @override
  @JsonKey(fromJson: _nullableAcpUsage)
  AcpUsageUpdateDto? get acp;

  /// Create a copy of UsageWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsageWireDtoImplCopyWith<_$UsageWireDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UsageEventEnvelopeDto _$UsageEventEnvelopeDtoFromJson(
  Map<String, dynamic> json,
) {
  return _UsageEventEnvelopeDto.fromJson(json);
}

/// @nodoc
mixin _$UsageEventEnvelopeDto {
  @JsonKey(fromJson: _requiredString)
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String? get sessionId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  DateTime? get at => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _usageWireFromJson)
  UsageWireDto get usage => throw _privateConstructorUsedError;

  /// Create a copy of UsageEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UsageEventEnvelopeDtoCopyWith<UsageEventEnvelopeDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsageEventEnvelopeDtoCopyWith<$Res> {
  factory $UsageEventEnvelopeDtoCopyWith(
    UsageEventEnvelopeDto value,
    $Res Function(UsageEventEnvelopeDto) then,
  ) = _$UsageEventEnvelopeDtoCopyWithImpl<$Res, UsageEventEnvelopeDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(fromJson: _usageWireFromJson) UsageWireDto usage,
  });

  $UsageWireDtoCopyWith<$Res> get usage;
}

/// @nodoc
class _$UsageEventEnvelopeDtoCopyWithImpl<
  $Res,
  $Val extends UsageEventEnvelopeDto
>
    implements $UsageEventEnvelopeDtoCopyWith<$Res> {
  _$UsageEventEnvelopeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UsageEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? usage = null,
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
            usage: null == usage
                ? _value.usage
                : usage // ignore: cast_nullable_to_non_nullable
                      as UsageWireDto,
          )
          as $Val,
    );
  }

  /// Create a copy of UsageEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UsageWireDtoCopyWith<$Res> get usage {
    return $UsageWireDtoCopyWith<$Res>(_value.usage, (value) {
      return _then(_value.copyWith(usage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UsageEventEnvelopeDtoImplCopyWith<$Res>
    implements $UsageEventEnvelopeDtoCopyWith<$Res> {
  factory _$$UsageEventEnvelopeDtoImplCopyWith(
    _$UsageEventEnvelopeDtoImpl value,
    $Res Function(_$UsageEventEnvelopeDtoImpl) then,
  ) = __$$UsageEventEnvelopeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(fromJson: _usageWireFromJson) UsageWireDto usage,
  });

  @override
  $UsageWireDtoCopyWith<$Res> get usage;
}

/// @nodoc
class __$$UsageEventEnvelopeDtoImplCopyWithImpl<$Res>
    extends
        _$UsageEventEnvelopeDtoCopyWithImpl<$Res, _$UsageEventEnvelopeDtoImpl>
    implements _$$UsageEventEnvelopeDtoImplCopyWith<$Res> {
  __$$UsageEventEnvelopeDtoImplCopyWithImpl(
    _$UsageEventEnvelopeDtoImpl _value,
    $Res Function(_$UsageEventEnvelopeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UsageEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? usage = null,
  }) {
    return _then(
      _$UsageEventEnvelopeDtoImpl(
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
        usage: null == usage
            ? _value.usage
            : usage // ignore: cast_nullable_to_non_nullable
                  as UsageWireDto,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$UsageEventEnvelopeDtoImpl implements _UsageEventEnvelopeDto {
  const _$UsageEventEnvelopeDtoImpl({
    @JsonKey(fromJson: _requiredString) required this.type,
    @JsonKey(name: 'sessionId') this.sessionId,
    this.seq = 0,
    this.at,
    @JsonKey(fromJson: _usageWireFromJson) required this.usage,
  });

  factory _$UsageEventEnvelopeDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$UsageEventEnvelopeDtoImplFromJson(json);

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
  @JsonKey(fromJson: _usageWireFromJson)
  final UsageWireDto usage;

  @override
  String toString() {
    return 'UsageEventEnvelopeDto(type: $type, sessionId: $sessionId, seq: $seq, at: $at, usage: $usage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsageEventEnvelopeDtoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.usage, usage) || other.usage == usage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, sessionId, seq, at, usage);

  /// Create a copy of UsageEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageEventEnvelopeDtoImplCopyWith<_$UsageEventEnvelopeDtoImpl>
  get copyWith =>
      __$$UsageEventEnvelopeDtoImplCopyWithImpl<_$UsageEventEnvelopeDtoImpl>(
        this,
        _$identity,
      );
}

abstract class _UsageEventEnvelopeDto implements UsageEventEnvelopeDto {
  const factory _UsageEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required final String type,
    @JsonKey(name: 'sessionId') final String? sessionId,
    final int seq,
    final DateTime? at,
    @JsonKey(fromJson: _usageWireFromJson) required final UsageWireDto usage,
  }) = _$UsageEventEnvelopeDtoImpl;

  factory _UsageEventEnvelopeDto.fromJson(Map<String, dynamic> json) =
      _$UsageEventEnvelopeDtoImpl.fromJson;

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
  @JsonKey(fromJson: _usageWireFromJson)
  UsageWireDto get usage;

  /// Create a copy of UsageEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsageEventEnvelopeDtoImplCopyWith<_$UsageEventEnvelopeDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
