import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../domain/model_info.dart';
import '../../domain/usage_info.dart';
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
              // Touch usageVersion so Obx rebuilds when usage changes.
              chatVm.usageVersion.value;
              final usage = chatVm.usageInfo;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── MODEL section ──
                  _sectionLabel('MODEL'),
                  const SizedBox(height: 10),
                  if (models.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No model options available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildCard(
                      children: models.map((m) => _buildModelRow(
                        m,
                        isSelected: m.value == current,
                        onTap: () => chatVm.changeModel(m.value),
                        isLast: m == models.last,
                      )).toList(),
                    ),

                  // ── COST & TOKENS section ──
                  const SizedBox(height: 24),
                  _sectionLabel('COST & TOKENS'),
                  const SizedBox(height: 10),
                  _buildCostCard(usage),

                  // ── CONTEXT WINDOW section ──
                  const SizedBox(height: 24),
                  _sectionLabel('CONTEXT WINDOW'),
                  const SizedBox(height: 10),
                  _buildContextCard(usage),
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMetadata,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  // ── Cost & Tokens card ──

  Widget _buildCostCard(UsageInfo? usage) {
    return _buildCard(
      children: [
        _kvRow('Cost', usage != null && usage.hasCost
            ? '\$${usage.costAmount.toStringAsFixed(3)}'
            : '—',
            isPrimary: true),
        _kvRow('Total tokens', usage != null && usage.totalTokens > 0
            ? _formatNumber(usage.totalTokens)
            : '—',
            isPrimary: true),
        _kvRow('Input', usage != null && usage.inputTokens > 0
            ? _formatNumber(usage.inputTokens)
            : '—',
            isPrimary: false),
        _kvRow('Output', usage != null && usage.outputTokens > 0
            ? _formatNumber(usage.outputTokens)
            : '—',
            isPrimary: false),
        _kvRow('Cache read', usage != null && usage.cachedReadTokens > 0
            ? _formatNumber(usage.cachedReadTokens)
            : '—',
            isPrimary: false),
        _kvRow('Cache write', usage != null && usage.cachedWriteTokens > 0
            ? _formatNumber(usage.cachedWriteTokens)
            : '—',
            isPrimary: false, isLast: true),
      ],
    );
  }

  Widget _kvRow(String label, String value, {
    bool isPrimary = true,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isPrimary ? 14 : 12,
      ).copyWith(left: isPrimary ? 16 : 32),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isPrimary ? 14 : 13,
              fontWeight: FontWeight.normal,
              color: isPrimary
                  ? AppTheme.textSecondary
                  : AppTheme.textMetadata,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isPrimary ? 14 : 13,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
              color: isPrimary
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Context Window card ──

  Widget _buildContextCard(UsageInfo? usage) {
    final hasContext = usage != null && usage.hasContext;
    final percent = hasContext ? usage.contextPercent : 0.0;
    final label = hasContext
        ? '${_formatNumber(usage.contextUsed)} / ${_formatNumber(usage.contextSize)}'
        : '—';
    final percentLabel = hasContext
        ? '${(percent * 100).round()}%'
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (percentLabel.isNotEmpty)
                Text(
                  percentLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Model row (existing) ──

  Widget _buildModelRow(ModelInfo model, {
    required bool isSelected,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : Colors.transparent,
          border: isLast ? null : const Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : AppTheme.textMetadata,
              ),
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
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (model.description != null &&
                      model.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        model.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : AppTheme.textMetadata,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.circle, size: 8, color: Colors.white),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    final str = n.toString();
    final result = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
      result.write(str[i]);
    }
    return result.toString();
  }
}
