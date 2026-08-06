import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Stub (non-web): ignore file drops; browse still works via image_picker.
Widget buildFileDropZone({
  required Widget child,
  required void Function(Uint8List bytes, String filename) onDrop,
  VoidCallback? onDragEnter,
  VoidCallback? onDragLeave,
}) {
  return child;
}
