import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'file_drop_zone.dart';
import 'product_image.dart';

/// Admin product image field: browse, preview, replace, remove.
/// On web, also accepts drag-and-drop onto the preview area.
class ProductImagePickerField extends StatefulWidget {
  const ProductImagePickerField({
    super.key,
    this.existingImageUrl,
    this.onChanged,
  });

  final String? existingImageUrl;

  /// Called with selected bytes, or `null` when the image should be cleared.
  final ValueChanged<ProductImageSelection?>? onChanged;

  @override
  State<ProductImagePickerField> createState() =>
      _ProductImagePickerFieldState();
}

class ProductImageSelection {
  const ProductImageSelection({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

class _ProductImagePickerFieldState extends State<ProductImagePickerField> {
  final _picker = ImagePicker();
  ProductImageSelection? _selection;
  bool _removedExisting = false;
  bool _dragging = false;

  String? get _previewUrl {
    if (_removedExisting) return null;
    if (_selection != null) return null;
    return widget.existingImageUrl;
  }

  void _emit() {
    if (_removedExisting && _selection == null) {
      widget.onChanged?.call(null);
      return;
    }
    widget.onChanged?.call(_selection);
  }

  Future<void> _browse() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected image is empty — try another file')),
      );
      return;
    }
    var name = file.name.trim();
    if (name.isEmpty) {
      name = 'product.jpg';
    } else if (!RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
        .hasMatch(name)) {
      name = '$name.jpg';
    }
    setState(() {
      _selection = ProductImageSelection(
        bytes: bytes,
        filename: name,
      );
      _removedExisting = false;
    });
    _emit();
  }

  void _remove() {
    setState(() {
      _selection = null;
      _removedExisting = true;
    });
    _emit();
  }

  void _applyBytes(Uint8List bytes, String name) {
    if (bytes.isEmpty) return;
    var safeName = name.trim().isEmpty ? 'product.jpg' : name.trim();
    if (!RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
        .hasMatch(safeName)) {
      safeName = '$safeName.jpg';
    }
    setState(() {
      _selection = ProductImageSelection(bytes: bytes, filename: safeName);
      _removedExisting = false;
      _dragging = false;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (_selection != null) {
      preview = ColoredBox(
        color: AppColors.surfaceMuted,
        child: Image.memory(
          _selection!.bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: 180,
          alignment: Alignment.center,
        ),
      );
    } else if ((_previewUrl ?? '').isNotEmpty) {
      preview = ProductImage(
        imageUrl: _previewUrl,
        height: 180,
        width: double.infinity,
        borderRadius: 12,
      );
    } else {
      preview = Container(
        height: 180,
        width: double.infinity,
        alignment: Alignment.center,
        color: AppColors.surfaceMuted,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Drag & drop an image, or browse'
                  : 'Browse to upload a product image',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final framed = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _dragging ? AppColors.primary : AppColors.border,
          width: _dragging ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: preview,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product image', style: AppTextStyles.label),
        const SizedBox(height: 8),
        buildFileDropZone(
          onDrop: _applyBytes,
          onDragEnter: () => setState(() => _dragging = true),
          onDragLeave: () => setState(() => _dragging = false),
          child: framed,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _browse,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(
                _selection == null && (_previewUrl ?? '').isEmpty
                    ? 'Browse'
                    : 'Replace',
              ),
            ),
            if (_selection != null || (_previewUrl ?? '').isNotEmpty)
              TextButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}
