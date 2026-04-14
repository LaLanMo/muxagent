// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rpc_result_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$RpcResyncResponseDto {
  @JsonKey(fromJson: _requiredObjectList)
  List<Map<String, dynamic>> get events => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _requiredResyncStatus)
  RpcResyncStatusDto get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
  int get streamEpoch => throw _privateConstructorUsedError;
  @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
  int get replayedThroughSeq => throw _privateConstructorUsedError;

  /// Create a copy of RpcResyncResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcResyncResponseDtoCopyWith<RpcResyncResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcResyncResponseDtoCopyWith<$Res> {
  factory $RpcResyncResponseDtoCopyWith(
    RpcResyncResponseDto value,
    $Res Function(RpcResyncResponseDto) then,
  ) = _$RpcResyncResponseDtoCopyWithImpl<$Res, RpcResyncResponseDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredObjectList) List<Map<String, dynamic>> events,
    @JsonKey(fromJson: _requiredResyncStatus) RpcResyncStatusDto status,
    @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
    int streamEpoch,
    @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
    int replayedThroughSeq,
  });
}

/// @nodoc
class _$RpcResyncResponseDtoCopyWithImpl<
  $Res,
  $Val extends RpcResyncResponseDto
>
    implements $RpcResyncResponseDtoCopyWith<$Res> {
  _$RpcResyncResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcResyncResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? events = null,
    Object? status = null,
    Object? streamEpoch = null,
    Object? replayedThroughSeq = null,
  }) {
    return _then(
      _value.copyWith(
            events: null == events
                ? _value.events
                : events // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as RpcResyncStatusDto,
            streamEpoch: null == streamEpoch
                ? _value.streamEpoch
                : streamEpoch // ignore: cast_nullable_to_non_nullable
                      as int,
            replayedThroughSeq: null == replayedThroughSeq
                ? _value.replayedThroughSeq
                : replayedThroughSeq // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcResyncResponseDtoImplCopyWith<$Res>
    implements $RpcResyncResponseDtoCopyWith<$Res> {
  factory _$$RpcResyncResponseDtoImplCopyWith(
    _$RpcResyncResponseDtoImpl value,
    $Res Function(_$RpcResyncResponseDtoImpl) then,
  ) = __$$RpcResyncResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredObjectList) List<Map<String, dynamic>> events,
    @JsonKey(fromJson: _requiredResyncStatus) RpcResyncStatusDto status,
    @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
    int streamEpoch,
    @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
    int replayedThroughSeq,
  });
}

/// @nodoc
class __$$RpcResyncResponseDtoImplCopyWithImpl<$Res>
    extends _$RpcResyncResponseDtoCopyWithImpl<$Res, _$RpcResyncResponseDtoImpl>
    implements _$$RpcResyncResponseDtoImplCopyWith<$Res> {
  __$$RpcResyncResponseDtoImplCopyWithImpl(
    _$RpcResyncResponseDtoImpl _value,
    $Res Function(_$RpcResyncResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcResyncResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? events = null,
    Object? status = null,
    Object? streamEpoch = null,
    Object? replayedThroughSeq = null,
  }) {
    return _then(
      _$RpcResyncResponseDtoImpl(
        events: null == events
            ? _value._events
            : events // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as RpcResyncStatusDto,
        streamEpoch: null == streamEpoch
            ? _value.streamEpoch
            : streamEpoch // ignore: cast_nullable_to_non_nullable
                  as int,
        replayedThroughSeq: null == replayedThroughSeq
            ? _value.replayedThroughSeq
            : replayedThroughSeq // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$RpcResyncResponseDtoImpl implements _RpcResyncResponseDto {
  const _$RpcResyncResponseDtoImpl({
    @JsonKey(fromJson: _requiredObjectList)
    required final List<Map<String, dynamic>> events,
    @JsonKey(fromJson: _requiredResyncStatus) required this.status,
    @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
    required this.streamEpoch,
    @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
    required this.replayedThroughSeq,
  }) : _events = events;

  final List<Map<String, dynamic>> _events;
  @override
  @JsonKey(fromJson: _requiredObjectList)
  List<Map<String, dynamic>> get events {
    if (_events is EqualUnmodifiableListView) return _events;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_events);
  }

  @override
  @JsonKey(fromJson: _requiredResyncStatus)
  final RpcResyncStatusDto status;
  @override
  @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
  final int streamEpoch;
  @override
  @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
  final int replayedThroughSeq;

  @override
  String toString() {
    return 'RpcResyncResponseDto(events: $events, status: $status, streamEpoch: $streamEpoch, replayedThroughSeq: $replayedThroughSeq)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcResyncResponseDtoImpl &&
            const DeepCollectionEquality().equals(other._events, _events) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.streamEpoch, streamEpoch) ||
                other.streamEpoch == streamEpoch) &&
            (identical(other.replayedThroughSeq, replayedThroughSeq) ||
                other.replayedThroughSeq == replayedThroughSeq));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_events),
    status,
    streamEpoch,
    replayedThroughSeq,
  );

  /// Create a copy of RpcResyncResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcResyncResponseDtoImplCopyWith<_$RpcResyncResponseDtoImpl>
  get copyWith =>
      __$$RpcResyncResponseDtoImplCopyWithImpl<_$RpcResyncResponseDtoImpl>(
        this,
        _$identity,
      );
}

abstract class _RpcResyncResponseDto implements RpcResyncResponseDto {
  const factory _RpcResyncResponseDto({
    @JsonKey(fromJson: _requiredObjectList)
    required final List<Map<String, dynamic>> events,
    @JsonKey(fromJson: _requiredResyncStatus)
    required final RpcResyncStatusDto status,
    @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
    required final int streamEpoch,
    @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
    required final int replayedThroughSeq,
  }) = _$RpcResyncResponseDtoImpl;

