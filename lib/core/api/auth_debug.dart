import 'package:flutter/foundation.dart';

/// Temporary auth integration diagnostics.
/// Set [enabled] to false (or remove call sites) once the loop is verified fixed.
const bool kAuthDebug = true;

void authLog(String message) {
  if (kAuthDebug) {
    debugPrint('[AUTH] $message');
  }
}
