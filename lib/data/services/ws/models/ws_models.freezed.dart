// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ws_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WsRegister _$WsRegisterFromJson(Map<String, dynamic> json) {
  return _WsRegister.fromJson(json);
}

/// @nodoc
mixin _$WsRegister {
  String get type => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_id')
  String? get machineId => throw _privateConstructorUsedError;
  String? get hostname => throw _privateConstructorUsedError;
  @JsonKey(name: 'connect_token')
  String? get connectToken => throw _privateConstructorUsedError;

  /// Serializes this WsRegister to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsRegister
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsRegisterCopyWith<WsRegister> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsRegisterCopyWith<$Res> {
  factory $WsRegisterCopyWith(
    WsRegister value,
    $Res Function(WsRegister) then,
  ) = _$WsRegisterCopyWithImpl<$Res, WsRegister>;
  @useResult
  $Res call({
    String type,
    String role,
    @JsonKey(name: 'machine_id') String? machineId,
    String? hostname,
    @JsonKey(name: 'connect_token') String? connectToken,
  });
}

/// @nodoc
class _$WsRegisterCopyWithImpl<$Res, $Val extends WsRegister>
    implements $WsRegisterCopyWith<$Res> {
  _$WsRegisterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsRegister
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? role = null,
    Object? machineId = freezed,
    Object? hostname = freezed,
    Object? connectToken = freezed,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            machineId: freezed == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String?,
            hostname: freezed == hostname
                ? _value.hostname
                : hostname // ignore: cast_nullable_to_non_nullable
                      as String?,
            connectToken: freezed == connectToken
                ? _value.connectToken
                : connectToken // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsRegisterImplCopyWith<$Res>
    implements $WsRegisterCopyWith<$Res> {
  factory _$$WsRegisterImplCopyWith(
    _$WsRegisterImpl value,
    $Res Function(_$WsRegisterImpl) then,
  ) = __$$WsRegisterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    String role,
    @JsonKey(name: 'machine_id') String? machineId,
    String? hostname,
    @JsonKey(name: 'connect_token') String? connectToken,
  });
}

