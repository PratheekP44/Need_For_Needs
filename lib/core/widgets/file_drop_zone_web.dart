import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Web: HTML5 drag-and-drop overlay over [child].
Widget buildFileDropZone({
  required Widget child,
  required void Function(Uint8List bytes, String filename) onDrop,
  VoidCallback? onDragEnter,
  VoidCallback? onDragLeave,
}) {
  return _HtmlFileDropZone(
    onDrop: onDrop,
    onDragEnter: onDragEnter,
    onDragLeave: onDragLeave,
    child: child,
  );
}

class _HtmlFileDropZone extends StatefulWidget {
  const _HtmlFileDropZone({
    required this.child,
    required this.onDrop,
    this.onDragEnter,
    this.onDragLeave,
  });

  final Widget child;
  final void Function(Uint8List bytes, String filename) onDrop;
  final VoidCallback? onDragEnter;
  final VoidCallback? onDragLeave;

  @override
  State<_HtmlFileDropZone> createState() => _HtmlFileDropZoneState();
}

class _HtmlFileDropZoneState extends State<_HtmlFileDropZone> {
  late final String _viewType;
  final List<StreamSubscription<html.Event>> _subs = [];

  @override
  void initState() {
    super.initState();
    _viewType =
        'nfn-file-drop-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final root = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative';

      final overlay = html.DivElement()
        ..style.position = 'absolute'
        ..style.left = '0'
        ..style.top = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.zIndex = '10'
        ..style.background = 'transparent';

      void prevent(html.Event e) {
        e.preventDefault();
        e.stopPropagation();
      }

      _subs.add(overlay.onDragOver.listen((e) {
        prevent(e);
        widget.onDragEnter?.call();
      }));
      _subs.add(overlay.onDragEnter.listen((e) {
        prevent(e);
        widget.onDragEnter?.call();
      }));
      _subs.add(overlay.onDragLeave.listen((e) {
        prevent(e);
        widget.onDragLeave?.call();
      }));
      _subs.add(overlay.onDrop.listen((e) async {
        prevent(e);
        widget.onDragLeave?.call();
        final dt = e.dataTransfer;
        if (dt == null) return;
        final files = dt.files;
        if (files == null || files.isEmpty) return;
        final file = files.first;
        if (!file.type.startsWith('image/')) return;
        final reader = html.FileReader();
        final done = reader.onLoad.first;
        reader.readAsArrayBuffer(file);
        await done;
        final result = reader.result;
        if (result is ByteBuffer) {
          widget.onDrop(result.asUint8List(), file.name);
        }
      }));

      root.append(overlay);
      return root;
    });
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),
      ],
    );
  }
}
