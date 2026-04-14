// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_event_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppPlanEntryDto _$AppPlanEntryDtoFromJson(Map<String, dynamic> json) {
  return _AppPlanEntryDto.fromJson(json);
}

/// @nodoc
mixin _$AppPlanEntryDto {
  @JsonKey(fromJson: _requiredString)
  String get content => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _requiredString)
  String get priority => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _requiredString)
  String get status => throw _privateConstructorUsedError;

  /// Create a copy of AppPlanEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppPlanEntryDtoCopyWith<AppPlanEntryDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppPlanEntryDtoCopyWith<$Res> {
  factory $AppPlanEntryDtoCopyWith(
    AppPlanEntryDto value,
    $Res Function(AppPlanEntryDto) then,
  ) = _$AppPlanEntryDtoCopyWithImpl<$Res, AppPlanEntryDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String content,
    @JsonKey(fromJson: _requiredString) String priority,
    @JsonKey(fromJson: _requiredString) String status,
  });
}

/// @nodoc
class _$AppPlanEntryDtoCopyWithImpl<$Res, $Val extends AppPlanEntryDto>
    implements $AppPlanEntryDtoCopyWith<$Res> {
  _$AppPlanEntryDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppPlanEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? priority = null,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppPlanEntryDtoImplCopyWith<$Res>
    implements $AppPlanEntryDtoCopyWith<$Res> {
  factory _$$AppPlanEntryDtoImplCopyWith(
    _$AppPlanEntryDtoImpl value,
    $Res Function(_$AppPlanEntryDtoImpl) then,
  ) = __$$AppPlanEntryDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String content,
    @JsonKey(fromJson: _requiredString) String priority,
    @JsonKey(fromJson: _requiredString) String status,
  });
}

/// @nodoc
class __$$AppPlanEntryDtoImplCopyWithImpl<$Res>
    extends _$AppPlanEntryDtoCopyWithImpl<$Res, _$AppPlanEntryDtoImpl>
    implements _$$AppPlanEntryDtoImplCopyWith<$Res> {
  __$$AppPlanEntryDtoImplCopyWithImpl(
    _$AppPlanEntryDtoImpl _value,
    $Res Function(_$AppPlanEntryDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppPlanEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? priority = null,
    Object? status = null,
  }) {
    return _then(
      _$AppPlanEntryDtoImpl(
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$AppPlanEntryDtoImpl implements _AppPlanEntryDto {
  const _$AppPlanEntryDtoImpl({
    @JsonKey(fromJson: _requiredString) required this.content,
    @JsonKey(fromJson: _requiredString) required this.priority,
    @JsonKey(fromJson: _requiredString) required this.status,
  });

  factory _$AppPlanEntryDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppPlanEntryDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _requiredString)
  final String content;
  @override
  @JsonKey(fromJson: _requiredString)
  final String priority;
  @override
  @JsonKey(fromJson: _requiredString)
  final String status;

  @override
  String toString() {
    return 'AppPlanEntryDto(content: $content, priority: $priority, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppPlanEntryDtoImpl &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, content, priority, status);

  /// Create a copy of AppPlanEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppPlanEntryDtoImplCopyWith<_$AppPlanEntryDtoImpl> get copyWith =>
      __$$AppPlanEntryDtoImplCopyWithImpl<_$AppPlanEntryDtoImpl>(
        this,
        _$identity,
      );
}

abstract class _AppPlanEntryDto implements AppPlanEntryDto {
  const factory _AppPlanEntryDto({
    @JsonKey(fromJson: _requiredString) required final String content,
    @JsonKey(fromJson: _requiredString) required final String priority,
    @JsonKey(fromJson: _requiredString) required final String status,
  }) = _$AppPlanEntryDtoImpl;

  factory _AppPlanEntryDto.fromJson(Map<String, dynamic> json) =
      _$AppPlanEntryDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _requiredString)
  String get content;
  @override
  @JsonKey(fromJson: _requiredString)
  String get priority;
  @override
  @JsonKey(fromJson: _requiredString)
  String get status;

  /// Create a copy of AppPlanEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppPlanEntryDtoImplCopyWith<_$AppPlanEntryDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppPlanUpdateDto _$AppPlanUpdateDtoFromJson(Map<String, dynamic> json) {
  return _AppPlanUpdateDto.fromJson(json);
}

/// @nodoc
mixin _$AppPlanUpdateDto {
  @JsonKey(fromJson: _appPlanEntryListFromJson)
  List<AppPlanEntryDto> get entries => throw _privateConstructorUsedError;

  /// Create a copy of AppPlanUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppPlanUpdateDtoCopyWith<AppPlanUpdateDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppPlanUpdateDtoCopyWith<$Res> {
  factory $AppPlanUpdateDtoCopyWith(
    AppPlanUpdateDto value,
    $Res Function(AppPlanUpdateDto) then,
  ) = _$AppPlanUpdateDtoCopyWithImpl<$Res, AppPlanUpdateDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _appPlanEntryListFromJson) List<AppPlanEntryDto> entries,
  });
}