/// @nodoc
class __$$WsRegisterImplCopyWithImpl<$Res>
    extends _$WsRegisterCopyWithImpl<$Res, _$WsRegisterImpl>
    implements _$$WsRegisterImplCopyWith<$Res> {
  __$$WsRegisterImplCopyWithImpl(
    _$WsRegisterImpl _value,
    $Res Function(_$WsRegisterImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsRegister
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? role = null,
    Object? machineId = freezed,
    Object? hostname = freezed,
    Object? connectToken = freezed,
  }) {
    return _then(
      _$WsRegisterImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        machineId: freezed == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String?,
        hostname: freezed == hostname
            ? _value.hostname
            : hostname // ignore: cast_nullable_to_non_nullable
                  as String?,
        connectToken: freezed == connectToken
            ? _value.connectToken
            : connectToken // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsRegisterImpl implements _WsRegister {
  const _$WsRegisterImpl({
    required this.type,
    required this.role,
    @JsonKey(name: 'machine_id') this.machineId,
    this.hostname,
    @JsonKey(name: 'connect_token') this.connectToken,
  });

  factory _$WsRegisterImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsRegisterImplFromJson(json);

  @override
  final String type;
  @override
  final String role;
  @override
  @JsonKey(name: 'machine_id')
  final String? machineId;
  @override
  final String? hostname;
  @override
  @JsonKey(name: 'connect_token')
  final String? connectToken;

  @override
  String toString() {
    return 'WsRegister(type: $type, role: $role, machineId: $machineId, hostname: $hostname, connectToken: $connectToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsRegisterImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId) &&
            (identical(other.hostname, hostname) ||
                other.hostname == hostname) &&
            (identical(other.connectToken, connectToken) ||
                other.connectToken == connectToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, role, machineId, hostname, connectToken);

  /// Create a copy of WsRegister
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsRegisterImplCopyWith<_$WsRegisterImpl> get copyWith =>
      __$$WsRegisterImplCopyWithImpl<_$WsRegisterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsRegisterImplToJson(this);
  }
}

abstract class _WsRegister implements WsRegister {
  const factory _WsRegister({
    required final String type,
    required final String role,
    @JsonKey(name: 'machine_id') final String? machineId,
    final String? hostname,
    @JsonKey(name: 'connect_token') final String? connectToken,
  }) = _$WsRegisterImpl;

  factory _WsRegister.fromJson(Map<String, dynamic> json) =
      _$WsRegisterImpl.fromJson;

  @override
  String get type;
  @override
  String get role;
  @override
  @JsonKey(name: 'machine_id')
  String? get machineId;
  @override
  String? get hostname;
  @override
  @JsonKey(name: 'connect_token')
  String? get connectToken;

  /// Create a copy of WsRegister
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsRegisterImplCopyWith<_$WsRegisterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsChallenge _$WsChallengeFromJson(Map<String, dynamic> json) {
  return _WsChallenge.fromJson(json);
}

/// @nodoc
mixin _$WsChallenge {
  String get type => throw _privateConstructorUsedError;
  String get nonce => throw _privateConstructorUsedError;

  /// Serializes this WsChallenge to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsChallenge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsChallengeCopyWith<WsChallenge> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsChallengeCopyWith<$Res> {
  factory $WsChallengeCopyWith(
    WsChallenge value,
    $Res Function(WsChallenge) then,
  ) = _$WsChallengeCopyWithImpl<$Res, WsChallenge>;
  @useResult
  $Res call({String type, String nonce});
}

/// @nodoc
class _$WsChallengeCopyWithImpl<$Res, $Val extends WsChallenge>
    implements $WsChallengeCopyWith<$Res> {
  _$WsChallengeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsChallenge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? nonce = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            nonce: null == nonce
                ? _value.nonce
                : nonce // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsChallengeImplCopyWith<$Res>
    implements $WsChallengeCopyWith<$Res> {
  factory _$$WsChallengeImplCopyWith(
    _$WsChallengeImpl value,
    $Res Function(_$WsChallengeImpl) then,
  ) = __$$WsChallengeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String nonce});
}

/// @nodoc
class __$$WsChallengeImplCopyWithImpl<$Res>
    extends _$WsChallengeCopyWithImpl<$Res, _$WsChallengeImpl>
    implements _$$WsChallengeImplCopyWith<$Res> {
  __$$WsChallengeImplCopyWithImpl(
    _$WsChallengeImpl _value,
    $Res Function(_$WsChallengeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsChallenge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? nonce = null}) {
    return _then(
      _$WsChallengeImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        nonce: null == nonce
            ? _value.nonce
            : nonce // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsChallengeImpl implements _WsChallenge {
  const _$WsChallengeImpl({required this.type, required this.nonce});

  factory _$WsChallengeImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsChallengeImplFromJson(json);

  @override
  final String type;
  @override
  final String nonce;

  @override
  String toString() {
    return 'WsChallenge(type: $type, nonce: $nonce)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsChallengeImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.nonce, nonce) || other.nonce == nonce));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, nonce);

  /// Create a copy of WsChallenge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsChallengeImplCopyWith<_$WsChallengeImpl> get copyWith =>
      __$$WsChallengeImplCopyWithImpl<_$WsChallengeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsChallengeImplToJson(this);
  }
}

abstract class _WsChallenge implements WsChallenge {
  const factory _WsChallenge({
    required final String type,
    required final String nonce,
  }) = _$WsChallengeImpl;

  factory _WsChallenge.fromJson(Map<String, dynamic> json) =
      _$WsChallengeImpl.fromJson;

  @override
  String get type;
  @override
  String get nonce;

  /// Create a copy of WsChallenge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsChallengeImplCopyWith<_$WsChallengeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsChallengeResponse _$WsChallengeResponseFromJson(Map<String, dynamic> json) {
  return _WsChallengeResponse.fromJson(json);
}

/// @nodoc
mixin _$WsChallengeResponse {
  String get type => throw _privateConstructorUsedError;
  String get signature => throw _privateConstructorUsedError;

  /// Serializes this WsChallengeResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsChallengeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsChallengeResponseCopyWith<WsChallengeResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsChallengeResponseCopyWith<$Res> {
  factory $WsChallengeResponseCopyWith(
    WsChallengeResponse value,
    $Res Function(WsChallengeResponse) then,
  ) = _$WsChallengeResponseCopyWithImpl<$Res, WsChallengeResponse>;
  @useResult
  $Res call({String type, String signature});
}

/// @nodoc
class _$WsChallengeResponseCopyWithImpl<$Res, $Val extends WsChallengeResponse>
    implements $WsChallengeResponseCopyWith<$Res> {
  _$WsChallengeResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsChallengeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? signature = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            signature: null == signature
                ? _value.signature
                : signature // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsChallengeResponseImplCopyWith<$Res>
    implements $WsChallengeResponseCopyWith<$Res> {
  factory _$$WsChallengeResponseImplCopyWith(
    _$WsChallengeResponseImpl value,
    $Res Function(_$WsChallengeResponseImpl) then,
  ) = __$$WsChallengeResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String signature});
}

/// @nodoc
class __$$WsChallengeResponseImplCopyWithImpl<$Res>
    extends _$WsChallengeResponseCopyWithImpl<$Res, _$WsChallengeResponseImpl>
    implements _$$WsChallengeResponseImplCopyWith<$Res> {
  __$$WsChallengeResponseImplCopyWithImpl(
    _$WsChallengeResponseImpl _value,
    $Res Function(_$WsChallengeResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsChallengeResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? signature = null}) {
    return _then(
      _$WsChallengeResponseImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        signature: null == signature
            ? _value.signature
            : signature // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsChallengeResponseImpl implements _WsChallengeResponse {
  const _$WsChallengeResponseImpl({
    required this.type,
    required this.signature,
  });

  factory _$WsChallengeResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsChallengeResponseImplFromJson(json);

  @override
  final String type;
  @override
  final String signature;

  @override
  String toString() {
    return 'WsChallengeResponse(type: $type, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsChallengeResponseImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.signature, signature) ||
                other.signature == signature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, signature);

  /// Create a copy of WsChallengeResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsChallengeResponseImplCopyWith<_$WsChallengeResponseImpl> get copyWith =>
      __$$WsChallengeResponseImplCopyWithImpl<_$WsChallengeResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WsChallengeResponseImplToJson(this);
  }
}

abstract class _WsChallengeResponse implements WsChallengeResponse {
  const factory _WsChallengeResponse({
    required final String type,
    required final String signature,
  }) = _$WsChallengeResponseImpl;

  factory _WsChallengeResponse.fromJson(Map<String, dynamic> json) =
      _$WsChallengeResponseImpl.fromJson;

  @override
  String get type;
  @override
  String get signature;

  /// Create a copy of WsChallengeResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsChallengeResponseImplCopyWith<_$WsChallengeResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsRegistered _$WsRegisteredFromJson(Map<String, dynamic> json) {
  return _WsRegistered.fromJson(json);
}

/// @nodoc
mixin _$WsRegistered {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'master_id')
  String? get masterId => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_id')
  String? get machineId => throw _privateConstructorUsedError;

  /// Serializes this WsRegistered to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsRegistered
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsRegisteredCopyWith<WsRegistered> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsRegisteredCopyWith<$Res> {
  factory $WsRegisteredCopyWith(
    WsRegistered value,
    $Res Function(WsRegistered) then,
  ) = _$WsRegisteredCopyWithImpl<$Res, WsRegistered>;
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'master_id') String? masterId,
    @JsonKey(name: 'machine_id') String? machineId,
  });
}

/// @nodoc
class _$WsRegisteredCopyWithImpl<$Res, $Val extends WsRegistered>
    implements $WsRegisteredCopyWith<$Res> {
  _$WsRegisteredCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsRegistered
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? masterId = freezed,
    Object? machineId = freezed,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            masterId: freezed == masterId
                ? _value.masterId
                : masterId // ignore: cast_nullable_to_non_nullable
                      as String?,
            machineId: freezed == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsRegisteredImplCopyWith<$Res>
    implements $WsRegisteredCopyWith<$Res> {
  factory _$$WsRegisteredImplCopyWith(
    _$WsRegisteredImpl value,
    $Res Function(_$WsRegisteredImpl) then,
  ) = __$$WsRegisteredImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'master_id') String? masterId,
    @JsonKey(name: 'machine_id') String? machineId,
  });
}