  @override
  @JsonKey(fromJson: _requiredObjectList)
  List<Map<String, dynamic>> get events;
  @override
  @JsonKey(fromJson: _requiredResyncStatus)
  RpcResyncStatusDto get status;
  @override
  @JsonKey(name: 'streamEpoch', fromJson: _requiredPositiveInt)
  int get streamEpoch;
  @override
  @JsonKey(name: 'replayedThroughSeq', fromJson: _requiredInt)
  int get replayedThroughSeq;

  /// Create a copy of RpcResyncResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcResyncResponseDtoImplCopyWith<_$RpcResyncResponseDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

RpcOkResponseDto _$RpcOkResponseDtoFromJson(Map<String, dynamic> json) {
  return _RpcOkResponseDto.fromJson(json);
}

/// @nodoc
mixin _$RpcOkResponseDto {
  @JsonKey(fromJson: _requiredBool)
  bool get ok => throw _privateConstructorUsedError;

  /// Serializes this RpcOkResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcOkResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcOkResponseDtoCopyWith<RpcOkResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcOkResponseDtoCopyWith<$Res> {
  factory $RpcOkResponseDtoCopyWith(
    RpcOkResponseDto value,
    $Res Function(RpcOkResponseDto) then,
  ) = _$RpcOkResponseDtoCopyWithImpl<$Res, RpcOkResponseDto>;
  @useResult
  $Res call({@JsonKey(fromJson: _requiredBool) bool ok});
}

/// @nodoc
class _$RpcOkResponseDtoCopyWithImpl<$Res, $Val extends RpcOkResponseDto>
    implements $RpcOkResponseDtoCopyWith<$Res> {
  _$RpcOkResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcOkResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? ok = null}) {
    return _then(
      _value.copyWith(
            ok: null == ok
                ? _value.ok
                : ok // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcOkResponseDtoImplCopyWith<$Res>
    implements $RpcOkResponseDtoCopyWith<$Res> {
  factory _$$RpcOkResponseDtoImplCopyWith(
    _$RpcOkResponseDtoImpl value,
    $Res Function(_$RpcOkResponseDtoImpl) then,
  ) = __$$RpcOkResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(fromJson: _requiredBool) bool ok});
}

/// @nodoc
class __$$RpcOkResponseDtoImplCopyWithImpl<$Res>
    extends _$RpcOkResponseDtoCopyWithImpl<$Res, _$RpcOkResponseDtoImpl>
    implements _$$RpcOkResponseDtoImplCopyWith<$Res> {
  __$$RpcOkResponseDtoImplCopyWithImpl(
    _$RpcOkResponseDtoImpl _value,
    $Res Function(_$RpcOkResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcOkResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? ok = null}) {
    return _then(
      _$RpcOkResponseDtoImpl(
        ok: null == ok
            ? _value.ok
            : ok // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcOkResponseDtoImpl implements _RpcOkResponseDto {
  const _$RpcOkResponseDtoImpl({
    @JsonKey(fromJson: _requiredBool) required this.ok,
  });

  factory _$RpcOkResponseDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RpcOkResponseDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _requiredBool)
  final bool ok;

  @override
  String toString() {
    return 'RpcOkResponseDto(ok: $ok)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcOkResponseDtoImpl &&
            (identical(other.ok, ok) || other.ok == ok));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, ok);

  /// Create a copy of RpcOkResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcOkResponseDtoImplCopyWith<_$RpcOkResponseDtoImpl> get copyWith =>
      __$$RpcOkResponseDtoImplCopyWithImpl<_$RpcOkResponseDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcOkResponseDtoImplToJson(this);
  }
}

abstract class _RpcOkResponseDto implements RpcOkResponseDto {
  const factory _RpcOkResponseDto({
    @JsonKey(fromJson: _requiredBool) required final bool ok,
  }) = _$RpcOkResponseDtoImpl;

  factory _RpcOkResponseDto.fromJson(Map<String, dynamic> json) =
      _$RpcOkResponseDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _requiredBool)
  bool get ok;

  /// Create a copy of RpcOkResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcOkResponseDtoImplCopyWith<_$RpcOkResponseDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RpcAcceptedResponseDto _$RpcAcceptedResponseDtoFromJson(
  Map<String, dynamic> json,
) {
  return _RpcAcceptedResponseDto.fromJson(json);
}

/// @nodoc
mixin _$RpcAcceptedResponseDto {
  @JsonKey(fromJson: _requiredBool)
  bool get accepted => throw _privateConstructorUsedError;

  /// Serializes this RpcAcceptedResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcAcceptedResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcAcceptedResponseDtoCopyWith<RpcAcceptedResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcAcceptedResponseDtoCopyWith<$Res> {
  factory $RpcAcceptedResponseDtoCopyWith(
    RpcAcceptedResponseDto value,
    $Res Function(RpcAcceptedResponseDto) then,
  ) = _$RpcAcceptedResponseDtoCopyWithImpl<$Res, RpcAcceptedResponseDto>;
  @useResult
  $Res call({@JsonKey(fromJson: _requiredBool) bool accepted});
}

/// @nodoc
class _$RpcAcceptedResponseDtoCopyWithImpl<
  $Res,
  $Val extends RpcAcceptedResponseDto
