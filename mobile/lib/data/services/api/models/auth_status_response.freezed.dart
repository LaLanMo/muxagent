// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_status_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AuthStatusResponse _$AuthStatusResponseFromJson(Map<String, dynamic> json) {
  return _AuthStatusResponse.fromJson(json);
}

/// @nodoc
mixin _$AuthStatusResponse {
  String get state => throw _privateConstructorUsedError;
  String? get requestId => throw _privateConstructorUsedError;
  String? get machineId => throw _privateConstructorUsedError;
  String? get machineSignPub => throw _privateConstructorUsedError;
  String? get machineEncPub => throw _privateConstructorUsedError;
  String? get machineHostname => throw _privateConstructorUsedError;
  String? get relayChallenge => throw _privateConstructorUsedError;
  int? get expiresAt => throw _privateConstructorUsedError;
  int? get approvedAt => throw _privateConstructorUsedError;
  String? get approvedByMasterSignKeyFingerprint =>
      throw _privateConstructorUsedError;
  String? get approvalSignature => throw _privateConstructorUsedError;
  String? get masterId => throw _privateConstructorUsedError;
  KeyringState? get keyring => throw _privateConstructorUsedError;
  String? get relayPubKey => throw _privateConstructorUsedError;
  String? get relaySignature => throw _privateConstructorUsedError;

  /// Serializes this AuthStatusResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AuthStatusResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AuthStatusResponseCopyWith<AuthStatusResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AuthStatusResponseCopyWith<$Res> {
  factory $AuthStatusResponseCopyWith(
    AuthStatusResponse value,
    $Res Function(AuthStatusResponse) then,
  ) = _$AuthStatusResponseCopyWithImpl<$Res, AuthStatusResponse>;
  @useResult
  $Res call({
    String state,
    String? requestId,
    String? machineId,
    String? machineSignPub,
    String? machineEncPub,
    String? machineHostname,
    String? relayChallenge,
    int? expiresAt,
    int? approvedAt,
    String? approvedByMasterSignKeyFingerprint,
    String? approvalSignature,
    String? masterId,
    KeyringState? keyring,
    String? relayPubKey,
    String? relaySignature,
  });

  $KeyringStateCopyWith<$Res>? get keyring;
}

