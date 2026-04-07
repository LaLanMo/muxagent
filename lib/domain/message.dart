import 'dart:convert';
import 'dart:typed_data';

import 'cost_info.dart';
import 'enums.dart';
import 'tool_activity.dart';

class MediaPart {
  final String? url;
  final String? base64;
  final String? mimeType;
  final String? name;
  final int? size;
  Uint8List? _decodedBytesCache;

  MediaPart({this.url, this.base64, this.mimeType, this.name, this.size});

  Uint8List? get decodedBytes {
    final encoded = base64;
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return _decodedBytesCache ??= base64Decode(encoded);
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

  MessagePart({required this.type, this.text, this.media, this.tool});

  Map<String, dynamic> toJson() => {
    'type': type.value,
    if (text != null) 'text': text,
    if (media != null) 'media': media!.toJson(),
    if (tool != null) 'tool': tool!.toJson(),
  };
}

class Message {
  final String id;
  final String sessionId;
  final MessageRole role;
  final List<MessagePart> parts;
  CostInfo? cost;
  String? model;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.parts,
    this.cost,
    this.model,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'role': role.value,
    'parts': parts.map((p) => p.toJson()).toList(),
    if (cost != null) 'cost': cost!.toJson(),
    if (model != null) 'model': model,
    'createdAt': createdAt.toIso8601String(),
  };
}
