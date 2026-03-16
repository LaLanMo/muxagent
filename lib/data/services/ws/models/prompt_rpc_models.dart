import '../../../../domain/prompt_content_block.dart';

class PromptContentBlockDto {
  final String type;
  final String? text;
  final String? mimeType;
  final String? data;
  final String? uri;

  const PromptContentBlockDto({
    required this.type,
    this.text,
    this.mimeType,
    this.data,
    this.uri,
  });

  factory PromptContentBlockDto.fromDomain(PromptContentBlock block) {
    return PromptContentBlockDto(
      type: block.type,
      text: block.text,
      mimeType: block.mimeType,
      data: block.data,
      uri: block.uri,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (text != null) 'text': text,
    if (mimeType != null) 'mimeType': mimeType,
    if (data != null) 'data': data,
    if (uri != null) 'uri': uri,
  };
}

class PromptSessionParamsDto {
  final String sessionId;
  final List<PromptContentBlockDto> content;

  const PromptSessionParamsDto({
    required this.sessionId,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'content': content.map((block) => block.toJson()).toList(),
  };
}
