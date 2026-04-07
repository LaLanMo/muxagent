import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:muxagent/config/app_typography.dart';

import '../../config/fonts.dart';
import '../../config/theme.dart';
import 'welcome_viewmodel.dart';

class WelcomeScreen extends GetView<WelcomeViewModel> {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final compactHero = keyboardInset > 0 || mediaQuery.size.height < 720;

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
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: compactHero ? 24 : 40,
                            bottom: 24,
                          ),
                          child: _buildHero(compactHero),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: compactHero ? 24 : 32,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildScanButton(),
                              const SizedBox(height: 16),
                              _buildInstallCard(),
                              const SizedBox(height: 8),
                              _buildDivider(),
                              const SizedBox(height: 16),
                              _buildManualConnectInput(),
                              const SizedBox(height: 24),
                              _buildFooter(),
                              SizedBox(height: compactHero ? 0 : 16),
                            ],
                          ),
                        ),
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

  Widget _buildHero(bool compact) {
    final logoSize = compact ? 64.0 : 80.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/app_icon.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: compact ? 16 : 24),
        Text(
          'MuxAgent',
          textAlign: TextAlign.center,
          style: AppTypography.sans(
            fontSize: compact ? 28 : 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: compact ? 12 : 24),
        Text(
          'Control your coding agents\nfrom anywhere',
          textAlign: TextAlign.center,
          style: AppTypography.sans(
            fontSize: compact ? 15 : 16,
            fontWeight: FontWeight.normal,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: controller.onScanPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.qrCode,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'Scan QR Code',
              style: AppTypography.sans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallCard() {
    return GestureDetector(
      onTap: controller.onCopyCommand,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.monitor,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Install Command',
                        style: AppTypography.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Run in terminal',
                        style: AppTypography.sans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.hoverBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.copy,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Copy',
                        style: AppTypography.sans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RichText(
                  text: TextSpan(
                    style: AppFonts.code(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    children: const [
                      TextSpan(
                        text: r'$ ',
                        style: TextStyle(color: AppTheme.textTertiary),
                      ),
                      TextSpan(text: welcomeInstallCommand),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF0F0F0),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'or',
            style: AppTypography.sans(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF0F0F0),
            ),
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
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.link,
                  size: 18,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller.urlController,
                    onChanged: (_) => controller.clearUrlError(),
                    onSubmitted: (_) => controller.onManualConnect(),
                    onTapOutside: (_) => controller.dismissKeyboard(),
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    style: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Enter server URL...',
                      hintStyle: AppTypography.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (urlError != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                urlError,
                style: AppTypography.sans(
                  fontSize: 11,
                  color: AppTheme.errorText,
                ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.github,
            size: 18,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            'View on GitHub',
            style: AppTypography.sans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
