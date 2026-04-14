import '../../domain/paired_machine.dart';

class PairedMachineStorageDto {
  final String machineId;
  final String relayHttpUrl;
  final String machineSignPubB64;
  final String machineEncPubB64;
  final String? hostname;

  const PairedMachineStorageDto({
    required this.machineId,
    required this.relayHttpUrl,
    required this.machineSignPubB64,
    required this.machineEncPubB64,
    this.hostname,
  });

  factory PairedMachineStorageDto.fromJson(Map<String, dynamic> json) {
    return PairedMachineStorageDto(
      machineId: json['machine_id'] as String,
      relayHttpUrl: json['relay_http_url'] as String,
      machineSignPubB64: json['machine_sign_pub'] as String,
      machineEncPubB64: json['machine_enc_pub'] as String,
      hostname: json['hostname'] as String?,
    );
  }

  factory PairedMachineStorageDto.fromDomain(PairedMachine machine) {
    return PairedMachineStorageDto(
      machineId: machine.machineId,
      relayHttpUrl: machine.relayHttpUrl,
      machineSignPubB64: machine.machineSignPubB64,
      machineEncPubB64: machine.machineEncPubB64,
      hostname: machine.hostname,
    );
  }

  Map<String, dynamic> toJson() => {
    'machine_id': machineId,
    'relay_http_url': relayHttpUrl,
    'machine_sign_pub': machineSignPubB64,
    'machine_enc_pub': machineEncPubB64,
    'hostname': hostname,
  };

  PairedMachine toDomain() {
    return PairedMachine(
      machineId: machineId,
      relayHttpUrl: relayHttpUrl,
      machineSignPubB64: machineSignPubB64,
      machineEncPubB64: machineEncPubB64,
      hostname: hostname,
    );
  }
}
