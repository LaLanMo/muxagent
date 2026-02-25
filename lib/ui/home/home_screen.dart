import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_viewmodel.dart';

class HomeScreen extends GetView<HomeViewModel> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MuxAgent'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: controller.disconnectAll,
            tooltip: 'Disconnect all',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: controller.onScanPressed,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'or enter URL manually',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Obx(
              () => TextField(
                controller: controller.urlController,
                decoration: InputDecoration(
                  hintText: 'muxagent://auth?id=...&relay=...',
                  border: const OutlineInputBorder(),
                  errorText: controller.urlError.value,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: controller.onManualConnect,
                  ),
                ),
                onChanged: (_) => controller.clearUrlError(),
                onSubmitted: (_) => controller.onManualConnect(),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => controller.hasMasterKey.value
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Master key configured',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            Obx(() {
              if (controller.machines.isEmpty) {
                return const Text(
                  'No machines paired yet.',
                  style: TextStyle(color: Colors.grey),
                );
              }
              final connected = controller.connectedMachines;
              final available = controller.availableMachines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Connected sessions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: controller.refreshMachines,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (connected.isEmpty)
                    const Text(
                      'No active sessions.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: connected
                          .map(
                            (machine) => Card(
                              child: ListTile(
                                title: Text(
                                  (machine.hostname != null &&
                                          machine.hostname!.isNotEmpty)
                                      ? machine.hostname!
                                      : 'Unknown host',
                                ),
                                subtitle: Text(machine.machineId),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          controller.testEcho(machine),
                                      child: const Text('Echo'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          controller.disconnectMachine(machine),
                                      child: const Text('Disconnect'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          controller.deleteMachine(machine),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Available machines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (available.isEmpty)
                    const Text(
                      'All machines are connected.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: available
                          .map(
                            (machine) => Card(
                              child: ListTile(
                                title: Text(
                                  (machine.hostname != null &&
                                          machine.hostname!.isNotEmpty)
                                      ? machine.hostname!
                                      : 'Unknown host',
                                ),
                                subtitle: Text(machine.machineId),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          controller.connectMachine(machine),
                                      child: const Text('Connect'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          controller.deleteMachine(machine),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              );
            }),
            const SizedBox(height: 12),
            Obx(
              () => controller.connectionStatus.value == null
                  ? const SizedBox.shrink()
                  : Text(
                      controller.connectionStatus.value!,
                      style: const TextStyle(color: Colors.blueGrey),
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
