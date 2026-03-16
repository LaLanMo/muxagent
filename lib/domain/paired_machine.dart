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
}
