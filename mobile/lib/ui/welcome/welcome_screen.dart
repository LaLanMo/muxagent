import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import '../../i18n/tx.dart';
import 'welcome_viewmodel.dart';

class WelcomeScreen extends GetView<WelcomeViewModel> {
  const WelcomeScreen({super.key});

  static const _fieldFill = Color(0xFFF0EAE5);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: controller.dismissKeyboard,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.14),
                        _buildHero(),
                        const SizedBox(height: 24),
                        _buildScanButton(),
                        const SizedBox(height: 24),
                        _buildInstallSection(),
                        const SizedBox(height: 12),
                        Text(
                          Tx.welcomeOr.tr,
                          style: AppTypography.sans(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildManualConnectInput(),
                        const SizedBox(height: 24),
                        _buildFooter(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/app_icon.png',
          width: 72,
          height: 72,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 24),
        Text(
          'MuxAgent',
          textAlign: TextAlign.center,
          style: AppTypography.sans(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 260,
          child: Text(
            Tx.welcomeTagline.tr,
            textAlign: TextAlign.center,
            style: AppTypography.sans(
              fontSize: 16,
              color: AppTheme.textTertiary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: controller.onScanPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        color: AppTheme.primary,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.qrCode, size: 18, color: AppTheme.surface),
            const SizedBox(width: 10),
            Text(
              Tx.welcomeScanQr.tr,
              style: AppTypography.sans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallSection() {
    return GestureDetector(
      onTap: controller.onCopyCommand,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            Tx.welcomeRunDaemon.tr,
            textAlign: TextAlign.center,
            style: AppTypography.sans(
              fontSize: 12,
              color: AppTheme.textMetadata,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  welcomeInstallCommand,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.code(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.copy,
                size: 14,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualConnectInput() {
    return Obx(() {
      final urlError = controller.urlError.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _fieldFill,
              border: Border.all(color: AppTheme.chipBorder),
            ),
            child: TextField(
              controller: controller.urlController,
              onChanged: (_) => controller.clearUrlError(),
              onSubmitted: (_) => controller.onManualConnect(),
              onTapOutside: (_) => controller.dismissKeyboard(),
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.none,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              scrollPadding: const EdgeInsets.only(bottom: 120),
              style: AppTypography.sans(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: Tx.welcomeEnterServerUrl.tr,
                hintStyle: AppTypography.sans(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
          if (urlError != null) ...[
            const SizedBox(height: 8),
            Text(
              urlError,
              style: AppTypography.sans(
                fontSize: 11,
                color: AppTheme.errorText,
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildFooter() {
    return GestureDetector(
      onTap: controller.onGithubPressed,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.github,
            size: 14,
            color: AppTheme.textMetadata,
          ),
          const SizedBox(width: 6),
          Text(
            Tx.welcomeViewGithub.tr,
            style: AppTypography.sans(
              fontSize: 12,
              color: AppTheme.textMetadata,
            ),
          ),
        ],
      ),
    );
  }
}
