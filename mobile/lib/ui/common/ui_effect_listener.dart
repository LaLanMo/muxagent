import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../domain/ui_effect.dart';
import '../../utils/app_toast.dart';

class UiEffectListener extends StatefulWidget {
  final Rxn<UiEffect> effects;
  final Widget child;

  const UiEffectListener({
    super.key,
    required this.effects,
    required this.child,
  });

  @override
  State<UiEffectListener> createState() => _UiEffectListenerState();
}

class _UiEffectListenerState extends State<UiEffectListener> {
  late final Worker _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever(widget.effects, _onEffect);
  }

  void _onEffect(UiEffect? e) {
    if (e == null) return;
    switch (e) {
      case ShowToast(:final message):
        AppToast.show(message);
    }
    widget.effects.value = null;
  }

  @override
  void dispose() {
    _worker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
