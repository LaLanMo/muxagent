import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../domain/model_info.dart';
import '../../domain/usage_info.dart';
import '../chat/chat_viewmodel.dart';

class SessionSettingsScreen extends StatelessWidget {
  const SessionSettingsScreen({super.key});

  static const _fieldFill = Color(0xFFF0EAE5);

  @override
  Widget build(BuildContext context) {
    final chatVm = Get.find<ChatViewModel>();

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _sectionLabel('MODEL'),
                  const SizedBox(height: 8),
                  _buildModelSection(
                    models: models,
                    current: current,
                    onSelect: (value) => chatVm.changeModel(value),
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('COST & TOKENS'),
                  const SizedBox(height: 8),
                  _buildCostSection(usage),
                  const SizedBox(height: 16),
                  _sectionLabel('CONTEXT WINDOW'),
                  const SizedBox(height: 8),
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
            border: Border(
              bottom: BorderSide(color: AppTheme.borderStrong),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: Get.back,
                child: const Icon(
                  LucideIcons.chevronLeft,
                  size: 20,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Session Settings',
                style: AppTypography.sans(
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
      style: AppTypography.mono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildModelSection({
    required List<ModelInfo> models,
    required String? current,
    required ValueChanged<String> onSelect,
  }) {
    if (models.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _fieldFill,
          border: Border.all(color: AppTheme.borderStrong),
        ),
        child: Text(
          'No model options available',
          style: AppTypography.sans(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < models.length; i++)
            _buildModelRow(
              model: models[i],
              isSelected: models[i].value == current,
              showBottomDivider:
                  i != models.length - 1 && models[i + 1].value != current,
              onTap: () => onSelect(models[i].value),
            ),
        ],
      ),
    );
  }

  Widget _buildModelRow({
    required ModelInfo model,
    required bool isSelected,
    required bool showBottomDivider,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surface : Colors.transparent,
          border: isSelected
              ? Border.all(color: AppTheme.textPrimary, width: 1.5)
              : showBottomDivider
              ? const Border(
                  bottom: BorderSide(color: AppTheme.border),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRadio(isSelected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (model.description?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        model.description!.trim(),
                        style: AppTypography.sans(
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

  Widget _buildRadio(bool isSelected) {
    if (isSelected) {
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.chipBorder, width: 1.5),
      ),
    );
  }

  Widget _buildCostSection(UsageInfo? usage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCostRow(
          label: 'Cost',
          value: usage != null && usage.hasCost
              ? '\$${usage.costAmount.toStringAsFixed(3)}'
              : '—',
          isPrimary: true,
        ),
        _buildCostRow(
          label: 'Total tokens',
          value: usage != null && usage.totalTokens > 0
              ? _formatNumber(usage.totalTokens)
              : '—',
          isPrimary: true,
        ),
        _buildCostRow(
          label: 'Input',
          value: usage != null && usage.inputTokens > 0
              ? _formatNumber(usage.inputTokens)
              : '—',
        ),
        _buildCostRow(
          label: 'Output',
          value: usage != null && usage.outputTokens > 0
              ? _formatNumber(usage.outputTokens)
              : '—',
        ),
        _buildCostRow(
          label: 'Cache read',
          value: usage != null && usage.cachedReadTokens > 0
              ? _formatNumber(usage.cachedReadTokens)
              : '—',
        ),
        _buildCostRow(
          label: 'Cache write',
          value: usage != null && usage.cachedWriteTokens > 0
              ? _formatNumber(usage.cachedWriteTokens)
              : '—',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildCostRow({
    required String label,
    required String value,
    bool isPrimary = false,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(isPrimary ? 0 : 16, 12, 0, 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppTheme.border),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.sans(
              fontSize: isPrimary ? 14 : 13,
              color: isPrimary
                  ? AppTheme.textSecondary
                  : AppTheme.textTertiary,
            ),
          ),
          Text(
            value,
            style: AppTypography.mono(
              fontSize: 13,
              color: isPrimary
                  ? AppTheme.textPrimary
                  : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard(UsageInfo? usage) {
    final hasContext = usage != null && usage.hasContext;
    final percent = hasContext ? usage.contextPercent.clamp(0.0, 1.0) : 0.0;
    final label = hasContext
        ? '${_formatNumber(usage.contextUsed)} / ${_formatNumber(usage.contextSize)}'
        : '—';
    final percentLabel = hasContext ? '${(percent * 100).round()}%' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.chipBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.mono(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (percentLabel.isNotEmpty)
                Text(
                  percentLabel,
                  style: AppTypography.mono(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 3,
            child: Container(
              color: AppTheme.border,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: percent,
                  child: Container(color: AppTheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