>
    implements $RpcAcceptedResponseDtoCopyWith<$Res> {
  _$RpcAcceptedResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcAcceptedResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? accepted = null}) {
    return _then(
      _value.copyWith(
            accepted: null == accepted
                ? _value.accepted
                : accepted // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcAcceptedResponseDtoImplCopyWith<$Res>
    implements $RpcAcceptedResponseDtoCopyWith<$Res> {
  factory _$$RpcAcceptedResponseDtoImplCopyWith(
    _$RpcAcceptedResponseDtoImpl value,
    $Res Function(_$RpcAcceptedResponseDtoImpl) then,
  ) = __$$RpcAcceptedResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({@JsonKey(fromJson: _requiredBool) bool accepted});
}

/// @nodoc
class __$$RpcAcceptedResponseDtoImplCopyWithImpl<$Res>
    extends
        _$RpcAcceptedResponseDtoCopyWithImpl<$Res, _$RpcAcceptedResponseDtoImpl>
    implements _$$RpcAcceptedResponseDtoImplCopyWith<$Res> {
  __$$RpcAcceptedResponseDtoImplCopyWithImpl(
    _$RpcAcceptedResponseDtoImpl _value,
    $Res Function(_$RpcAcceptedResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcAcceptedResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? accepted = null}) {
    return _then(
      _$RpcAcceptedResponseDtoImpl(
        accepted: null == accepted
            ? _value.accepted
            : accepted // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcAcceptedResponseDtoImpl implements _RpcAcceptedResponseDto {
  const _$RpcAcceptedResponseDtoImpl({
    @JsonKey(fromJson: _requiredBool) required this.accepted,
  });

  factory _$RpcAcceptedResponseDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RpcAcceptedResponseDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _requiredBool)
  final bool accepted;

  @override
  String toString() {
    return 'RpcAcceptedResponseDto(accepted: $accepted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcAcceptedResponseDtoImpl &&
            (identical(other.accepted, accepted) ||
                other.accepted == accepted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, accepted);

  /// Create a copy of RpcAcceptedResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcAcceptedResponseDtoImplCopyWith<_$RpcAcceptedResponseDtoImpl>
  get copyWith =>
      __$$RpcAcceptedResponseDtoImplCopyWithImpl<_$RpcAcceptedResponseDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcAcceptedResponseDtoImplToJson(this);
  }
}

abstract class _RpcAcceptedResponseDto implements RpcAcceptedResponseDto {
  const factory _RpcAcceptedResponseDto({
    @JsonKey(fromJson: _requiredBool) required final bool accepted,
  }) = _$RpcAcceptedResponseDtoImpl;

  factory _RpcAcceptedResponseDto.fromJson(Map<String, dynamic> json) =
      _$RpcAcceptedResponseDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _requiredBool)
  bool get accepted;

  /// Create a copy of RpcAcceptedResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcAcceptedResponseDtoImplCopyWith<_$RpcAcceptedResponseDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

RpcResolvedSessionDto _$RpcResolvedSessionDtoFromJson(
  Map<String, dynamic> json,
) {
  return _RpcResolvedSessionDto.fromJson(json);
}

/// @nodoc
mixin _$RpcResolvedSessionDto {
  @JsonKey(name: 'sessionId', fromJson: _requiredString)
  String get sessionId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableString)
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableString)
  String? get cwd => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableString)
  String? get runtime => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableString)
  String? get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
  List<AcpSessionConfigOptionDto>? get configOptions =>
      throw _privateConstructorUsedError;

  /// Serializes this RpcResolvedSessionDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcResolvedSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcResolvedSessionDtoCopyWith<RpcResolvedSessionDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcResolvedSessionDtoCopyWith<$Res> {
  factory $RpcResolvedSessionDtoCopyWith(
    RpcResolvedSessionDto value,
    $Res Function(RpcResolvedSessionDto) then,
  ) = _$RpcResolvedSessionDtoCopyWithImpl<$Res, RpcResolvedSessionDto>;
  @useResult
  $Res call({
    @JsonKey(name: 'sessionId', fromJson: _requiredString) String sessionId,
    @JsonKey(fromJson: _nullableString) String? title,
    @JsonKey(fromJson: _nullableString) String? cwd,
    @JsonKey(fromJson: _nullableString) String? runtime,
    @JsonKey(fromJson: _nullableString) String? status,
    @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
    DateTime? updatedAt,
    @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
    List<AcpSessionConfigOptionDto>? configOptions,
  });
}

/// @nodoc
class _$RpcResolvedSessionDtoCopyWithImpl<
  $Res,
  $Val extends RpcResolvedSessionDto
>
    implements $RpcResolvedSessionDtoCopyWith<$Res> {
  _$RpcResolvedSessionDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcResolvedSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? title = freezed,
    Object? cwd = freezed,
    Object? runtime = freezed,
    Object? status = freezed,
    Object? updatedAt = freezed,
    Object? configOptions = freezed,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            cwd: freezed == cwd
                ? _value.cwd
                : cwd // ignore: cast_nullable_to_non_nullable
                      as String?,
            runtime: freezed == runtime
                ? _value.runtime
                : runtime // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            configOptions: freezed == configOptions
                ? _value.configOptions
                : configOptions // ignore: cast_nullable_to_non_nullable
                      as List<AcpSessionConfigOptionDto>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcResolvedSessionDtoImplCopyWith<$Res>
    implements $RpcResolvedSessionDtoCopyWith<$Res> {
  factory _$$RpcResolvedSessionDtoImplCopyWith(
    _$RpcResolvedSessionDtoImpl value,
    $Res Function(_$RpcResolvedSessionDtoImpl) then,
  ) = __$$RpcResolvedSessionDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'sessionId', fromJson: _requiredString) String sessionId,
    @JsonKey(fromJson: _nullableString) String? title,
    @JsonKey(fromJson: _nullableString) String? cwd,
    @JsonKey(fromJson: _nullableString) String? runtime,
    @JsonKey(fromJson: _nullableString) String? status,
    @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
    DateTime? updatedAt,
    @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
    List<AcpSessionConfigOptionDto>? configOptions,
  });
}

