// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'acp_tool_call_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AcpToolCallUpdateDto _$AcpToolCallUpdateDtoFromJson(Map<String, dynamic> json) {
  return _AcpToolCallUpdateDto.fromJson(json);
}

/// @nodoc
mixin _$AcpToolCallUpdateDto {
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  @JsonKey(name: 'toolCallId')
  String get toolCallId => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String? get kind => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  List<Map<String, dynamic>>? get content => throw _privateConstructorUsedError;
  List<AcpToolCallLocationDto>? get locations =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'rawInput')
  Object? get rawInput => throw _privateConstructorUsedError;
  @JsonKey(name: 'rawOutput')
  Object? get rawOutput => throw _privateConstructorUsedError;

  /// Serializes this AcpToolCallUpdateDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcpToolCallUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcpToolCallUpdateDtoCopyWith<AcpToolCallUpdateDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcpToolCallUpdateDtoCopyWith<$Res> {
  factory $AcpToolCallUpdateDtoCopyWith(
    AcpToolCallUpdateDto value,
    $Res Function(AcpToolCallUpdateDto) then,
  ) = _$AcpToolCallUpdateDtoCopyWithImpl<$Res, AcpToolCallUpdateDto>;
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'toolCallId') String toolCallId,
    String? title,
    String? kind,
    String? status,
    List<Map<String, dynamic>>? content,
    List<AcpToolCallLocationDto>? locations,
    @JsonKey(name: 'rawInput') Object? rawInput,
    @JsonKey(name: 'rawOutput') Object? rawOutput,
  });
}

/// @nodoc
class _$AcpToolCallUpdateDtoCopyWithImpl<
  $Res,
  $Val extends AcpToolCallUpdateDto
