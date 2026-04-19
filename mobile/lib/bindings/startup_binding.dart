import 'package:get/get.dart';

import '../data/repositories/paired_machine_repository.dart';
import '../data/services/pairing_deep_link_coordinator.dart';
import '../ui/startup/startup_viewmodel.dart';

class StartupBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<StartupViewModel>(
      StartupViewModel(
        machineRepo: Get.find<PairedMachineRepository>(),
        pairingDeepLinkCoordinator: Get.find<PairingDeepLinkCoordinator>(),
      ),
    );
  }
}
