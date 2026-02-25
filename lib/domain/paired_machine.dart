class PairedMachine {
  final String machineId;
  final String relayHttpUrl;
  final String machineSignPubB64;
  final String machineEncPubB64;
  final String? hostname;

  PairedMachine({
    required this.machineId,
    required this.relayHttpUrl,
    required this.machineSignPubB64,
    required this.machineEncPubB64,
    this.hostname,
  });

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'relay_http_url': relayHttpUrl,
        'machine_sign_pub': machineSignPubB64,
        'machine_enc_pub': machineEncPubB64,
        'hostname': hostname,
      };

  factory PairedMachine.fromJson(Map<String, dynamic> json) {
    return PairedMachine(
      machineId: json['machine_id'] as String,
      relayHttpUrl: json['relay_http_url'] as String,
      machineSignPubB64: json['machine_sign_pub'] as String,
      machineEncPubB64: json['machine_enc_pub'] as String,
      hostname: json['hostname'] as String?,
    );
  }
}
