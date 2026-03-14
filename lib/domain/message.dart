import 'cost_info.dart';
import 'enums.dart';
import 'tool_activity.dart';

class MediaPart {
  final String? url;
  final String? base64;
  final String? mimeType;
  final String? name;
  final int? size;

  MediaPart({this.url, this.base64, this.mimeType, this.name, this.size});

  Map<String, dynamic> toJson() => {
    if (url != null) 'url': url,
    if (base64 != null) 'base64': base64,
    if (mimeType != null) 'mimeType': mimeType,
    if (name != null) 'name': name,
    if (size != null) 'size': size,
  };
}

class MessagePart {
  PartType type;
  String? text;
  MediaPart? media;
  ToolActivity? tool;
  Map<String, dynamic>? data;

  MessagePart({
    required this.type,
    this.text,
    this.media,
    this.tool,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'type': type.value,
    if (text != null) 'text': text,
    if (media != null) 'media': media!.toJson(),
    if (tool != null) 'tool': tool!.toJson(),
    if (data != null) 'data': data,
  };
}

class Message {
  final String id;
  final String sessionId;
  final MessageRole role;
  final List<MessagePart> parts;
  CostInfo? cost;
  String? model;
  Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.parts,
    this.cost,
    this.model,
    this.metadata,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'role': role.value,
    'parts': parts.map((p) => p.toJson()).toList(),
    if (cost != null) 'cost': cost!.toJson(),
    if (model != null) 'model': model,
    if (metadata != null) 'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
  };
}
