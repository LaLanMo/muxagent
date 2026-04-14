class RpcResponseEnvelopeDto {
  final Object? result;
  final String? error;

  const RpcResponseEnvelopeDto({this.result, this.error});

  factory RpcResponseEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    return RpcResponseEnvelopeDto(
      result: json['result'],
      error: error is String && error.isNotEmpty ? error : null,
    );
  }
}