/// @nodoc
class __$$WsRegisteredImplCopyWithImpl<$Res>
    extends _$WsRegisteredCopyWithImpl<$Res, _$WsRegisteredImpl>
    implements _$$WsRegisteredImplCopyWith<$Res> {
  __$$WsRegisteredImplCopyWithImpl(
    _$WsRegisteredImpl _value,
    $Res Function(_$WsRegisteredImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsRegistered
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? masterId = freezed,
    Object? machineId = freezed,
  }) {
    return _then(
      _$WsRegisteredImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        masterId: freezed == masterId
            ? _value.masterId
            : masterId // ignore: cast_nullable_to_non_nullable
                  as String?,
        machineId: freezed == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsRegisteredImpl implements _WsRegistered {
  const _$WsRegisteredImpl({
    required this.type,
    @JsonKey(name: 'master_id') this.masterId,
    @JsonKey(name: 'machine_id') this.machineId,
  });

  factory _$WsRegisteredImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsRegisteredImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'master_id')
  final String? masterId;
  @override
  @JsonKey(name: 'machine_id')
  final String? machineId;

  @override
  String toString() {
    return 'WsRegistered(type: $type, masterId: $masterId, machineId: $machineId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsRegisteredImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.masterId, masterId) ||
                other.masterId == masterId) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, masterId, machineId);

  /// Create a copy of WsRegistered
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsRegisteredImplCopyWith<_$WsRegisteredImpl> get copyWith =>
      __$$WsRegisteredImplCopyWithImpl<_$WsRegisteredImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsRegisteredImplToJson(this);
  }
}

abstract class _WsRegistered implements WsRegistered {
  const factory _WsRegistered({
    required final String type,
    @JsonKey(name: 'master_id') final String? masterId,
    @JsonKey(name: 'machine_id') final String? machineId,
  }) = _$WsRegisteredImpl;

  factory _WsRegistered.fromJson(Map<String, dynamic> json) =
      _$WsRegisteredImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'master_id')
  String? get masterId;
  @override
  @JsonKey(name: 'machine_id')
  String? get machineId;

  /// Create a copy of WsRegistered
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsRegisteredImplCopyWith<_$WsRegisteredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsSessionInit _$WsSessionInitFromJson(Map<String, dynamic> json) {
  return _WsSessionInit.fromJson(json);
}

/// @nodoc
mixin _$WsSessionInit {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_id')
  String get machineId => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_token')
  String get machineToken => throw _privateConstructorUsedError;
  @JsonKey(name: 'client_ephemeral_pub')
  String get clientEphemeralPub => throw _privateConstructorUsedError;
  String get signature => throw _privateConstructorUsedError;

  /// Serializes this WsSessionInit to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsSessionInit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsSessionInitCopyWith<WsSessionInit> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsSessionInitCopyWith<$Res> {
  factory $WsSessionInitCopyWith(
    WsSessionInit value,
    $Res Function(WsSessionInit) then,
  ) = _$WsSessionInitCopyWithImpl<$Res, WsSessionInit>;
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'machine_id') String machineId,
    @JsonKey(name: 'machine_token') String machineToken,
    @JsonKey(name: 'client_ephemeral_pub') String clientEphemeralPub,
    String signature,
  });
}

