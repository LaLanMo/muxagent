import 'package:get/get.dart';

import '../ui/scan/scan_viewmodel.dart';

class ScanBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ScanViewModel>(() => ScanViewModel());
  }
}