>
    implements $AcpToolCallUpdateDtoCopyWith<$Res> {
  _$AcpToolCallUpdateDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcpToolCallUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? toolCallId = null,
    Object? title = freezed,
    Object? kind = freezed,
    Object? status = freezed,
    Object? content = freezed,
    Object? locations = freezed,
    Object? rawInput = freezed,
    Object? rawOutput = freezed,
  }) {
    return _then(
      _value.copyWith(
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            toolCallId: null == toolCallId
                ? _value.toolCallId
                : toolCallId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            kind: freezed == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String?,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, dynamic>>?,
            locations: freezed == locations
                ? _value.locations
                : locations // ignore: cast_nullable_to_non_nullable
                      as List<AcpToolCallLocationDto>?,
            rawInput: freezed == rawInput ? _value.rawInput : rawInput,
            rawOutput: freezed == rawOutput ? _value.rawOutput : rawOutput,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AcpToolCallUpdateDtoImplCopyWith<$Res>
    implements $AcpToolCallUpdateDtoCopyWith<$Res> {
  factory _$$AcpToolCallUpdateDtoImplCopyWith(
    _$AcpToolCallUpdateDtoImpl value,
    $Res Function(_$AcpToolCallUpdateDtoImpl) then,
  ) = __$$AcpToolCallUpdateDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    @JsonKey(name: 'toolCallId') String toolCallId,
    String? title,
    String? kind,
    String? status,
    List<Map<String, dynamic>>? content,
    List<AcpToolCallLocationDto>? locations,
    @JsonKey(name: 'rawInput') Object? rawInput,
    @JsonKey(name: 'rawOutput') Object? rawOutput,
  });
}

/// @nodoc
class __$$AcpToolCallUpdateDtoImplCopyWithImpl<$Res>
    extends _$AcpToolCallUpdateDtoCopyWithImpl<$Res, _$AcpToolCallUpdateDtoImpl>
    implements _$$AcpToolCallUpdateDtoImplCopyWith<$Res> {
  __$$AcpToolCallUpdateDtoImplCopyWithImpl(
    _$AcpToolCallUpdateDtoImpl _value,
    $Res Function(_$AcpToolCallUpdateDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AcpToolCallUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? toolCallId = null,
    Object? title = freezed,
    Object? kind = freezed,
    Object? status = freezed,
    Object? content = freezed,
    Object? locations = freezed,
    Object? rawInput = freezed,
    Object? rawOutput = freezed,
  }) {
    return _then(
      _$AcpToolCallUpdateDtoImpl(
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        toolCallId: null == toolCallId
            ? _value.toolCallId
            : toolCallId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: freezed == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String?,
        content: freezed == content
            ? _value._content
            : content // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, dynamic>>?,
        locations: freezed == locations
            ? _value._locations
            : locations // ignore: cast_nullable_to_non_nullable
                  as List<AcpToolCallLocationDto>?,
        rawInput: freezed == rawInput ? _value.rawInput : rawInput,
        rawOutput: freezed == rawOutput ? _value.rawOutput : rawOutput,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AcpToolCallUpdateDtoImpl implements _AcpToolCallUpdateDto {
  const _$AcpToolCallUpdateDtoImpl({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    @JsonKey(name: 'toolCallId') required this.toolCallId,
    this.title,
    this.kind,
    this.status,
    final List<Map<String, dynamic>>? content,
    final List<AcpToolCallLocationDto>? locations,
    @JsonKey(name: 'rawInput') this.rawInput,
    @JsonKey(name: 'rawOutput') this.rawOutput,
  }) : _meta = meta,
       _content = content,
       _locations = locations;

  factory _$AcpToolCallUpdateDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AcpToolCallUpdateDtoImplFromJson(json);

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
  @JsonKey(name: 'toolCallId')
  final String toolCallId;
  @override
  final String? title;
  @override
  final String? kind;
  @override
  final String? status;
  final List<Map<String, dynamic>>? _content;
  @override
  List<Map<String, dynamic>>? get content {
    final value = _content;
    if (value == null) return null;
    if (_content is EqualUnmodifiableListView) return _content;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<AcpToolCallLocationDto>? _locations;
  @override
  List<AcpToolCallLocationDto>? get locations {
    final value = _locations;
    if (value == null) return null;
    if (_locations is EqualUnmodifiableListView) return _locations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'rawInput')
  final Object? rawInput;
  @override
  @JsonKey(name: 'rawOutput')
  final Object? rawOutput;

  @override
  String toString() {
    return 'AcpToolCallUpdateDto(meta: $meta, toolCallId: $toolCallId, title: $title, kind: $kind, status: $status, content: $content, locations: $locations, rawInput: $rawInput, rawOutput: $rawOutput)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcpToolCallUpdateDtoImpl &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.toolCallId, toolCallId) ||
                other.toolCallId == toolCallId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._content, _content) &&
            const DeepCollectionEquality().equals(
              other._locations,
              _locations,
            ) &&
            const DeepCollectionEquality().equals(other.rawInput, rawInput) &&
            const DeepCollectionEquality().equals(other.rawOutput, rawOutput));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_meta),
    toolCallId,
    title,
    kind,
    status,
    const DeepCollectionEquality().hash(_content),
    const DeepCollectionEquality().hash(_locations),
    const DeepCollectionEquality().hash(rawInput),
    const DeepCollectionEquality().hash(rawOutput),
  );

  /// Create a copy of AcpToolCallUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcpToolCallUpdateDtoImplCopyWith<_$AcpToolCallUpdateDtoImpl>
  get copyWith =>
      __$$AcpToolCallUpdateDtoImplCopyWithImpl<_$AcpToolCallUpdateDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AcpToolCallUpdateDtoImplToJson(this);
  }
}

abstract class _AcpToolCallUpdateDto implements AcpToolCallUpdateDto {
  const factory _AcpToolCallUpdateDto({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    @JsonKey(name: 'toolCallId') required final String toolCallId,
    final String? title,
    final String? kind,
    final String? status,
    final List<Map<String, dynamic>>? content,
    final List<AcpToolCallLocationDto>? locations,
    @JsonKey(name: 'rawInput') final Object? rawInput,
    @JsonKey(name: 'rawOutput') final Object? rawOutput,
  }) = _$AcpToolCallUpdateDtoImpl;

  factory _AcpToolCallUpdateDto.fromJson(Map<String, dynamic> json) =
      _$AcpToolCallUpdateDtoImpl.fromJson;

  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta;
  @override
  @JsonKey(name: 'toolCallId')
  String get toolCallId;
  @override
  String? get title;
  @override
  String? get kind;
  @override
  String? get status;
  @override
  List<Map<String, dynamic>>? get content;
  @override
  List<AcpToolCallLocationDto>? get locations;
  @override
  @JsonKey(name: 'rawInput')
  Object? get rawInput;
  @override
  @JsonKey(name: 'rawOutput')
  Object? get rawOutput;

  /// Create a copy of AcpToolCallUpdateDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcpToolCallUpdateDtoImplCopyWith<_$AcpToolCallUpdateDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AcpToolCallLocationDto _$AcpToolCallLocationDtoFromJson(
  Map<String, dynamic> json,
) {
  return _AcpToolCallLocationDto.fromJson(json);
}

/// @nodoc
mixin _$AcpToolCallLocationDto {
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  int? get line => throw _privateConstructorUsedError;

  /// Serializes this AcpToolCallLocationDto to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AcpToolCallLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AcpToolCallLocationDtoCopyWith<AcpToolCallLocationDto> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AcpToolCallLocationDtoCopyWith<$Res> {
  factory $AcpToolCallLocationDtoCopyWith(
    AcpToolCallLocationDto value,
    $Res Function(AcpToolCallLocationDto) then,
  ) = _$AcpToolCallLocationDtoCopyWithImpl<$Res, AcpToolCallLocationDto>;
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    String path,
    int? line,
  });
}