/// @nodoc
class _$WsSessionInitCopyWithImpl<$Res, $Val extends WsSessionInit>
    implements $WsSessionInitCopyWith<$Res> {
  _$WsSessionInitCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsSessionInit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? machineId = null,
    Object? machineToken = null,
    Object? clientEphemeralPub = null,
    Object? signature = null,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            machineId: null == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String,
            machineToken: null == machineToken
                ? _value.machineToken
                : machineToken // ignore: cast_nullable_to_non_nullable
                      as String,
            clientEphemeralPub: null == clientEphemeralPub
                ? _value.clientEphemeralPub
                : clientEphemeralPub // ignore: cast_nullable_to_non_nullable
                      as String,
            signature: null == signature
                ? _value.signature
                : signature // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsSessionInitImplCopyWith<$Res>
    implements $WsSessionInitCopyWith<$Res> {
  factory _$$WsSessionInitImplCopyWith(
    _$WsSessionInitImpl value,
    $Res Function(_$WsSessionInitImpl) then,
  ) = __$$WsSessionInitImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'machine_id') String machineId,
    @JsonKey(name: 'machine_token') String machineToken,
    @JsonKey(name: 'client_ephemeral_pub') String clientEphemeralPub,
    String signature,
  });
}

/// @nodoc
class __$$WsSessionInitImplCopyWithImpl<$Res>
    extends _$WsSessionInitCopyWithImpl<$Res, _$WsSessionInitImpl>
    implements _$$WsSessionInitImplCopyWith<$Res> {
  __$$WsSessionInitImplCopyWithImpl(
    _$WsSessionInitImpl _value,
    $Res Function(_$WsSessionInitImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsSessionInit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? machineId = null,
    Object? machineToken = null,
    Object? clientEphemeralPub = null,
    Object? signature = null,
  }) {
    return _then(
      _$WsSessionInitImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        machineId: null == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String,
        machineToken: null == machineToken
            ? _value.machineToken
            : machineToken // ignore: cast_nullable_to_non_nullable
                  as String,
        clientEphemeralPub: null == clientEphemeralPub
            ? _value.clientEphemeralPub
            : clientEphemeralPub // ignore: cast_nullable_to_non_nullable
                  as String,
        signature: null == signature
            ? _value.signature
            : signature // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsSessionInitImpl implements _WsSessionInit {
  const _$WsSessionInitImpl({
    required this.type,
    @JsonKey(name: 'machine_id') required this.machineId,
    @JsonKey(name: 'machine_token') required this.machineToken,
    @JsonKey(name: 'client_ephemeral_pub') required this.clientEphemeralPub,
    required this.signature,
  });

  factory _$WsSessionInitImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsSessionInitImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'machine_id')
  final String machineId;
  @override
  @JsonKey(name: 'machine_token')
  final String machineToken;
  @override
  @JsonKey(name: 'client_ephemeral_pub')
  final String clientEphemeralPub;
  @override
  final String signature;

  @override
  String toString() {
    return 'WsSessionInit(type: $type, machineId: $machineId, machineToken: $machineToken, clientEphemeralPub: $clientEphemeralPub, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsSessionInitImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId) &&
            (identical(other.machineToken, machineToken) ||
                other.machineToken == machineToken) &&
            (identical(other.clientEphemeralPub, clientEphemeralPub) ||
                other.clientEphemeralPub == clientEphemeralPub) &&
            (identical(other.signature, signature) ||
                other.signature == signature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    type,
    machineId,
    machineToken,
    clientEphemeralPub,
    signature,
  );

  /// Create a copy of WsSessionInit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsSessionInitImplCopyWith<_$WsSessionInitImpl> get copyWith =>
      __$$WsSessionInitImplCopyWithImpl<_$WsSessionInitImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsSessionInitImplToJson(this);
  }
}

abstract class _WsSessionInit implements WsSessionInit {
  const factory _WsSessionInit({
    required final String type,
    @JsonKey(name: 'machine_id') required final String machineId,
    @JsonKey(name: 'machine_token') required final String machineToken,
    @JsonKey(name: 'client_ephemeral_pub')
    required final String clientEphemeralPub,
    required final String signature,
  }) = _$WsSessionInitImpl;

  factory _WsSessionInit.fromJson(Map<String, dynamic> json) =
      _$WsSessionInitImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'machine_id')
  String get machineId;
  @override
  @JsonKey(name: 'machine_token')
  String get machineToken;
  @override
  @JsonKey(name: 'client_ephemeral_pub')
  String get clientEphemeralPub;
  @override
  String get signature;

  /// Create a copy of WsSessionInit
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsSessionInitImplCopyWith<_$WsSessionInitImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsSessionAck _$WsSessionAckFromJson(Map<String, dynamic> json) {
  return _WsSessionAck.fromJson(json);
}

/// @nodoc
mixin _$WsSessionAck {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_id')
  String get machineId => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_ephemeral_pub')
  String get machineEphemeralPub => throw _privateConstructorUsedError;
  String get signature => throw _privateConstructorUsedError;

  /// Serializes this WsSessionAck to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsSessionAck
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsSessionAckCopyWith<WsSessionAck> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsSessionAckCopyWith<$Res> {
  factory $WsSessionAckCopyWith(
    WsSessionAck value,
    $Res Function(WsSessionAck) then,
  ) = _$WsSessionAckCopyWithImpl<$Res, WsSessionAck>;
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'machine_id') String machineId,
    @JsonKey(name: 'machine_ephemeral_pub') String machineEphemeralPub,
    String signature,
  });
}