/// @nodoc
class _$AuthStatusResponseCopyWithImpl<$Res, $Val extends AuthStatusResponse>
    implements $AuthStatusResponseCopyWith<$Res> {
  _$AuthStatusResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AuthStatusResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? requestId = freezed,
    Object? machineId = freezed,
    Object? machineSignPub = freezed,
    Object? machineEncPub = freezed,
    Object? machineHostname = freezed,
    Object? relayChallenge = freezed,
    Object? expiresAt = freezed,
    Object? approvedAt = freezed,
    Object? approvedByMasterSignKeyFingerprint = freezed,
    Object? approvalSignature = freezed,
    Object? masterId = freezed,
    Object? keyring = freezed,
    Object? relayPubKey = freezed,
    Object? relaySignature = freezed,
  }) {
    return _then(
      _value.copyWith(
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as String,
            requestId: freezed == requestId
                ? _value.requestId
                : requestId // ignore: cast_nullable_to_non_nullable
                      as String?,
            machineId: freezed == machineId
                ? _value.machineId
                : machineId // ignore: cast_nullable_to_non_nullable
                      as String?,
            machineSignPub: freezed == machineSignPub
                ? _value.machineSignPub
                : machineSignPub // ignore: cast_nullable_to_non_nullable
                      as String?,
            machineEncPub: freezed == machineEncPub
                ? _value.machineEncPub
                : machineEncPub // ignore: cast_nullable_to_non_nullable
                      as String?,
            machineHostname: freezed == machineHostname
                ? _value.machineHostname
                : machineHostname // ignore: cast_nullable_to_non_nullable
                      as String?,
            relayChallenge: freezed == relayChallenge
                ? _value.relayChallenge
                : relayChallenge // ignore: cast_nullable_to_non_nullable
                      as String?,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as int?,
            approvedAt: freezed == approvedAt
                ? _value.approvedAt
                : approvedAt // ignore: cast_nullable_to_non_nullable
                      as int?,
            approvedByMasterSignKeyFingerprint:
                freezed == approvedByMasterSignKeyFingerprint
                ? _value.approvedByMasterSignKeyFingerprint
                : approvedByMasterSignKeyFingerprint // ignore: cast_nullable_to_non_nullable
                      as String?,
            approvalSignature: freezed == approvalSignature
                ? _value.approvalSignature
                : approvalSignature // ignore: cast_nullable_to_non_nullable
                      as String?,
            masterId: freezed == masterId
                ? _value.masterId
                : masterId // ignore: cast_nullable_to_non_nullable
                      as String?,
            keyring: freezed == keyring
                ? _value.keyring
                : keyring // ignore: cast_nullable_to_non_nullable
                      as KeyringState?,
            relayPubKey: freezed == relayPubKey
                ? _value.relayPubKey
                : relayPubKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            relaySignature: freezed == relaySignature
                ? _value.relaySignature
                : relaySignature // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of AuthStatusResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $KeyringStateCopyWith<$Res>? get keyring {
    if (_value.keyring == null) {
      return null;
    }

    return $KeyringStateCopyWith<$Res>(_value.keyring!, (value) {
      return _then(_value.copyWith(keyring: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AuthStatusResponseImplCopyWith<$Res>
    implements $AuthStatusResponseCopyWith<$Res> {
  factory _$$AuthStatusResponseImplCopyWith(
    _$AuthStatusResponseImpl value,
    $Res Function(_$AuthStatusResponseImpl) then,
  ) = __$$AuthStatusResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String state,
    String? requestId,
    String? machineId,
    String? machineSignPub,
    String? machineEncPub,
    String? machineHostname,
    String? relayChallenge,
    int? expiresAt,
    int? approvedAt,
    String? approvedByMasterSignKeyFingerprint,
    String? approvalSignature,
    String? masterId,
    KeyringState? keyring,
    String? relayPubKey,
    String? relaySignature,
  });

  @override
  $KeyringStateCopyWith<$Res>? get keyring;
}

/// @nodoc
class __$$AuthStatusResponseImplCopyWithImpl<$Res>
    extends _$AuthStatusResponseCopyWithImpl<$Res, _$AuthStatusResponseImpl>
    implements _$$AuthStatusResponseImplCopyWith<$Res> {
  __$$AuthStatusResponseImplCopyWithImpl(
    _$AuthStatusResponseImpl _value,
    $Res Function(_$AuthStatusResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AuthStatusResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? requestId = freezed,
    Object? machineId = freezed,
    Object? machineSignPub = freezed,
    Object? machineEncPub = freezed,
    Object? machineHostname = freezed,
    Object? relayChallenge = freezed,
    Object? expiresAt = freezed,
    Object? approvedAt = freezed,
    Object? approvedByMasterSignKeyFingerprint = freezed,
    Object? approvalSignature = freezed,
    Object? masterId = freezed,
    Object? keyring = freezed,
    Object? relayPubKey = freezed,
    Object? relaySignature = freezed,
  }) {
    return _then(
      _$AuthStatusResponseImpl(
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as String,
        requestId: freezed == requestId
            ? _value.requestId
            : requestId // ignore: cast_nullable_to_non_nullable
                  as String?,
        machineId: freezed == machineId
            ? _value.machineId
            : machineId // ignore: cast_nullable_to_non_nullable
                  as String?,
        machineSignPub: freezed == machineSignPub
            ? _value.machineSignPub
            : machineSignPub // ignore: cast_nullable_to_non_nullable
                  as String?,
        machineEncPub: freezed == machineEncPub
            ? _value.machineEncPub
            : machineEncPub // ignore: cast_nullable_to_non_nullable
                  as String?,
        machineHostname: freezed == machineHostname
            ? _value.machineHostname
            : machineHostname // ignore: cast_nullable_to_non_nullable
                  as String?,
        relayChallenge: freezed == relayChallenge
            ? _value.relayChallenge
            : relayChallenge // ignore: cast_nullable_to_non_nullable
                  as String?,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as int?,
        approvedAt: freezed == approvedAt
            ? _value.approvedAt
            : approvedAt // ignore: cast_nullable_to_non_nullable
                  as int?,
        approvedByMasterSignKeyFingerprint:
            freezed == approvedByMasterSignKeyFingerprint
            ? _value.approvedByMasterSignKeyFingerprint
            : approvedByMasterSignKeyFingerprint // ignore: cast_nullable_to_non_nullable
                  as String?,
        approvalSignature: freezed == approvalSignature
            ? _value.approvalSignature
            : approvalSignature // ignore: cast_nullable_to_non_nullable
                  as String?,
        masterId: freezed == masterId
            ? _value.masterId
            : masterId // ignore: cast_nullable_to_non_nullable
                  as String?,
        keyring: freezed == keyring
            ? _value.keyring
            : keyring // ignore: cast_nullable_to_non_nullable
                  as KeyringState?,
        relayPubKey: freezed == relayPubKey
            ? _value.relayPubKey
            : relayPubKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        relaySignature: freezed == relaySignature
            ? _value.relaySignature
            : relaySignature // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AuthStatusResponseImpl extends _AuthStatusResponse {
  const _$AuthStatusResponseImpl({
    required this.state,
    this.requestId,
    this.machineId,
    this.machineSignPub,
    this.machineEncPub,
    this.machineHostname,
    this.relayChallenge,
    this.expiresAt,
    this.approvedAt,
    this.approvedByMasterSignKeyFingerprint,
    this.approvalSignature,
    this.masterId,
    this.keyring,
    this.relayPubKey,
    this.relaySignature,
  }) : super._();

  factory _$AuthStatusResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$AuthStatusResponseImplFromJson(json);

  @override
  final String state;
  @override
  final String? requestId;
  @override
  final String? machineId;
  @override
  final String? machineSignPub;
  @override
  final String? machineEncPub;
  @override
  final String? machineHostname;
  @override
  final String? relayChallenge;
  @override
  final int? expiresAt;
  @override
  final int? approvedAt;
  @override
  final String? approvedByMasterSignKeyFingerprint;
  @override
  final String? approvalSignature;
  @override
  final String? masterId;
  @override
  final KeyringState? keyring;
  @override
  final String? relayPubKey;
  @override
  final String? relaySignature;

  @override
  String toString() {
    return 'AuthStatusResponse(state: $state, requestId: $requestId, machineId: $machineId, machineSignPub: $machineSignPub, machineEncPub: $machineEncPub, machineHostname: $machineHostname, relayChallenge: $relayChallenge, expiresAt: $expiresAt, approvedAt: $approvedAt, approvedByMasterSignKeyFingerprint: $approvedByMasterSignKeyFingerprint, approvalSignature: $approvalSignature, masterId: $masterId, keyring: $keyring, relayPubKey: $relayPubKey, relaySignature: $relaySignature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AuthStatusResponseImpl &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.requestId, requestId) ||
                other.requestId == requestId) &&
            (identical(other.machineId, machineId) ||
                other.machineId == machineId) &&
            (identical(other.machineSignPub, machineSignPub) ||
                other.machineSignPub == machineSignPub) &&
            (identical(other.machineEncPub, machineEncPub) ||
                other.machineEncPub == machineEncPub) &&
            (identical(other.machineHostname, machineHostname) ||
                other.machineHostname == machineHostname) &&
            (identical(other.relayChallenge, relayChallenge) ||
                other.relayChallenge == relayChallenge) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(
                  other.approvedByMasterSignKeyFingerprint,
                  approvedByMasterSignKeyFingerprint,
                ) ||
                other.approvedByMasterSignKeyFingerprint ==
                    approvedByMasterSignKeyFingerprint) &&
            (identical(other.approvalSignature, approvalSignature) ||
                other.approvalSignature == approvalSignature) &&
            (identical(other.masterId, masterId) ||
                other.masterId == masterId) &&
            (identical(other.keyring, keyring) || other.keyring == keyring) &&
            (identical(other.relayPubKey, relayPubKey) ||
                other.relayPubKey == relayPubKey) &&
            (identical(other.relaySignature, relaySignature) ||
                other.relaySignature == relaySignature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    state,
    requestId,
    machineId,
    machineSignPub,
    machineEncPub,
    machineHostname,
    relayChallenge,
    expiresAt,
    approvedAt,
    approvedByMasterSignKeyFingerprint,
    approvalSignature,
    masterId,
    keyring,
    relayPubKey,
    relaySignature,
  );

  /// Create a copy of AuthStatusResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AuthStatusResponseImplCopyWith<_$AuthStatusResponseImpl> get copyWith =>
      __$$AuthStatusResponseImplCopyWithImpl<_$AuthStatusResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AuthStatusResponseImplToJson(this);
  }
}

abstract class _AuthStatusResponse extends AuthStatusResponse {
  const factory _AuthStatusResponse({
    required final String state,
    final String? requestId,
    final String? machineId,
    final String? machineSignPub,
    final String? machineEncPub,
    final String? machineHostname,
    final String? relayChallenge,
    final int? expiresAt,
    final int? approvedAt,
    final String? approvedByMasterSignKeyFingerprint,
    final String? approvalSignature,
    final String? masterId,
    final KeyringState? keyring,
    final String? relayPubKey,
    final String? relaySignature,
  }) = _$AuthStatusResponseImpl;
  const _AuthStatusResponse._() : super._();

  factory _AuthStatusResponse.fromJson(Map<String, dynamic> json) =
      _$AuthStatusResponseImpl.fromJson;

  @override
  String get state;
  @override
  String? get requestId;
  @override
  String? get machineId;
  @override
  String? get machineSignPub;
  @override
  String? get machineEncPub;
  @override
  String? get machineHostname;
  @override
  String? get relayChallenge;
  @override
  int? get expiresAt;
  @override
  int? get approvedAt;
  @override
  String? get approvedByMasterSignKeyFingerprint;
  @override
  String? get approvalSignature;
  @override
  String? get masterId;
  @override
  KeyringState? get keyring;
  @override
  String? get relayPubKey;
  @override
  String? get relaySignature;

  /// Create a copy of AuthStatusResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AuthStatusResponseImplCopyWith<_$AuthStatusResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

KeyringState _$KeyringStateFromJson(Map<String, dynamic> json) {
  return _KeyringState.fromJson(json);
}

/// @nodoc
mixin _$KeyringState {
  String get masterId => throw _privateConstructorUsedError;
  int get seq => throw _privateConstructorUsedError;
  String get headHash => throw _privateConstructorUsedError;
  List<MasterKeyInfo> get keys => throw _privateConstructorUsedError;

  /// Serializes this KeyringState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of KeyringState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $KeyringStateCopyWith<KeyringState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeyringStateCopyWith<$Res> {
  factory $KeyringStateCopyWith(
    KeyringState value,
    $Res Function(KeyringState) then,
  ) = _$KeyringStateCopyWithImpl<$Res, KeyringState>;
  @useResult
  $Res call({
    String masterId,
    int seq,
    String headHash,
    List<MasterKeyInfo> keys,
  });
}

/// @nodoc
class _$KeyringStateCopyWithImpl<$Res, $Val extends KeyringState>
    implements $KeyringStateCopyWith<$Res> {
  _$KeyringStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of KeyringState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? masterId = null,
    Object? seq = null,
    Object? headHash = null,
    Object? keys = null,
  }) {
    return _then(
      _value.copyWith(
            masterId: null == masterId
                ? _value.masterId
                : masterId // ignore: cast_nullable_to_non_nullable
                      as String,
            seq: null == seq
                ? _value.seq
                : seq // ignore: cast_nullable_to_non_nullable
                      as int,
            headHash: null == headHash
                ? _value.headHash
                : headHash // ignore: cast_nullable_to_non_nullable
                      as String,
            keys: null == keys
                ? _value.keys
                : keys // ignore: cast_nullable_to_non_nullable
                      as List<MasterKeyInfo>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$KeyringStateImplCopyWith<$Res>
    implements $KeyringStateCopyWith<$Res> {
  factory _$$KeyringStateImplCopyWith(
    _$KeyringStateImpl value,
    $Res Function(_$KeyringStateImpl) then,
  ) = __$$KeyringStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String masterId,
    int seq,
    String headHash,
    List<MasterKeyInfo> keys,
  });
}

/// @nodoc
class __$$KeyringStateImplCopyWithImpl<$Res>
    extends _$KeyringStateCopyWithImpl<$Res, _$KeyringStateImpl>
    implements _$$KeyringStateImplCopyWith<$Res> {
  __$$KeyringStateImplCopyWithImpl(
    _$KeyringStateImpl _value,
    $Res Function(_$KeyringStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of KeyringState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? masterId = null,
    Object? seq = null,
    Object? headHash = null,
    Object? keys = null,
  }) {
    return _then(
      _$KeyringStateImpl(
        masterId: null == masterId
            ? _value.masterId
            : masterId // ignore: cast_nullable_to_non_nullable
                  as String,
        seq: null == seq
            ? _value.seq
            : seq // ignore: cast_nullable_to_non_nullable
                  as int,
        headHash: null == headHash
            ? _value.headHash
            : headHash // ignore: cast_nullable_to_non_nullable
                  as String,
        keys: null == keys
            ? _value._keys
            : keys // ignore: cast_nullable_to_non_nullable
                  as List<MasterKeyInfo>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$KeyringStateImpl extends _KeyringState {
  const _$KeyringStateImpl({
    required this.masterId,
    required this.seq,
    required this.headHash,
    required final List<MasterKeyInfo> keys,
  }) : _keys = keys,
       super._();

  factory _$KeyringStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$KeyringStateImplFromJson(json);

  @override
  final String masterId;
  @override
  final int seq;
  @override
  final String headHash;
  final List<MasterKeyInfo> _keys;
  @override
  List<MasterKeyInfo> get keys {
    if (_keys is EqualUnmodifiableListView) return _keys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_keys);
  }

  @override
  String toString() {
    return 'KeyringState(masterId: $masterId, seq: $seq, headHash: $headHash, keys: $keys)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeyringStateImpl &&
            (identical(other.masterId, masterId) ||
                other.masterId == masterId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.headHash, headHash) ||
                other.headHash == headHash) &&
            const DeepCollectionEquality().equals(other._keys, _keys));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    masterId,
    seq,
    headHash,
    const DeepCollectionEquality().hash(_keys),
  );

  /// Create a copy of KeyringState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$KeyringStateImplCopyWith<_$KeyringStateImpl> get copyWith =>
      __$$KeyringStateImplCopyWithImpl<_$KeyringStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$KeyringStateImplToJson(this);
  }
}

abstract class _KeyringState extends KeyringState {
  const factory _KeyringState({
    required final String masterId,
    required final int seq,
    required final String headHash,
    required final List<MasterKeyInfo> keys,
  }) = _$KeyringStateImpl;
  const _KeyringState._() : super._();

  factory _KeyringState.fromJson(Map<String, dynamic> json) =
      _$KeyringStateImpl.fromJson;

  @override
  String get masterId;
  @override
  int get seq;
  @override
  String get headHash;
  @override
  List<MasterKeyInfo> get keys;

  /// Create a copy of KeyringState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$KeyringStateImplCopyWith<_$KeyringStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MasterKeyInfo _$MasterKeyInfoFromJson(Map<String, dynamic> json) {
  return _MasterKeyInfo.fromJson(json);
}

/// @nodoc
mixin _$MasterKeyInfo {
  String get masterSignKeyFingerprint => throw _privateConstructorUsedError;
  String get masterSignPub => throw _privateConstructorUsedError;
  String get masterEncPub => throw _privateConstructorUsedError;
  int? get revokedAt => throw _privateConstructorUsedError;

  /// Serializes this MasterKeyInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MasterKeyInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MasterKeyInfoCopyWith<MasterKeyInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MasterKeyInfoCopyWith<$Res> {
  factory $MasterKeyInfoCopyWith(
    MasterKeyInfo value,
    $Res Function(MasterKeyInfo) then,
  ) = _$MasterKeyInfoCopyWithImpl<$Res, MasterKeyInfo>;
  @useResult
  $Res call({
    String masterSignKeyFingerprint,
    String masterSignPub,
    String masterEncPub,
    int? revokedAt,
  });
}

/// @nodoc
class _$MasterKeyInfoCopyWithImpl<$Res, $Val extends MasterKeyInfo>
    implements $MasterKeyInfoCopyWith<$Res> {
  _$MasterKeyInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MasterKeyInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? masterSignKeyFingerprint = null,
    Object? masterSignPub = null,
    Object? masterEncPub = null,
    Object? revokedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            masterSignKeyFingerprint: null == masterSignKeyFingerprint
                ? _value.masterSignKeyFingerprint
                : masterSignKeyFingerprint // ignore: cast_nullable_to_non_nullable
                      as String,
            masterSignPub: null == masterSignPub
                ? _value.masterSignPub
                : masterSignPub // ignore: cast_nullable_to_non_nullable
                      as String,
            masterEncPub: null == masterEncPub
                ? _value.masterEncPub
                : masterEncPub // ignore: cast_nullable_to_non_nullable
                      as String,
            revokedAt: freezed == revokedAt
                ? _value.revokedAt
                : revokedAt // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MasterKeyInfoImplCopyWith<$Res>
    implements $MasterKeyInfoCopyWith<$Res> {
  factory _$$MasterKeyInfoImplCopyWith(
    _$MasterKeyInfoImpl value,
    $Res Function(_$MasterKeyInfoImpl) then,
  ) = __$$MasterKeyInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String masterSignKeyFingerprint,
    String masterSignPub,
    String masterEncPub,
    int? revokedAt,
  });
}

/// @nodoc
class __$$MasterKeyInfoImplCopyWithImpl<$Res>
    extends _$MasterKeyInfoCopyWithImpl<$Res, _$MasterKeyInfoImpl>
    implements _$$MasterKeyInfoImplCopyWith<$Res> {
  __$$MasterKeyInfoImplCopyWithImpl(
    _$MasterKeyInfoImpl _value,
    $Res Function(_$MasterKeyInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MasterKeyInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? masterSignKeyFingerprint = null,
    Object? masterSignPub = null,
    Object? masterEncPub = null,
    Object? revokedAt = freezed,
  }) {
    return _then(
      _$MasterKeyInfoImpl(
        masterSignKeyFingerprint: null == masterSignKeyFingerprint
            ? _value.masterSignKeyFingerprint
            : masterSignKeyFingerprint // ignore: cast_nullable_to_non_nullable
                  as String,
        masterSignPub: null == masterSignPub
            ? _value.masterSignPub
            : masterSignPub // ignore: cast_nullable_to_non_nullable
                  as String,
        masterEncPub: null == masterEncPub
            ? _value.masterEncPub
            : masterEncPub // ignore: cast_nullable_to_non_nullable
                  as String,
        revokedAt: freezed == revokedAt
            ? _value.revokedAt
            : revokedAt // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MasterKeyInfoImpl extends _MasterKeyInfo {
  const _$MasterKeyInfoImpl({
    required this.masterSignKeyFingerprint,
    required this.masterSignPub,
    required this.masterEncPub,
    this.revokedAt,
  }) : super._();

  factory _$MasterKeyInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$MasterKeyInfoImplFromJson(json);

  @override
  final String masterSignKeyFingerprint;
  @override
  final String masterSignPub;
  @override
  final String masterEncPub;
  @override
  final int? revokedAt;

  @override
  String toString() {
    return 'MasterKeyInfo(masterSignKeyFingerprint: $masterSignKeyFingerprint, masterSignPub: $masterSignPub, masterEncPub: $masterEncPub, revokedAt: $revokedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MasterKeyInfoImpl &&
            (identical(
                  other.masterSignKeyFingerprint,
                  masterSignKeyFingerprint,
                ) ||
                other.masterSignKeyFingerprint == masterSignKeyFingerprint) &&
            (identical(other.masterSignPub, masterSignPub) ||
                other.masterSignPub == masterSignPub) &&
            (identical(other.masterEncPub, masterEncPub) ||
                other.masterEncPub == masterEncPub) &&
            (identical(other.revokedAt, revokedAt) ||
                other.revokedAt == revokedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    masterSignKeyFingerprint,
    masterSignPub,
    masterEncPub,
    revokedAt,
  );

  /// Create a copy of MasterKeyInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MasterKeyInfoImplCopyWith<_$MasterKeyInfoImpl> get copyWith =>
      __$$MasterKeyInfoImplCopyWithImpl<_$MasterKeyInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MasterKeyInfoImplToJson(this);
  }
}

abstract class _MasterKeyInfo extends MasterKeyInfo {
  const factory _MasterKeyInfo({
    required final String masterSignKeyFingerprint,
    required final String masterSignPub,
    required final String masterEncPub,
    final int? revokedAt,
  }) = _$MasterKeyInfoImpl;
  const _MasterKeyInfo._() : super._();

  factory _MasterKeyInfo.fromJson(Map<String, dynamic> json) =
      _$MasterKeyInfoImpl.fromJson;

  @override
  String get masterSignKeyFingerprint;
  @override
  String get masterSignPub;
  @override
  String get masterEncPub;
  @override
  int? get revokedAt;

  /// Create a copy of MasterKeyInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MasterKeyInfoImplCopyWith<_$MasterKeyInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
