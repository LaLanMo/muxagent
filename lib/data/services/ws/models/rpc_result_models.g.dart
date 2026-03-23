// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rpc_result_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RpcOkResponseDtoImpl _$$RpcOkResponseDtoImplFromJson(
  Map<String, dynamic> json,
) => _$RpcOkResponseDtoImpl(ok: _requiredBool(json['ok']));

Map<String, dynamic> _$$RpcOkResponseDtoImplToJson(
  _$RpcOkResponseDtoImpl instance,
) => <String, dynamic>{'ok': instance.ok};

_$RpcAcceptedResponseDtoImpl _$$RpcAcceptedResponseDtoImplFromJson(
  Map<String, dynamic> json,
) => _$RpcAcceptedResponseDtoImpl(accepted: _requiredBool(json['accepted']));

Map<String, dynamic> _$$RpcAcceptedResponseDtoImplToJson(
  _$RpcAcceptedResponseDtoImpl instance,
) => <String, dynamic>{'accepted': instance.accepted};

_$RpcResolvedSessionDtoImpl _$$RpcResolvedSessionDtoImplFromJson(
  Map<String, dynamic> json,
) => _$RpcResolvedSessionDtoImpl(
  sessionId: _requiredString(json['sessionId']),
  title: _nullableString(json['title']),
  cwd: _nullableString(json['cwd']),
  runtime: _nullableString(json['runtime']),
  status: _nullableString(json['status']),
  updatedAt: _nullableDateTime(json['updatedAt']),
  configOptions: _nullableConfigOptionListFromJson(json['configOptions']),
);

Map<String, dynamic> _$$RpcResolvedSessionDtoImplToJson(
  _$RpcResolvedSessionDtoImpl instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'title': instance.title,
  'cwd': instance.cwd,
  'runtime': instance.runtime,
  'status': instance.status,
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'configOptions': instance.configOptions?.map((e) => e.toJson()).toList(),
};

_$RpcSessionResolveResponseDtoImpl _$$RpcSessionResolveResponseDtoImplFromJson(
  Map<String, dynamic> json,
) => _$RpcSessionResolveResponseDtoImpl(
  sessions: _resolvedSessionListFromJson(json['sessions']),
);

Map<String, dynamic> _$$RpcSessionResolveResponseDtoImplToJson(
  _$RpcSessionResolveResponseDtoImpl instance,
) => <String, dynamic>{
  'sessions': instance.sessions.map((e) => e.toJson()).toList(),
};

_$RpcFsEntryDtoImpl _$$RpcFsEntryDtoImplFromJson(Map<String, dynamic> json) =>
    _$RpcFsEntryDtoImpl(
      path: _requiredString(json['path']),
      isDir: _requiredBool(json['isDir']),
      name: _nullableString(json['name']),
    );

Map<String, dynamic> _$$RpcFsEntryDtoImplToJson(_$RpcFsEntryDtoImpl instance) =>
    <String, dynamic>{
      'path': instance.path,
      'isDir': instance.isDir,
      'name': instance.name,
    };

_$RpcFsListResponseDtoImpl _$$RpcFsListResponseDtoImplFromJson(
  Map<String, dynamic> json,
) => _$RpcFsListResponseDtoImpl(entries: _fsEntryListFromJson(json['entries']));

Map<String, dynamic> _$$RpcFsListResponseDtoImplToJson(
  _$RpcFsListResponseDtoImpl instance,
) => <String, dynamic>{
  'entries': instance.entries.map((e) => e.toJson()).toList(),
};

_$RpcFsSearchResponseDtoImpl _$$RpcFsSearchResponseDtoImplFromJson(
  Map<String, dynamic> json,
) => _$RpcFsSearchResponseDtoImpl(
  results: _fsEntryListFromJson(json['results']),
);

Map<String, dynamic> _$$RpcFsSearchResponseDtoImplToJson(
  _$RpcFsSearchResponseDtoImpl instance,
) => <String, dynamic>{
  'results': instance.results.map((e) => e.toJson()).toList(),
};