/// @nodoc
class _$WsSessionAckCopyWithImpl<$Res, $Val extends WsSessionAck>
    implements $WsSessionAckCopyWith<$Res> {
  _$WsSessionAckCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsSessionAck
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? machineId = null,
    Object? machineEphemeralPub = null,
    Object? signature = null,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            machineId: null == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String,
            machineEphemeralPub: null == machineEphemeralPub
                ? _value.machineEphemeralPub
                : machineEphemeralPub // ignore: cast_nullable_to_non_nullable
                      as String,
            signature: null == signature
                ? _value.signature
                : signature // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsSessionAckImplCopyWith<$Res>
    implements $WsSessionAckCopyWith<$Res> {
  factory _$$WsSessionAckImplCopyWith(
    _$WsSessionAckImpl value,
    $Res Function(_$WsSessionAckImpl) then,
  ) = __$$WsSessionAckImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'machine_id') String machineId,
    @JsonKey(name: 'machine_ephemeral_pub') String machineEphemeralPub,
    String signature,
  });
}

/// @nodoc
class __$$WsSessionAckImplCopyWithImpl<$Res>
    extends _$WsSessionAckCopyWithImpl<$Res, _$WsSessionAckImpl>
    implements _$$WsSessionAckImplCopyWith<$Res> {
  __$$WsSessionAckImplCopyWithImpl(
    _$WsSessionAckImpl _value,
    $Res Function(_$WsSessionAckImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsSessionAck
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? machineId = null,
    Object? machineEphemeralPub = null,
    Object? signature = null,
  }) {
    return _then(
      _$WsSessionAckImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        machineId: null == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String,
        machineEphemeralPub: null == machineEphemeralPub
            ? _value.machineEphemeralPub
            : machineEphemeralPub // ignore: cast_nullable_to_non_nullable
                  as String,
        signature: null == signature
            ? _value.signature
            : signature // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsSessionAckImpl implements _WsSessionAck {
  const _$WsSessionAckImpl({
    required this.type,
    @JsonKey(name: 'machine_id') required this.machineId,
    @JsonKey(name: 'machine_ephemeral_pub') required this.machineEphemeralPub,
    required this.signature,
  });

  factory _$WsSessionAckImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsSessionAckImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'machine_id')
  final String machineId;
  @override
  @JsonKey(name: 'machine_ephemeral_pub')
  final String machineEphemeralPub;
  @override
  final String signature;

  @override
  String toString() {
    return 'WsSessionAck(type: $type, machineId: $machineId, machineEphemeralPub: $machineEphemeralPub, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsSessionAckImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId) &&
            (identical(other.machineEphemeralPub, machineEphemeralPub) ||
                other.machineEphemeralPub == machineEphemeralPub) &&
            (identical(other.signature, signature) ||
                other.signature == signature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, machineId, machineEphemeralPub, signature);

  /// Create a copy of WsSessionAck
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsSessionAckImplCopyWith<_$WsSessionAckImpl> get copyWith =>
      __$$WsSessionAckImplCopyWithImpl<_$WsSessionAckImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsSessionAckImplToJson(this);
  }
}

abstract class _WsSessionAck implements WsSessionAck {
  const factory _WsSessionAck({
    required final String type,
    @JsonKey(name: 'machine_id') required final String machineId,
    @JsonKey(name: 'machine_ephemeral_pub')
    required final String machineEphemeralPub,
    required final String signature,
  }) = _$WsSessionAckImpl;

  factory _WsSessionAck.fromJson(Map<String, dynamic> json) =
      _$WsSessionAckImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'machine_id')
  String get machineId;
  @override
  @JsonKey(name: 'machine_ephemeral_pub')
  String get machineEphemeralPub;
  @override
  String get signature;

  /// Create a copy of WsSessionAck
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsSessionAckImplCopyWith<_$WsSessionAckImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsSessionEnd _$WsSessionEndFromJson(Map<String, dynamic> json) {
  return _WsSessionEnd.fromJson(json);
}

/// @nodoc
mixin _$WsSessionEnd {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_id')
  String get machineId => throw _privateConstructorUsedError;

  /// Serializes this WsSessionEnd to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsSessionEnd
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsSessionEndCopyWith<WsSessionEnd> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsSessionEndCopyWith<$Res> {
  factory $WsSessionEndCopyWith(
    WsSessionEnd value,
    $Res Function(WsSessionEnd) then,
  ) = _$WsSessionEndCopyWithImpl<$Res, WsSessionEnd>;
  @useResult
  $Res call({String type, @JsonKey(name: 'machine_id') String machineId});
}

/// @nodoc
class _$WsSessionEndCopyWithImpl<$Res, $Val extends WsSessionEnd>
    implements $WsSessionEndCopyWith<$Res> {
  _$WsSessionEndCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsSessionEnd
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? machineId = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            machineId: null == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsSessionEndImplCopyWith<$Res>
    implements $WsSessionEndCopyWith<$Res> {
  factory _$$WsSessionEndImplCopyWith(
    _$WsSessionEndImpl value,
    $Res Function(_$WsSessionEndImpl) then,
  ) = __$$WsSessionEndImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, @JsonKey(name: 'machine_id') String machineId});
}

/// @nodoc
class __$$WsSessionEndImplCopyWithImpl<$Res>
    extends _$WsSessionEndCopyWithImpl<$Res, _$WsSessionEndImpl>
    implements _$$WsSessionEndImplCopyWith<$Res> {
  __$$WsSessionEndImplCopyWithImpl(
    _$WsSessionEndImpl _value,
    $Res Function(_$WsSessionEndImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsSessionEnd
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? machineId = null}) {
    return _then(
      _$WsSessionEndImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        machineId: null == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsSessionEndImpl implements _WsSessionEnd {
  const _$WsSessionEndImpl({
    required this.type,
    @JsonKey(name: 'machine_id') required this.machineId,
  });

  factory _$WsSessionEndImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsSessionEndImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'machine_id')
  final String machineId;

  @override
  String toString() {
    return 'WsSessionEnd(type: $type, machineId: $machineId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsSessionEndImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, machineId);

  /// Create a copy of WsSessionEnd
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsSessionEndImplCopyWith<_$WsSessionEndImpl> get copyWith =>
      __$$WsSessionEndImplCopyWithImpl<_$WsSessionEndImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsSessionEndImplToJson(this);
  }
}

abstract class _WsSessionEnd implements WsSessionEnd {
  const factory _WsSessionEnd({
    required final String type,
    @JsonKey(name: 'machine_id') required final String machineId,
  }) = _$WsSessionEndImpl;

  factory _WsSessionEnd.fromJson(Map<String, dynamic> json) =
      _$WsSessionEndImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'machine_id')
  String get machineId;

  /// Create a copy of WsSessionEnd
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsSessionEndImplCopyWith<_$WsSessionEndImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsEncryptedMessage _$WsEncryptedMessageFromJson(Map<String, dynamic> json) {
  return _WsEncryptedMessage.fromJson(json);
}

/// @nodoc
mixin _$WsEncryptedMessage {
  String get type => throw _privateConstructorUsedError;
  @JsonKey(name: 'machine_id')
  String get machineId => throw _privateConstructorUsedError;
  @JsonKey(name: 'msg_id')
  String get msgId => throw _privateConstructorUsedError;
  String get nonce => throw _privateConstructorUsedError;
  String get ciphertext => throw _privateConstructorUsedError;

  /// Serializes this WsEncryptedMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsEncryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsEncryptedMessageCopyWith<WsEncryptedMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsEncryptedMessageCopyWith<$Res> {
  factory $WsEncryptedMessageCopyWith(
    WsEncryptedMessage value,
    $Res Function(WsEncryptedMessage) then,
  ) = _$WsEncryptedMessageCopyWithImpl<$Res, WsEncryptedMessage>;
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'machine_id') String machineId,
    @JsonKey(name: 'msg_id') String msgId,
    String nonce,
    String ciphertext,
  });
}