/// @nodoc
class _$AppPlanUpdateDtoCopyWithImpl<$Res, $Val extends AppPlanUpdateDto>
    implements $AppPlanUpdateDtoCopyWith<$Res> {
  _$AppPlanUpdateDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppPlanUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? entries = null}) {
    return _then(
      _value.copyWith(
            entries: null == entries
                ? _value.entries
                : entries // ignore: cast_nullable_to_non_nullable
                      as List<AppPlanEntryDto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppPlanUpdateDtoImplCopyWith<$Res>
    implements $AppPlanUpdateDtoCopyWith<$Res> {
  factory _$$AppPlanUpdateDtoImplCopyWith(
    _$AppPlanUpdateDtoImpl value,
    $Res Function(_$AppPlanUpdateDtoImpl) then,
  ) = __$$AppPlanUpdateDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _appPlanEntryListFromJson) List<AppPlanEntryDto> entries,
  });
}

/// @nodoc
class __$$AppPlanUpdateDtoImplCopyWithImpl<$Res>
    extends _$AppPlanUpdateDtoCopyWithImpl<$Res, _$AppPlanUpdateDtoImpl>
    implements _$$AppPlanUpdateDtoImplCopyWith<$Res> {
  __$$AppPlanUpdateDtoImplCopyWithImpl(
    _$AppPlanUpdateDtoImpl _value,
    $Res Function(_$AppPlanUpdateDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppPlanUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? entries = null}) {
    return _then(
      _$AppPlanUpdateDtoImpl(
        entries: null == entries
            ? _value._entries
            : entries // ignore: cast_nullable_to_non_nullable
                  as List<AppPlanEntryDto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$AppPlanUpdateDtoImpl implements _AppPlanUpdateDto {
  const _$AppPlanUpdateDtoImpl({
    @JsonKey(fromJson: _appPlanEntryListFromJson)
    final List<AppPlanEntryDto> entries = const <AppPlanEntryDto>[],
  }) : _entries = entries;

  factory _$AppPlanUpdateDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppPlanUpdateDtoImplFromJson(json);

  final List<AppPlanEntryDto> _entries;
  @override
  @JsonKey(fromJson: _appPlanEntryListFromJson)
  List<AppPlanEntryDto> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  String toString() {
    return 'AppPlanUpdateDto(entries: $entries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppPlanUpdateDtoImpl &&
            const DeepCollectionEquality().equals(other._entries, _entries));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_entries));

  /// Create a copy of AppPlanUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppPlanUpdateDtoImplCopyWith<_$AppPlanUpdateDtoImpl> get copyWith =>
      __$$AppPlanUpdateDtoImplCopyWithImpl<_$AppPlanUpdateDtoImpl>(
        this,
        _$identity,
      );
}

abstract class _AppPlanUpdateDto implements AppPlanUpdateDto {
  const factory _AppPlanUpdateDto({
    @JsonKey(fromJson: _appPlanEntryListFromJson)
    final List<AppPlanEntryDto> entries,
  }) = _$AppPlanUpdateDtoImpl;

  factory _AppPlanUpdateDto.fromJson(Map<String, dynamic> json) =
      _$AppPlanUpdateDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _appPlanEntryListFromJson)
  List<AppPlanEntryDto> get entries;

  /// Create a copy of AppPlanUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppPlanUpdateDtoImplCopyWith<_$AppPlanUpdateDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanWireDto _$PlanWireDtoFromJson(Map<String, dynamic> json) {
  return _PlanWireDto.fromJson(json);
}

/// @nodoc
mixin _$PlanWireDto {
  @JsonKey(fromJson: _appPlanUpdateFromJson)
  AppPlanUpdateDto get app => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableAcpPlanUpdate)
  AcpPlanUpdateDto? get acp => throw _privateConstructorUsedError;

  /// Create a copy of PlanWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanWireDtoCopyWith<PlanWireDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanWireDtoCopyWith<$Res> {
  factory $PlanWireDtoCopyWith(
    PlanWireDto value,
    $Res Function(PlanWireDto) then,
  ) = _$PlanWireDtoCopyWithImpl<$Res, PlanWireDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _appPlanUpdateFromJson) AppPlanUpdateDto app,
    @JsonKey(fromJson: _nullableAcpPlanUpdate) AcpPlanUpdateDto? acp,
  });

  $AppPlanUpdateDtoCopyWith<$Res> get app;
}

