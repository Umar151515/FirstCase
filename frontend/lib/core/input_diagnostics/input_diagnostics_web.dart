import 'dart:js_interop';

import 'package:flutter/gestures.dart';

@JS('firstcaseRecordPointer')
external void _recordPointer(String phase);

@JS('firstcaseRecordNavigation')
external void _recordNavigation(String phase, String path);

void recordNavigation(String phase, String path) {
  try {
    _recordNavigation(phase, path);
  } catch (_) {
    // Diagnostics are optional and must never change navigation behavior.
  }
}

void installInputDiagnostics() {
  GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
    try {
      if (event is PointerDownEvent) _recordPointer('down');
      if (event is PointerUpEvent) _recordPointer('up');
    } catch (_) {
      // An old cached index or a blocked optional script must not affect input.
    }
  });
}