/// @nodoc
class _$WsEncryptedMessageCopyWithImpl<$Res, $Val extends WsEncryptedMessage>
    implements $WsEncryptedMessageCopyWith<$Res> {
  _$WsEncryptedMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsEncryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? machineId = null,
    Object? msgId = null,
    Object? nonce = null,
    Object? ciphertext = null,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            machineId: null == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String,
            msgId: null == msgId
                ? _value.msgId
                : msgId // ignore: cast_nullable_to_non_nullable
                      as String,
            nonce: null == nonce
                ? _value.nonce
                : nonce // ignore: cast_nullable_to_non_nullable
                      as String,
            ciphertext: null == ciphertext
                ? _value.ciphertext
                : ciphertext // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsEncryptedMessageImplCopyWith<$Res>
    implements $WsEncryptedMessageCopyWith<$Res> {
  factory _$$WsEncryptedMessageImplCopyWith(
    _$WsEncryptedMessageImpl value,
    $Res Function(_$WsEncryptedMessageImpl) then,
  ) = __$$WsEncryptedMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String type,
    @JsonKey(name: 'machine_id') String machineId,
    @JsonKey(name: 'msg_id') String msgId,
    String nonce,
    String ciphertext,
  });
}

/// @nodoc
class __$$WsEncryptedMessageImplCopyWithImpl<$Res>
    extends _$WsEncryptedMessageCopyWithImpl<$Res, _$WsEncryptedMessageImpl>
    implements _$$WsEncryptedMessageImplCopyWith<$Res> {
  __$$WsEncryptedMessageImplCopyWithImpl(
    _$WsEncryptedMessageImpl _value,
    $Res Function(_$WsEncryptedMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsEncryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? machineId = null,
    Object? msgId = null,
    Object? nonce = null,
    Object? ciphertext = null,
  }) {
    return _then(
      _$WsEncryptedMessageImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        machineId: null == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String,
        msgId: null == msgId
            ? _value.msgId
            : msgId // ignore: cast_nullable_to_non_nullable
                  as String,
        nonce: null == nonce
            ? _value.nonce
            : nonce // ignore: cast_nullable_to_non_nullable
                  as String,
        ciphertext: null == ciphertext
            ? _value.ciphertext
            : ciphertext // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsEncryptedMessageImpl implements _WsEncryptedMessage {
  const _$WsEncryptedMessageImpl({
    required this.type,
    @JsonKey(name: 'machine_id') required this.machineId,
    @JsonKey(name: 'msg_id') required this.msgId,
    required this.nonce,
    required this.ciphertext,
  });

  factory _$WsEncryptedMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsEncryptedMessageImplFromJson(json);

  @override
  final String type;
  @override
  @JsonKey(name: 'machine_id')
  final String machineId;
  @override
  @JsonKey(name: 'msg_id')
  final String msgId;
  @override
  final String nonce;
  @override
  final String ciphertext;

  @override
  String toString() {
    return 'WsEncryptedMessage(type: $type, machineId: $machineId, msgId: $msgId, nonce: $nonce, ciphertext: $ciphertext)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsEncryptedMessageImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId) &&
            (identical(other.msgId, msgId) || other.msgId == msgId) &&
            (identical(other.nonce, nonce) || other.nonce == nonce) &&
            (identical(other.ciphertext, ciphertext) ||
                other.ciphertext == ciphertext));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, machineId, msgId, nonce, ciphertext);

  /// Create a copy of WsEncryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsEncryptedMessageImplCopyWith<_$WsEncryptedMessageImpl> get copyWith =>
      __$$WsEncryptedMessageImplCopyWithImpl<_$WsEncryptedMessageImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WsEncryptedMessageImplToJson(this);
  }
}