/// @nodoc
class _$PlanWireDtoCopyWithImpl<$Res, $Val extends PlanWireDto>
    implements $PlanWireDtoCopyWith<$Res> {
  _$PlanWireDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _value.copyWith(
            app: null == app
                ? _value.app
                : app // ignore: cast_nullable_to_non_nullable
                      as AppPlanUpdateDto,
            acp: freezed == acp
                ? _value.acp
                : acp // ignore: cast_nullable_to_non_nullable
                      as AcpPlanUpdateDto?,
          )
          as $Val,
    );
  }

  /// Create a copy of PlanWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AppPlanUpdateDtoCopyWith<$Res> get app {
    return $AppPlanUpdateDtoCopyWith<$Res>(_value.app, (value) {
      return _then(_value.copyWith(app: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlanWireDtoImplCopyWith<$Res>
    implements $PlanWireDtoCopyWith<$Res> {
  factory _$$PlanWireDtoImplCopyWith(
    _$PlanWireDtoImpl value,
    $Res Function(_$PlanWireDtoImpl) then,
  ) = __$$PlanWireDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _appPlanUpdateFromJson) AppPlanUpdateDto app,
    @JsonKey(fromJson: _nullableAcpPlanUpdate) AcpPlanUpdateDto? acp,
  });

  @override
  $AppPlanUpdateDtoCopyWith<$Res> get app;
}

/// @nodoc
class __$$PlanWireDtoImplCopyWithImpl<$Res>
    extends _$PlanWireDtoCopyWithImpl<$Res, _$PlanWireDtoImpl>
    implements _$$PlanWireDtoImplCopyWith<$Res> {
  __$$PlanWireDtoImplCopyWithImpl(
    _$PlanWireDtoImpl _value,
    $Res Function(_$PlanWireDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanWireDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? app = null, Object? acp = freezed}) {
    return _then(
      _$PlanWireDtoImpl(
        app: null == app
            ? _value.app
            : app // ignore: cast_nullable_to_non_nullable
                  as AppPlanUpdateDto,
        acp: freezed == acp
            ? _value.acp
            : acp // ignore: cast_nullable_to_non_nullable
                  as AcpPlanUpdateDto?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$PlanWireDtoImpl implements _PlanWireDto {
  const _$PlanWireDtoImpl({
    @JsonKey(fromJson: _appPlanUpdateFromJson) required this.app,
    @JsonKey(fromJson: _nullableAcpPlanUpdate) this.acp,
  });

  factory _$PlanWireDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanWireDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _appPlanUpdateFromJson)
  final AppPlanUpdateDto app;
  @override
  @JsonKey(fromJson: _nullableAcpPlanUpdate)
  final AcpPlanUpdateDto? acp;

  @override
  String toString() {
    return 'PlanWireDto(app: $app, acp: $acp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanWireDtoImpl &&
            (identical(other.app, app) || other.app == app) &&
            (identical(other.acp, acp) || other.acp == acp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, app, acp);

  /// Create a copy of PlanWireDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanWireDtoImplCopyWith<_$PlanWireDtoImpl> get copyWith =>
      __$$PlanWireDtoImplCopyWithImpl<_$PlanWireDtoImpl>(this, _$identity);
}

abstract class _PlanWireDto implements PlanWireDto {
  const factory _PlanWireDto({
    @JsonKey(fromJson: _appPlanUpdateFromJson)
    required final AppPlanUpdateDto app,
    @JsonKey(fromJson: _nullableAcpPlanUpdate) final AcpPlanUpdateDto? acp,
  }) = _$PlanWireDtoImpl;

  factory _PlanWireDto.fromJson(Map<String, dynamic> json) =
      _$PlanWireDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _appPlanUpdateFromJson)
  AppPlanUpdateDto get app;
  @override
  @JsonKey(fromJson: _nullableAcpPlanUpdate)
  AcpPlanUpdateDto? get acp;

  /// Create a copy of PlanWireDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanWireDtoImplCopyWith<_$PlanWireDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlanEventEnvelopeDto _$PlanEventEnvelopeDtoFromJson(Map<String, dynamic> json) {
  return _PlanEventEnvelopeDto.fromJson(json);
}

/// @nodoc
mixin _$PlanEventEnvelopeDto {
  @JsonKey(fromJson: _requiredString)
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'sessionId')
  String? get sessionId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  DateTime? get at => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _planWireFromJson)
  PlanWireDto get plan => throw _privateConstructorUsedError;

  /// Create a copy of PlanEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanEventEnvelopeDtoCopyWith<PlanEventEnvelopeDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanEventEnvelopeDtoCopyWith<$Res> {
  factory $PlanEventEnvelopeDtoCopyWith(
    PlanEventEnvelopeDto value,
    $Res Function(PlanEventEnvelopeDto) then,
  ) = _$PlanEventEnvelopeDtoCopyWithImpl<$Res, PlanEventEnvelopeDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(fromJson: _planWireFromJson) PlanWireDto plan,
  });

  $PlanWireDtoCopyWith<$Res> get plan;
}

