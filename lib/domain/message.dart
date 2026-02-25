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

  factory MediaPart.fromJson(Map<String, dynamic> json) {
    return MediaPart(
      url: json['url'] as String?,
      base64: json['base64'] as String?,
      mimeType: json['mimeType'] as String?,
      name: json['name'] as String?,
      size: (json['size'] as num?)?.toInt(),
    );
  }

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

  factory MessagePart.fromJson(Map<String, dynamic> json) {
    return MessagePart(
      type: PartType.fromValue(json['type'] as String? ?? 'text'),
      text: json['text'] as String?,
      media: json['media'] != null
          ? MediaPart.fromJson(json['media'] as Map<String, dynamic>)
          : null,
      tool: json['tool'] != null
          ? ToolActivity.fromJson(json['tool'] as Map<String, dynamic>)
          : null,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

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

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      role: MessageRole.fromValue(json['role'] as String? ?? 'user'),
      parts: (json['parts'] as List<dynamic>?)
              ?.map(
                (p) => MessagePart.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          [],
      cost: json['cost'] != null
          ? CostInfo.fromJson(json['cost'] as Map<String, dynamic>)
          : null,
      model: json['model'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

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