abstract class _WsEncryptedMessage implements WsEncryptedMessage {
  const factory _WsEncryptedMessage({
    required final String type,
    @JsonKey(name: 'machine_id') required final String machineId,
    @JsonKey(name: 'msg_id') required final String msgId,
    required final String nonce,
    required final String ciphertext,
  }) = _$WsEncryptedMessageImpl;

  factory _WsEncryptedMessage.fromJson(Map<String, dynamic> json) =
      _$WsEncryptedMessageImpl.fromJson;

  @override
  String get type;
  @override
  @JsonKey(name: 'machine_id')
  String get machineId;
  @override
  @JsonKey(name: 'msg_id')
  String get msgId;
  @override
  String get nonce;
  @override
  String get ciphertext;

  /// Create a copy of WsEncryptedMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsEncryptedMessageImplCopyWith<_$WsEncryptedMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsErrorMessage _$WsErrorMessageFromJson(Map<String, dynamic> json) {
  return _WsErrorMessage.fromJson(json);
}

/// @nodoc
mixin _$WsErrorMessage {
  String get type => throw _privateConstructorUsedError;
  String get error => throw _privateConstructorUsedError;

  /// Serializes this WsErrorMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsErrorMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsErrorMessageCopyWith<WsErrorMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsErrorMessageCopyWith<$Res> {
  factory $WsErrorMessageCopyWith(
    WsErrorMessage value,
    $Res Function(WsErrorMessage) then,
  ) = _$WsErrorMessageCopyWithImpl<$Res, WsErrorMessage>;
  @useResult
  $Res call({String type, String error});
}

/// @nodoc
class _$WsErrorMessageCopyWithImpl<$Res, $Val extends WsErrorMessage>
    implements $WsErrorMessageCopyWith<$Res> {
  _$WsErrorMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsErrorMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? error = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            error: null == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsErrorMessageImplCopyWith<$Res>
    implements $WsErrorMessageCopyWith<$Res> {
  factory _$$WsErrorMessageImplCopyWith(
    _$WsErrorMessageImpl value,
    $Res Function(_$WsErrorMessageImpl) then,
  ) = __$$WsErrorMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, String error});
}