/// @nodoc
class _$PlanEventEnvelopeDtoCopyWithImpl<
  $Res,
  $Val extends PlanEventEnvelopeDto
>
    implements $PlanEventEnvelopeDtoCopyWith<$Res> {
  _$PlanEventEnvelopeDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? plan = null,
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
            plan: null == plan
                ? _value.plan
                : plan // ignore: cast_nullable_to_non_nullable
                      as PlanWireDto,
          )
          as $Val,
    );
  }

  /// Create a copy of PlanEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PlanWireDtoCopyWith<$Res> get plan {
    return $PlanWireDtoCopyWith<$Res>(_value.plan, (value) {
      return _then(_value.copyWith(plan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlanEventEnvelopeDtoImplCopyWith<$Res>
    implements $PlanEventEnvelopeDtoCopyWith<$Res> {
  factory _$$PlanEventEnvelopeDtoImplCopyWith(
    _$PlanEventEnvelopeDtoImpl value,
    $Res Function(_$PlanEventEnvelopeDtoImpl) then,
  ) = __$$PlanEventEnvelopeDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String type,
    @JsonKey(name: 'sessionId') String? sessionId,
    int seq,
    DateTime? at,
    @JsonKey(fromJson: _planWireFromJson) PlanWireDto plan,
  });

  @override
  $PlanWireDtoCopyWith<$Res> get plan;
}

/// @nodoc
class __$$PlanEventEnvelopeDtoImplCopyWithImpl<$Res>
    extends _$PlanEventEnvelopeDtoCopyWithImpl<$Res, _$PlanEventEnvelopeDtoImpl>
    implements _$$PlanEventEnvelopeDtoImplCopyWith<$Res> {
  __$$PlanEventEnvelopeDtoImplCopyWithImpl(
    _$PlanEventEnvelopeDtoImpl _value,
    $Res Function(_$PlanEventEnvelopeDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlanEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? sessionId = freezed,
    Object? seq = null,
    Object? at = freezed,
    Object? plan = null,
  }) {
    return _then(
      _$PlanEventEnvelopeDtoImpl(
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
        plan: null == plan
            ? _value.plan
            : plan // ignore: cast_nullable_to_non_nullable
                  as PlanWireDto,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable(createToJson: false)
class _$PlanEventEnvelopeDtoImpl implements _PlanEventEnvelopeDto {
  const _$PlanEventEnvelopeDtoImpl({
    @JsonKey(fromJson: _requiredString) required this.type,
    @JsonKey(name: 'sessionId') this.sessionId,
    this.seq = 0,
    this.at,
    @JsonKey(fromJson: _planWireFromJson) required this.plan,
  });

  factory _$PlanEventEnvelopeDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanEventEnvelopeDtoImplFromJson(json);

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
  @JsonKey(fromJson: _planWireFromJson)
  final PlanWireDto plan;

  @override
  String toString() {
    return 'PlanEventEnvelopeDto(type: $type, sessionId: $sessionId, seq: $seq, at: $at, plan: $plan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanEventEnvelopeDtoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.at, at) || other.at == at) &&
            (identical(other.plan, plan) || other.plan == plan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, sessionId, seq, at, plan);

  /// Create a copy of PlanEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanEventEnvelopeDtoImplCopyWith<_$PlanEventEnvelopeDtoImpl>
  get copyWith =>
      __$$PlanEventEnvelopeDtoImplCopyWithImpl<_$PlanEventEnvelopeDtoImpl>(
        this,
        _$identity,
      );
}

abstract class _PlanEventEnvelopeDto implements PlanEventEnvelopeDto {
  const factory _PlanEventEnvelopeDto({
    @JsonKey(fromJson: _requiredString) required final String type,
    @JsonKey(name: 'sessionId') final String? sessionId,
    final int seq,
    final DateTime? at,
    @JsonKey(fromJson: _planWireFromJson) required final PlanWireDto plan,
  }) = _$PlanEventEnvelopeDtoImpl;

  factory _PlanEventEnvelopeDto.fromJson(Map<String, dynamic> json) =
      _$PlanEventEnvelopeDtoImpl.fromJson;

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
  @JsonKey(fromJson: _planWireFromJson)
  PlanWireDto get plan;

  /// Create a copy of PlanEventEnvelopeDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanEventEnvelopeDtoImplCopyWith<_$PlanEventEnvelopeDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
