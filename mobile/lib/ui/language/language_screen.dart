import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/theme.dart';
import '../../i18n/app_locales.dart';
import '../../i18n/tx.dart';
import 'language_viewmodel.dart';

class LanguageScreen extends GetView<LanguageViewModel> {
  const LanguageScreen({super.key});

  static const _fieldFill = Color(0xFFF0EAE5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GetBuilder<LanguageViewModel>(
        builder: (controller) {
          final selectedLocale = controller.selectedLocale.value;
          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _sectionLabel(Tx.languageAppLanguage.tr),
                    const SizedBox(height: 8),
                    _buildLanguageCard(selectedLocale),
                    const SizedBox(height: 8),
                    Text(
                      Tx.languageFooter.tr,
                      style: AppTypography.sans(
                        fontSize: 12,
                        color: AppTheme.textMetadata,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
            border: Border(bottom: BorderSide(color: AppTheme.borderStrong)),
          ),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: Get.back,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Tx.languageTitle.tr,
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
      text.toUpperCase(),
      style: AppTypography.mono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: AppTheme.textTertiary,
      ),
    );
  }

  Widget _buildLanguageCard(Locale selectedLocale) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldFill,
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < LanguageViewModel.options.length; i++)
            _buildLanguageRow(
              option: LanguageViewModel.options[i],
              isSelected: LanguageViewModel.options[i].locale == selectedLocale,
              showBottomDivider: i != LanguageViewModel.options.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageRow({
    required LanguageOption option,
    required bool isSelected,
    required bool showBottomDivider,
  }) {
    final tag = AppLocales.tagFor(option.locale);
    return GestureDetector(
      key: ValueKey('language-option-$tag'),
      onTap: () => controller.selectLocale(option.locale),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surface : Colors.transparent,
          border: isSelected
              ? Border.all(color: AppTheme.textPrimary, width: 1.5)
              : showBottomDivider
              ? const Border(bottom: BorderSide(color: AppTheme.border))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRadio(isSelected, tag: tag),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: AppTypography.sans(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
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

  Widget _buildRadio(bool isSelected, {required String tag}) {
    if (isSelected) {
      return Container(
        key: ValueKey('language-radio-$tag-selected'),
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
      key: ValueKey('language-radio-$tag-unselected'),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.chipBorder, width: 1.5),
      ),
    );
  }
}
