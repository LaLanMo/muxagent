class PromptContentBlock {
  final String type;
  final String? text;
  final String? mimeType;
  final String? data;
  final String? uri;

  const PromptContentBlock({
    required this.type,
    this.text,
    this.mimeType,
    this.data,
    this.uri,
  });

  factory PromptContentBlock.text(String text) {
    return PromptContentBlock(type: 'text', text: text);
  }

  factory PromptContentBlock.imageBase64({
    required String mimeType,
    required String data,
  }) {
    return PromptContentBlock(type: 'image', mimeType: mimeType, data: data);
  }
}