/// @nodoc
class _$AcpToolCallLocationDtoCopyWithImpl<
  $Res,
  $Val extends AcpToolCallLocationDto
>
    implements $AcpToolCallLocationDtoCopyWith<$Res> {
  _$AcpToolCallLocationDtoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AcpToolCallLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? path = null,
    Object? line = freezed,
  }) {
    return _then(
      _value.copyWith(
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
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
abstract class _$$AcpToolCallLocationDtoImplCopyWith<$Res>
    implements $AcpToolCallLocationDtoCopyWith<$Res> {
  factory _$$AcpToolCallLocationDtoImplCopyWith(
    _$AcpToolCallLocationDtoImpl value,
    $Res Function(_$AcpToolCallLocationDtoImpl) then,
  ) = __$$AcpToolCallLocationDtoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: '_meta') Map<String, dynamic>? meta,
    String path,
    int? line,
  });
}

/// @nodoc
class __$$AcpToolCallLocationDtoImplCopyWithImpl<$Res>
    extends
        _$AcpToolCallLocationDtoCopyWithImpl<$Res, _$AcpToolCallLocationDtoImpl>
    implements _$$AcpToolCallLocationDtoImplCopyWith<$Res> {
  __$$AcpToolCallLocationDtoImplCopyWithImpl(
    _$AcpToolCallLocationDtoImpl _value,
    $Res Function(_$AcpToolCallLocationDtoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AcpToolCallLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? meta = freezed,
    Object? path = null,
    Object? line = freezed,
  }) {
    return _then(
      _$AcpToolCallLocationDtoImpl(
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
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
class _$AcpToolCallLocationDtoImpl implements _AcpToolCallLocationDto {
  const _$AcpToolCallLocationDtoImpl({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    required this.path,
    this.line,
  }) : _meta = meta;

  factory _$AcpToolCallLocationDtoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AcpToolCallLocationDtoImplFromJson(json);

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
  final String path;
  @override
  final int? line;

  @override
  String toString() {
    return 'AcpToolCallLocationDto(meta: $meta, path: $path, line: $line)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AcpToolCallLocationDtoImpl &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.line, line) || other.line == line));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_meta),
    path,
    line,
  );

  /// Create a copy of AcpToolCallLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AcpToolCallLocationDtoImplCopyWith<_$AcpToolCallLocationDtoImpl>
  get copyWith =>
      __$$AcpToolCallLocationDtoImplCopyWithImpl<_$AcpToolCallLocationDtoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AcpToolCallLocationDtoImplToJson(this);
  }
}

abstract class _AcpToolCallLocationDto implements AcpToolCallLocationDto {
  const factory _AcpToolCallLocationDto({
    @JsonKey(name: '_meta') final Map<String, dynamic>? meta,
    required final String path,
    final int? line,
  }) = _$AcpToolCallLocationDtoImpl;

  factory _AcpToolCallLocationDto.fromJson(Map<String, dynamic> json) =
      _$AcpToolCallLocationDtoImpl.fromJson;

  @override
  @JsonKey(name: '_meta')
  Map<String, dynamic>? get meta;
  @override
  String get path;
  @override
  int? get line;

  /// Create a copy of AcpToolCallLocationDto
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AcpToolCallLocationDtoImplCopyWith<_$AcpToolCallLocationDtoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
