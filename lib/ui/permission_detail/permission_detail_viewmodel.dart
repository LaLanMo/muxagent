import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/ws_session_repository.dart';
import '../../domain/approval.dart';

class PermissionDetailViewModel extends GetxController {
  final WsSessionRepository _wsRepo = Get.find<WsSessionRepository>();

  late final ApprovalRequest approval;
  late final String machineId;
  late final String sessionId;

  final isReplying = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    approval = args['approval'] as ApprovalRequest;
    machineId = args['machineId'] as String;
    sessionId = args['sessionId'] as String;
  }

  Future<void> replyApproval(String optionId) async {
    if (isReplying.value) return;
    isReplying.value = true;

    try {
      await _wsRepo.callRpc(
        machineId: machineId,
        method: 'approval.reply',
        params: {
          'sessionId': sessionId,
          'requestId': approval.id,
          'optionId': optionId,
        },
      );
      Get.back();
    } catch (e) {
      debugPrint('Failed to reply approval: $e');
      isReplying.value = false;
    }
  }
}