/// @nodoc
class __$$RpcResolvedSessionDtoImplCopyWithImpl<$Res>
    extends
        _$RpcResolvedSessionDtoCopyWithImpl<$Res, _$RpcResolvedSessionDtoImpl>
    implements _$$RpcResolvedSessionDtoImplCopyWith<$Res> {
  __$$RpcResolvedSessionDtoImplCopyWithImpl(
    _$RpcResolvedSessionDtoImpl _value,
    $Res Function(_$RpcResolvedSessionDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcResolvedSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? title = freezed,
    Object? cwd = freezed,
    Object? runtime = freezed,
    Object? status = freezed,
    Object? updatedAt = freezed,
    Object? configOptions = freezed,
  }) {
    return _then(
      _$RpcResolvedSessionDtoImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        cwd: freezed == cwd
            ? _value.cwd
            : cwd // ignore: cast_nullable_to_non_nullable
                  as String?,
        runtime: freezed == runtime
            ? _value.runtime
            : runtime // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        configOptions: freezed == configOptions
            ? _value._configOptions
            : configOptions // ignore: cast_nullable_to_non_nullable
                  as List<AcpSessionConfigOptionDto>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcResolvedSessionDtoImpl implements _RpcResolvedSessionDto {
  const _$RpcResolvedSessionDtoImpl({
    @JsonKey(name: 'sessionId', fromJson: _requiredString)
    required this.sessionId,
    @JsonKey(fromJson: _nullableString) this.title,
    @JsonKey(fromJson: _nullableString) this.cwd,
    @JsonKey(fromJson: _nullableString) this.runtime,
    @JsonKey(fromJson: _nullableString) this.status,
    @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime) this.updatedAt,
    @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
    final List<AcpSessionConfigOptionDto>? configOptions,
  }) : _configOptions = configOptions;

  factory _$RpcResolvedSessionDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RpcResolvedSessionDtoImplFromJson(json);

  @override
  @JsonKey(name: 'sessionId', fromJson: _requiredString)
  final String sessionId;
  @override
  @JsonKey(fromJson: _nullableString)
  final String? title;
  @override
  @JsonKey(fromJson: _nullableString)
  final String? cwd;
  @override
  @JsonKey(fromJson: _nullableString)
  final String? runtime;
  @override
  @JsonKey(fromJson: _nullableString)
  final String? status;
  @override
  @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
  final DateTime? updatedAt;
  final List<AcpSessionConfigOptionDto>? _configOptions;
  @override
  @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
  List<AcpSessionConfigOptionDto>? get configOptions {
    final value = _configOptions;
    if (value == null) return null;
    if (_configOptions is EqualUnmodifiableListView) return _configOptions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'RpcResolvedSessionDto(sessionId: $sessionId, title: $title, cwd: $cwd, runtime: $runtime, status: $status, updatedAt: $updatedAt, configOptions: $configOptions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcResolvedSessionDtoImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.cwd, cwd) || other.cwd == cwd) &&
            (identical(other.runtime, runtime) || other.runtime == runtime) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(
              other._configOptions,
              _configOptions,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    title,
    cwd,
    runtime,
    status,
    updatedAt,
    const DeepCollectionEquality().hash(_configOptions),
  );

  /// Create a copy of RpcResolvedSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcResolvedSessionDtoImplCopyWith<_$RpcResolvedSessionDtoImpl>
  get copyWith =>
      __$$RpcResolvedSessionDtoImplCopyWithImpl<_$RpcResolvedSessionDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcResolvedSessionDtoImplToJson(this);
  }
}

abstract class _RpcResolvedSessionDto implements RpcResolvedSessionDto {
  const factory _RpcResolvedSessionDto({
    @JsonKey(name: 'sessionId', fromJson: _requiredString)
    required final String sessionId,
    @JsonKey(fromJson: _nullableString) final String? title,
    @JsonKey(fromJson: _nullableString) final String? cwd,
    @JsonKey(fromJson: _nullableString) final String? runtime,
    @JsonKey(fromJson: _nullableString) final String? status,
    @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
    final DateTime? updatedAt,
    @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
    final List<AcpSessionConfigOptionDto>? configOptions,
  }) = _$RpcResolvedSessionDtoImpl;

  factory _RpcResolvedSessionDto.fromJson(Map<String, dynamic> json) =
      _$RpcResolvedSessionDtoImpl.fromJson;

  @override
  @JsonKey(name: 'sessionId', fromJson: _requiredString)
  String get sessionId;
  @override
  @JsonKey(fromJson: _nullableString)
  String? get title;
  @override
  @JsonKey(fromJson: _nullableString)
  String? get cwd;
  @override
  @JsonKey(fromJson: _nullableString)
  String? get runtime;
  @override
  @JsonKey(fromJson: _nullableString)
  String? get status;
  @override
  @JsonKey(name: 'updatedAt', fromJson: _nullableDateTime)
  DateTime? get updatedAt;
  @override
  @JsonKey(name: 'configOptions', fromJson: _nullableConfigOptionListFromJson)
  List<AcpSessionConfigOptionDto>? get configOptions;

  /// Create a copy of RpcResolvedSessionDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcResolvedSessionDtoImplCopyWith<_$RpcResolvedSessionDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

RpcSessionResolveResponseDto _$RpcSessionResolveResponseDtoFromJson(
  Map<String, dynamic> json,
) {
  return _RpcSessionResolveResponseDto.fromJson(json);
}

/// @nodoc
mixin _$RpcSessionResolveResponseDto {
  @JsonKey(fromJson: _resolvedSessionListFromJson)
  List<RpcResolvedSessionDto> get sessions =>
      throw _privateConstructorUsedError;

  /// Serializes this RpcSessionResolveResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcSessionResolveResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcSessionResolveResponseDtoCopyWith<RpcSessionResolveResponseDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcSessionResolveResponseDtoCopyWith<$Res> {
  factory $RpcSessionResolveResponseDtoCopyWith(
    RpcSessionResolveResponseDto value,
    $Res Function(RpcSessionResolveResponseDto) then,
  ) =
      _$RpcSessionResolveResponseDtoCopyWithImpl<
        $Res,
        RpcSessionResolveResponseDto
      >;
  @useResult
  $Res call({
    @JsonKey(fromJson: _resolvedSessionListFromJson)
    List<RpcResolvedSessionDto> sessions,
  });
}

/// @nodoc
class _$RpcSessionResolveResponseDtoCopyWithImpl<
  $Res,
  $Val extends RpcSessionResolveResponseDto
>
    implements $RpcSessionResolveResponseDtoCopyWith<$Res> {
  _$RpcSessionResolveResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcSessionResolveResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sessions = null}) {
    return _then(
      _value.copyWith(
            sessions: null == sessions
                ? _value.sessions
                : sessions // ignore: cast_nullable_to_non_nullable
                      as List<RpcResolvedSessionDto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcSessionResolveResponseDtoImplCopyWith<$Res>
    implements $RpcSessionResolveResponseDtoCopyWith<$Res> {
  factory _$$RpcSessionResolveResponseDtoImplCopyWith(
    _$RpcSessionResolveResponseDtoImpl value,
    $Res Function(_$RpcSessionResolveResponseDtoImpl) then,
  ) = __$$RpcSessionResolveResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _resolvedSessionListFromJson)
    List<RpcResolvedSessionDto> sessions,
  });
}

/// @nodoc
class __$$RpcSessionResolveResponseDtoImplCopyWithImpl<$Res>
    extends
        _$RpcSessionResolveResponseDtoCopyWithImpl<
          $Res,
          _$RpcSessionResolveResponseDtoImpl
        >
    implements _$$RpcSessionResolveResponseDtoImplCopyWith<$Res> {
  __$$RpcSessionResolveResponseDtoImplCopyWithImpl(
    _$RpcSessionResolveResponseDtoImpl _value,
    $Res Function(_$RpcSessionResolveResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcSessionResolveResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? sessions = null}) {
    return _then(
      _$RpcSessionResolveResponseDtoImpl(
        sessions: null == sessions
            ? _value._sessions
            : sessions // ignore: cast_nullable_to_non_nullable
                  as List<RpcResolvedSessionDto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcSessionResolveResponseDtoImpl
    implements _RpcSessionResolveResponseDto {
  const _$RpcSessionResolveResponseDtoImpl({
    @JsonKey(fromJson: _resolvedSessionListFromJson)
    required final List<RpcResolvedSessionDto> sessions,
  }) : _sessions = sessions;

  factory _$RpcSessionResolveResponseDtoImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$RpcSessionResolveResponseDtoImplFromJson(json);

  final List<RpcResolvedSessionDto> _sessions;
  @override
  @JsonKey(fromJson: _resolvedSessionListFromJson)
  List<RpcResolvedSessionDto> get sessions {
    if (_sessions is EqualUnmodifiableListView) return _sessions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sessions);
  }

  @override
  String toString() {
    return 'RpcSessionResolveResponseDto(sessions: $sessions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcSessionResolveResponseDtoImpl &&
            const DeepCollectionEquality().equals(other._sessions, _sessions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_sessions));

  /// Create a copy of RpcSessionResolveResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcSessionResolveResponseDtoImplCopyWith<
    _$RpcSessionResolveResponseDtoImpl
  >
  get copyWith =>
      __$$RpcSessionResolveResponseDtoImplCopyWithImpl<
        _$RpcSessionResolveResponseDtoImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcSessionResolveResponseDtoImplToJson(this);
  }
}

abstract class _RpcSessionResolveResponseDto
    implements RpcSessionResolveResponseDto {
  const factory _RpcSessionResolveResponseDto({
    @JsonKey(fromJson: _resolvedSessionListFromJson)
    required final List<RpcResolvedSessionDto> sessions,
  }) = _$RpcSessionResolveResponseDtoImpl;

  factory _RpcSessionResolveResponseDto.fromJson(Map<String, dynamic> json) =
      _$RpcSessionResolveResponseDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _resolvedSessionListFromJson)
  List<RpcResolvedSessionDto> get sessions;

  /// Create a copy of RpcSessionResolveResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcSessionResolveResponseDtoImplCopyWith<
    _$RpcSessionResolveResponseDtoImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RpcPendingApprovalsResponseDto {
  @JsonKey(fromJson: _approvalWireListFromJson)
  List<ApprovalWireDto> get approvals => throw _privateConstructorUsedError;

  /// Create a copy of RpcPendingApprovalsResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcPendingApprovalsResponseDtoCopyWith<RpcPendingApprovalsResponseDto>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcPendingApprovalsResponseDtoCopyWith<$Res> {
  factory $RpcPendingApprovalsResponseDtoCopyWith(
    RpcPendingApprovalsResponseDto value,
    $Res Function(RpcPendingApprovalsResponseDto) then,
  ) =
      _$RpcPendingApprovalsResponseDtoCopyWithImpl<
        $Res,
        RpcPendingApprovalsResponseDto
      >;
  @useResult
  $Res call({
    @JsonKey(fromJson: _approvalWireListFromJson)
    List<ApprovalWireDto> approvals,
  });
}

/// @nodoc
class _$RpcPendingApprovalsResponseDtoCopyWithImpl<
  $Res,
  $Val extends RpcPendingApprovalsResponseDto
>
    implements $RpcPendingApprovalsResponseDtoCopyWith<$Res> {
  _$RpcPendingApprovalsResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcPendingApprovalsResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? approvals = null}) {
    return _then(
      _value.copyWith(
            approvals: null == approvals
                ? _value.approvals
                : approvals // ignore: cast_nullable_to_non_nullable
                      as List<ApprovalWireDto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcPendingApprovalsResponseDtoImplCopyWith<$Res>
    implements $RpcPendingApprovalsResponseDtoCopyWith<$Res> {
  factory _$$RpcPendingApprovalsResponseDtoImplCopyWith(
    _$RpcPendingApprovalsResponseDtoImpl value,
    $Res Function(_$RpcPendingApprovalsResponseDtoImpl) then,
  ) = __$$RpcPendingApprovalsResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _approvalWireListFromJson)
    List<ApprovalWireDto> approvals,
  });
}

/// @nodoc
class __$$RpcPendingApprovalsResponseDtoImplCopyWithImpl<$Res>
    extends
        _$RpcPendingApprovalsResponseDtoCopyWithImpl<
          $Res,
          _$RpcPendingApprovalsResponseDtoImpl
        >
    implements _$$RpcPendingApprovalsResponseDtoImplCopyWith<$Res> {
  __$$RpcPendingApprovalsResponseDtoImplCopyWithImpl(
    _$RpcPendingApprovalsResponseDtoImpl _value,
    $Res Function(_$RpcPendingApprovalsResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcPendingApprovalsResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? approvals = null}) {
    return _then(
      _$RpcPendingApprovalsResponseDtoImpl(
        approvals: null == approvals
            ? _value._approvals
            : approvals // ignore: cast_nullable_to_non_nullable
                  as List<ApprovalWireDto>,
      ),
    );
  }
}

/// @nodoc

class _$RpcPendingApprovalsResponseDtoImpl
    implements _RpcPendingApprovalsResponseDto {
  const _$RpcPendingApprovalsResponseDtoImpl({
    @JsonKey(fromJson: _approvalWireListFromJson)
    required final List<ApprovalWireDto> approvals,
  }) : _approvals = approvals;

  final List<ApprovalWireDto> _approvals;
  @override
  @JsonKey(fromJson: _approvalWireListFromJson)
  List<ApprovalWireDto> get approvals {
    if (_approvals is EqualUnmodifiableListView) return _approvals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_approvals);
  }

  @override
  String toString() {
    return 'RpcPendingApprovalsResponseDto(approvals: $approvals)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcPendingApprovalsResponseDtoImpl &&
            const DeepCollectionEquality().equals(
              other._approvals,
              _approvals,
            ));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_approvals));

  /// Create a copy of RpcPendingApprovalsResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcPendingApprovalsResponseDtoImplCopyWith<
    _$RpcPendingApprovalsResponseDtoImpl
  >
  get copyWith =>
      __$$RpcPendingApprovalsResponseDtoImplCopyWithImpl<
        _$RpcPendingApprovalsResponseDtoImpl
      >(this, _$identity);
}