/// @nodoc
class __$$WsErrorMessageImplCopyWithImpl<$Res>
    extends _$WsErrorMessageCopyWithImpl<$Res, _$WsErrorMessageImpl>
    implements _$$WsErrorMessageImplCopyWith<$Res> {
  __$$WsErrorMessageImplCopyWithImpl(
    _$WsErrorMessageImpl _value,
    $Res Function(_$WsErrorMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsErrorMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? error = null}) {
    return _then(
      _$WsErrorMessageImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        error: null == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsErrorMessageImpl implements _WsErrorMessage {
  const _$WsErrorMessageImpl({required this.type, required this.error});

  factory _$WsErrorMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsErrorMessageImplFromJson(json);

  @override
  final String type;
  @override
  final String error;

  @override
  String toString() {
    return 'WsErrorMessage(type: $type, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsErrorMessageImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.error, error) || other.error == error));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, error);

  /// Create a copy of WsErrorMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsErrorMessageImplCopyWith<_$WsErrorMessageImpl> get copyWith =>
      __$$WsErrorMessageImplCopyWithImpl<_$WsErrorMessageImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WsErrorMessageImplToJson(this);
  }
}

abstract class _WsErrorMessage implements WsErrorMessage {
  const factory _WsErrorMessage({
    required final String type,
    required final String error,
  }) = _$WsErrorMessageImpl;

  factory _WsErrorMessage.fromJson(Map<String, dynamic> json) =
      _$WsErrorMessageImpl.fromJson;

  @override
  String get type;
  @override
  String get error;

  /// Create a copy of WsErrorMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsErrorMessageImplCopyWith<_$WsErrorMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsEvent _$WsEventFromJson(Map<String, dynamic> json) {
  return _WsEvent.fromJson(json);
}

/// @nodoc
mixin _$WsEvent {
  String get type => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;

  /// Serializes this WsEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsEventCopyWith<WsEvent> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsEventCopyWith<$Res> {
  factory $WsEventCopyWith(WsEvent value, $Res Function(WsEvent) then) =
      _$WsEventCopyWithImpl<$Res, WsEvent>;
  @useResult
  $Res call({String type, Map<String, dynamic> payload});
}

/// @nodoc
class _$WsEventCopyWithImpl<$Res, $Val extends WsEvent>
    implements $WsEventCopyWith<$Res> {
  _$WsEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? payload = null}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            payload: null == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsEventImplCopyWith<$Res> implements $WsEventCopyWith<$Res> {
  factory _$$WsEventImplCopyWith(
    _$WsEventImpl value,
    $Res Function(_$WsEventImpl) then,
  ) = __$$WsEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, Map<String, dynamic> payload});
}

/// @nodoc
class __$$WsEventImplCopyWithImpl<$Res>
    extends _$WsEventCopyWithImpl<$Res, _$WsEventImpl>
    implements _$$WsEventImplCopyWith<$Res> {
  __$$WsEventImplCopyWithImpl(
    _$WsEventImpl _value,
    $Res Function(_$WsEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? payload = null}) {
    return _then(
      _$WsEventImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        payload: null == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsEventImpl implements _WsEvent {
  const _$WsEventImpl({
    required this.type,
    required final Map<String, dynamic> payload,
  }) : _payload = payload;

  factory _$WsEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsEventImplFromJson(json);

  @override
  final String type;
  final Map<String, dynamic> _payload;
  @override
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  String toString() {
    return 'WsEvent(type: $type, payload: $payload)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsEventImpl &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._payload, _payload));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    type,
    const DeepCollectionEquality().hash(_payload),
  );

  /// Create a copy of WsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsEventImplCopyWith<_$WsEventImpl> get copyWith =>
      __$$WsEventImplCopyWithImpl<_$WsEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsEventImplToJson(this);
  }
}

abstract class _WsEvent implements WsEvent {
  const factory _WsEvent({
    required final String type,
    required final Map<String, dynamic> payload,
  }) = _$WsEventImpl;

  factory _WsEvent.fromJson(Map<String, dynamic> json) = _$WsEventImpl.fromJson;

  @override
  String get type;
  @override
  Map<String, dynamic> get payload;

  /// Create a copy of WsEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsEventImplCopyWith<_$WsEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

WsRpcPayload _$WsRpcPayloadFromJson(Map<String, dynamic> json) {
  return _WsRpcPayload.fromJson(json);
}

/// @nodoc
mixin _$WsRpcPayload {
  String get method => throw _privateConstructorUsedError;
  Map<String, dynamic>? get params => throw _privateConstructorUsedError;

  /// Serializes this WsRpcPayload to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WsRpcPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WsRpcPayloadCopyWith<WsRpcPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WsRpcPayloadCopyWith<$Res> {
  factory $WsRpcPayloadCopyWith(
    WsRpcPayload value,
    $Res Function(WsRpcPayload) then,
  ) = _$WsRpcPayloadCopyWithImpl<$Res, WsRpcPayload>;
  @useResult
  $Res call({String method, Map<String, dynamic>? params});
}

/// @nodoc
class _$WsRpcPayloadCopyWithImpl<$Res, $Val extends WsRpcPayload>
    implements $WsRpcPayloadCopyWith<$Res> {
  _$WsRpcPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WsRpcPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? method = null, Object? params = freezed}) {
    return _then(
      _value.copyWith(
            method: null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                      as String,
            params: freezed == params
                ? _value.params
                : params // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WsRpcPayloadImplCopyWith<$Res>
    implements $WsRpcPayloadCopyWith<$Res> {
  factory _$$WsRpcPayloadImplCopyWith(
    _$WsRpcPayloadImpl value,
    $Res Function(_$WsRpcPayloadImpl) then,
  ) = __$$WsRpcPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String method, Map<String, dynamic>? params});
}

/// @nodoc
class __$$WsRpcPayloadImplCopyWithImpl<$Res>
    extends _$WsRpcPayloadCopyWithImpl<$Res, _$WsRpcPayloadImpl>
    implements _$$WsRpcPayloadImplCopyWith<$Res> {
  __$$WsRpcPayloadImplCopyWithImpl(
    _$WsRpcPayloadImpl _value,
    $Res Function(_$WsRpcPayloadImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WsRpcPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? method = null, Object? params = freezed}) {
    return _then(
      _$WsRpcPayloadImpl(
        method: null == method
            ? _value.method
            : method // ignore: cast_nullable_to_non_nullable
                  as String,
        params: freezed == params
            ? _value._params
            : params // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WsRpcPayloadImpl implements _WsRpcPayload {
  const _$WsRpcPayloadImpl({
    required this.method,
    final Map<String, dynamic>? params,
  }) : _params = params;

  factory _$WsRpcPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$WsRpcPayloadImplFromJson(json);

  @override
  final String method;
  final Map<String, dynamic>? _params;
  @override
  Map<String, dynamic>? get params {
    final value = _params;
    if (value == null) return null;
    if (_params is EqualUnmodifiableMapView) return _params;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'WsRpcPayload(method: $method, params: $params)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WsRpcPayloadImpl &&
            (identical(other.method, method) || other.method == method) &&
            const DeepCollectionEquality().equals(other._params, _params));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    method,
    const DeepCollectionEquality().hash(_params),
  );

  /// Create a copy of WsRpcPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WsRpcPayloadImplCopyWith<_$WsRpcPayloadImpl> get copyWith =>
      __$$WsRpcPayloadImplCopyWithImpl<_$WsRpcPayloadImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WsRpcPayloadImplToJson(this);
  }
}

abstract class _WsRpcPayload implements WsRpcPayload {
  const factory _WsRpcPayload({
    required final String method,
    final Map<String, dynamic>? params,
  }) = _$WsRpcPayloadImpl;

  factory _WsRpcPayload.fromJson(Map<String, dynamic> json) =
      _$WsRpcPayloadImpl.fromJson;

  @override
  String get method;
  @override
  Map<String, dynamic>? get params;

  /// Create a copy of WsRpcPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WsRpcPayloadImplCopyWith<_$WsRpcPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
