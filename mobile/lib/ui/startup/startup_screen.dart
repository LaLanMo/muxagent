import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/theme.dart';
import 'startup_viewmodel.dart';

class StartupScreen extends GetView<StartupViewModel> {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