abstract class _RpcPendingApprovalsResponseDto
    implements RpcPendingApprovalsResponseDto {
  const factory _RpcPendingApprovalsResponseDto({
    @JsonKey(fromJson: _approvalWireListFromJson)
    required final List<ApprovalWireDto> approvals,
  }) = _$RpcPendingApprovalsResponseDtoImpl;

  @override
  @JsonKey(fromJson: _approvalWireListFromJson)
  List<ApprovalWireDto> get approvals;

  /// Create a copy of RpcPendingApprovalsResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcPendingApprovalsResponseDtoImplCopyWith<
    _$RpcPendingApprovalsResponseDtoImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

RpcFsEntryDto _$RpcFsEntryDtoFromJson(Map<String, dynamic> json) {
  return _RpcFsEntryDto.fromJson(json);
}

/// @nodoc
mixin _$RpcFsEntryDto {
  @JsonKey(fromJson: _requiredString)
  String get path => throw _privateConstructorUsedError;
  @JsonKey(name: 'isDir', fromJson: _requiredBool)
  bool get isDir => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _nullableString)
  String? get name => throw _privateConstructorUsedError;

  /// Serializes this RpcFsEntryDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcFsEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcFsEntryDtoCopyWith<RpcFsEntryDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcFsEntryDtoCopyWith<$Res> {
  factory $RpcFsEntryDtoCopyWith(
    RpcFsEntryDto value,
    $Res Function(RpcFsEntryDto) then,
  ) = _$RpcFsEntryDtoCopyWithImpl<$Res, RpcFsEntryDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String path,
    @JsonKey(name: 'isDir', fromJson: _requiredBool) bool isDir,
    @JsonKey(fromJson: _nullableString) String? name,
  });
}

