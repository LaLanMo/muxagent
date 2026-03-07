import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../domain/model_info.dart';
import '../chat/chat_viewmodel.dart';

class SessionSettingsScreen extends StatelessWidget {
  const SessionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatVm = Get.find<ChatViewModel>();

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Obx(() {
              final models = chatVm.availableModels.toList();
              final current = chatVm.currentModel.value;

              if (models.isEmpty) {
                return Center(
                  child: Text(
                    'No model options available',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'MODEL',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...models.map((m) => _buildModelRow(
                        m,
                        isSelected: m.value == current,
                        onTap: () => chatVm.changeModel(m.value),
                      )),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: const Icon(
                  LucideIcons.chevronLeft,
                  size: 22,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Session Settings',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelRow(ModelInfo model, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? AppTheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                  if (model.description != null && model.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        model.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
