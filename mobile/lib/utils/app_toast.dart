import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:muxagent/config/app_typography.dart';

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _key = GlobalKey<_ToastState>();

  static void show(String message) {
    // Remove any existing toast immediately
    _dismiss();

    final context = Get.overlayContext;
    if (context == null) return;

    _entry = OverlayEntry(
      builder: (_) => _ToastWidget(key: _key, message: message),
    );

    try {
      Overlay.of(context).insert(_entry!);
    } catch (_) {
      _entry = null;
      return;
    }

    // Auto-dismiss after 2s
    _timer = Timer(const Duration(seconds: 2), () {
      final state = _key.currentState;
      if (state != null) {
        state.fadeOut().then((_) => _dismiss());
      } else {
        _dismiss();
      }
    });
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    try {
      _entry?.remove();
    } catch (_) {
      // Entry may already be detached (e.g. after Get.offAllNamed)
    }
    _entry = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;

  const _ToastWidget({super.key, required this.message});

  @override
  State<_ToastWidget> createState() => _ToastState();
}

class _ToastState extends State<_ToastWidget> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  Future<void> fadeOut() async {
    if (!mounted) return;
    setState(() => _opacity = 0);
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return Positioned(
      bottom: 120 + keyboardHeight,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1D1F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.message,
                    style: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