/// @nodoc
class _$RpcFsEntryDtoCopyWithImpl<$Res, $Val extends RpcFsEntryDto>
    implements $RpcFsEntryDtoCopyWith<$Res> {
  _$RpcFsEntryDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcFsEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? isDir = null,
    Object? name = freezed,
  }) {
    return _then(
      _value.copyWith(
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            isDir: null == isDir
                ? _value.isDir
                : isDir // ignore: cast_nullable_to_non_nullable
                      as bool,
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcFsEntryDtoImplCopyWith<$Res>
    implements $RpcFsEntryDtoCopyWith<$Res> {
  factory _$$RpcFsEntryDtoImplCopyWith(
    _$RpcFsEntryDtoImpl value,
    $Res Function(_$RpcFsEntryDtoImpl) then,
  ) = __$$RpcFsEntryDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _requiredString) String path,
    @JsonKey(name: 'isDir', fromJson: _requiredBool) bool isDir,
    @JsonKey(fromJson: _nullableString) String? name,
  });
}

/// @nodoc
class __$$RpcFsEntryDtoImplCopyWithImpl<$Res>
    extends _$RpcFsEntryDtoCopyWithImpl<$Res, _$RpcFsEntryDtoImpl>
    implements _$$RpcFsEntryDtoImplCopyWith<$Res> {
  __$$RpcFsEntryDtoImplCopyWithImpl(
    _$RpcFsEntryDtoImpl _value,
    $Res Function(_$RpcFsEntryDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcFsEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? isDir = null,
    Object? name = freezed,
  }) {
    return _then(
      _$RpcFsEntryDtoImpl(
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        isDir: null == isDir
            ? _value.isDir
            : isDir // ignore: cast_nullable_to_non_nullable
                  as bool,
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcFsEntryDtoImpl implements _RpcFsEntryDto {
  const _$RpcFsEntryDtoImpl({
    @JsonKey(fromJson: _requiredString) required this.path,
    @JsonKey(name: 'isDir', fromJson: _requiredBool) required this.isDir,
    @JsonKey(fromJson: _nullableString) this.name,
  });

  factory _$RpcFsEntryDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RpcFsEntryDtoImplFromJson(json);

  @override
  @JsonKey(fromJson: _requiredString)
  final String path;
  @override
  @JsonKey(name: 'isDir', fromJson: _requiredBool)
  final bool isDir;
  @override
  @JsonKey(fromJson: _nullableString)
  final String? name;

  @override
  String toString() {
    return 'RpcFsEntryDto(path: $path, isDir: $isDir, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcFsEntryDtoImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.isDir, isDir) || other.isDir == isDir) &&
            (identical(other.name, name) || other.name == name));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, path, isDir, name);

  /// Create a copy of RpcFsEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcFsEntryDtoImplCopyWith<_$RpcFsEntryDtoImpl> get copyWith =>
      __$$RpcFsEntryDtoImplCopyWithImpl<_$RpcFsEntryDtoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcFsEntryDtoImplToJson(this);
  }
}

abstract class _RpcFsEntryDto implements RpcFsEntryDto {
  const factory _RpcFsEntryDto({
    @JsonKey(fromJson: _requiredString) required final String path,
    @JsonKey(name: 'isDir', fromJson: _requiredBool) required final bool isDir,
    @JsonKey(fromJson: _nullableString) final String? name,
  }) = _$RpcFsEntryDtoImpl;

  factory _RpcFsEntryDto.fromJson(Map<String, dynamic> json) =
      _$RpcFsEntryDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _requiredString)
  String get path;
  @override
  @JsonKey(name: 'isDir', fromJson: _requiredBool)
  bool get isDir;
  @override
  @JsonKey(fromJson: _nullableString)
  String? get name;

  /// Create a copy of RpcFsEntryDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcFsEntryDtoImplCopyWith<_$RpcFsEntryDtoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RpcFsListResponseDto _$RpcFsListResponseDtoFromJson(Map<String, dynamic> json) {
  return _RpcFsListResponseDto.fromJson(json);
}

/// @nodoc
mixin _$RpcFsListResponseDto {
  @JsonKey(fromJson: _fsEntryListFromJson)
  List<RpcFsEntryDto> get entries => throw _privateConstructorUsedError;

  /// Serializes this RpcFsListResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcFsListResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcFsListResponseDtoCopyWith<RpcFsListResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcFsListResponseDtoCopyWith<$Res> {
  factory $RpcFsListResponseDtoCopyWith(
    RpcFsListResponseDto value,
    $Res Function(RpcFsListResponseDto) then,
  ) = _$RpcFsListResponseDtoCopyWithImpl<$Res, RpcFsListResponseDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _fsEntryListFromJson) List<RpcFsEntryDto> entries,
  });
}

/// @nodoc
class _$RpcFsListResponseDtoCopyWithImpl<
  $Res,
  $Val extends RpcFsListResponseDto
>
    implements $RpcFsListResponseDtoCopyWith<$Res> {
  _$RpcFsListResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcFsListResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? entries = null}) {
    return _then(
      _value.copyWith(
            entries: null == entries
                ? _value.entries
                : entries // ignore: cast_nullable_to_non_nullable
                      as List<RpcFsEntryDto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcFsListResponseDtoImplCopyWith<$Res>
    implements $RpcFsListResponseDtoCopyWith<$Res> {
  factory _$$RpcFsListResponseDtoImplCopyWith(
    _$RpcFsListResponseDtoImpl value,
    $Res Function(_$RpcFsListResponseDtoImpl) then,
  ) = __$$RpcFsListResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _fsEntryListFromJson) List<RpcFsEntryDto> entries,
  });
}

/// @nodoc
class __$$RpcFsListResponseDtoImplCopyWithImpl<$Res>
    extends _$RpcFsListResponseDtoCopyWithImpl<$Res, _$RpcFsListResponseDtoImpl>
    implements _$$RpcFsListResponseDtoImplCopyWith<$Res> {
  __$$RpcFsListResponseDtoImplCopyWithImpl(
    _$RpcFsListResponseDtoImpl _value,
    $Res Function(_$RpcFsListResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcFsListResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? entries = null}) {
    return _then(
      _$RpcFsListResponseDtoImpl(
        entries: null == entries
            ? _value._entries
            : entries // ignore: cast_nullable_to_non_nullable
                  as List<RpcFsEntryDto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcFsListResponseDtoImpl implements _RpcFsListResponseDto {
  const _$RpcFsListResponseDtoImpl({
    @JsonKey(fromJson: _fsEntryListFromJson)
    required final List<RpcFsEntryDto> entries,
  }) : _entries = entries;

  factory _$RpcFsListResponseDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RpcFsListResponseDtoImplFromJson(json);

  final List<RpcFsEntryDto> _entries;
  @override
  @JsonKey(fromJson: _fsEntryListFromJson)
  List<RpcFsEntryDto> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  String toString() {
    return 'RpcFsListResponseDto(entries: $entries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcFsListResponseDtoImpl &&
            const DeepCollectionEquality().equals(other._entries, _entries));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_entries));

  /// Create a copy of RpcFsListResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcFsListResponseDtoImplCopyWith<_$RpcFsListResponseDtoImpl>
  get copyWith =>
      __$$RpcFsListResponseDtoImplCopyWithImpl<_$RpcFsListResponseDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcFsListResponseDtoImplToJson(this);
  }
}

abstract class _RpcFsListResponseDto implements RpcFsListResponseDto {
  const factory _RpcFsListResponseDto({
    @JsonKey(fromJson: _fsEntryListFromJson)
    required final List<RpcFsEntryDto> entries,
  }) = _$RpcFsListResponseDtoImpl;

  factory _RpcFsListResponseDto.fromJson(Map<String, dynamic> json) =
      _$RpcFsListResponseDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _fsEntryListFromJson)
  List<RpcFsEntryDto> get entries;

  /// Create a copy of RpcFsListResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcFsListResponseDtoImplCopyWith<_$RpcFsListResponseDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

RpcFsSearchResponseDto _$RpcFsSearchResponseDtoFromJson(
  Map<String, dynamic> json,
) {
  return _RpcFsSearchResponseDto.fromJson(json);
}

/// @nodoc
mixin _$RpcFsSearchResponseDto {
  @JsonKey(fromJson: _fsEntryListFromJson)
  List<RpcFsEntryDto> get results => throw _privateConstructorUsedError;

  /// Serializes this RpcFsSearchResponseDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RpcFsSearchResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RpcFsSearchResponseDtoCopyWith<RpcFsSearchResponseDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RpcFsSearchResponseDtoCopyWith<$Res> {
  factory $RpcFsSearchResponseDtoCopyWith(
    RpcFsSearchResponseDto value,
    $Res Function(RpcFsSearchResponseDto) then,
  ) = _$RpcFsSearchResponseDtoCopyWithImpl<$Res, RpcFsSearchResponseDto>;
  @useResult
  $Res call({
    @JsonKey(fromJson: _fsEntryListFromJson) List<RpcFsEntryDto> results,
  });
}

/// @nodoc
class _$RpcFsSearchResponseDtoCopyWithImpl<
  $Res,
  $Val extends RpcFsSearchResponseDto
>
    implements $RpcFsSearchResponseDtoCopyWith<$Res> {
  _$RpcFsSearchResponseDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RpcFsSearchResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? results = null}) {
    return _then(
      _value.copyWith(
            results: null == results
                ? _value.results
                : results // ignore: cast_nullable_to_non_nullable
                      as List<RpcFsEntryDto>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RpcFsSearchResponseDtoImplCopyWith<$Res>
    implements $RpcFsSearchResponseDtoCopyWith<$Res> {
  factory _$$RpcFsSearchResponseDtoImplCopyWith(
    _$RpcFsSearchResponseDtoImpl value,
    $Res Function(_$RpcFsSearchResponseDtoImpl) then,
  ) = __$$RpcFsSearchResponseDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _fsEntryListFromJson) List<RpcFsEntryDto> results,
  });
}

/// @nodoc
class __$$RpcFsSearchResponseDtoImplCopyWithImpl<$Res>
    extends
        _$RpcFsSearchResponseDtoCopyWithImpl<$Res, _$RpcFsSearchResponseDtoImpl>
    implements _$$RpcFsSearchResponseDtoImplCopyWith<$Res> {
  __$$RpcFsSearchResponseDtoImplCopyWithImpl(
    _$RpcFsSearchResponseDtoImpl _value,
    $Res Function(_$RpcFsSearchResponseDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RpcFsSearchResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? results = null}) {
    return _then(
      _$RpcFsSearchResponseDtoImpl(
        results: null == results
            ? _value._results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<RpcFsEntryDto>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RpcFsSearchResponseDtoImpl implements _RpcFsSearchResponseDto {
  const _$RpcFsSearchResponseDtoImpl({
    @JsonKey(fromJson: _fsEntryListFromJson)
    required final List<RpcFsEntryDto> results,
  }) : _results = results;

  factory _$RpcFsSearchResponseDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RpcFsSearchResponseDtoImplFromJson(json);

  final List<RpcFsEntryDto> _results;
  @override
  @JsonKey(fromJson: _fsEntryListFromJson)
  List<RpcFsEntryDto> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  @override
  String toString() {
    return 'RpcFsSearchResponseDto(results: $results)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RpcFsSearchResponseDtoImpl &&
            const DeepCollectionEquality().equals(other._results, _results));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_results));

  /// Create a copy of RpcFsSearchResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RpcFsSearchResponseDtoImplCopyWith<_$RpcFsSearchResponseDtoImpl>
  get copyWith =>
      __$$RpcFsSearchResponseDtoImplCopyWithImpl<_$RpcFsSearchResponseDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RpcFsSearchResponseDtoImplToJson(this);
  }
}

abstract class _RpcFsSearchResponseDto implements RpcFsSearchResponseDto {
  const factory _RpcFsSearchResponseDto({
    @JsonKey(fromJson: _fsEntryListFromJson)
    required final List<RpcFsEntryDto> results,
  }) = _$RpcFsSearchResponseDtoImpl;

  factory _RpcFsSearchResponseDto.fromJson(Map<String, dynamic> json) =
      _$RpcFsSearchResponseDtoImpl.fromJson;

  @override
  @JsonKey(fromJson: _fsEntryListFromJson)
  List<RpcFsEntryDto> get results;

  /// Create a copy of RpcFsSearchResponseDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RpcFsSearchResponseDtoImplCopyWith<_$RpcFsSearchResponseDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
