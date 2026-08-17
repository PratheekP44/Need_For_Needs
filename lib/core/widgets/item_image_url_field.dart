import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/product_image_url.dart';
import 'product_image.dart';

/// Admin Image URL field with live preview and non-blocking load errors.
class ItemImageUrlField extends StatefulWidget {
  const ItemImageUrlField({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  State<ItemImageUrlField> createState() => _ItemImageUrlFieldState();
}

class _ItemImageUrlFieldState extends State<ItemImageUrlField> {
  String? _formatHint;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _validateSoft(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant ItemImageUrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _validateSoft(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _validateSoft(widget.controller.text);
    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  void _validateSoft(String raw) {
    _formatHint = ProductImageUrlRules.validationError(raw);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image URL', style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Image URL',
            hintText: 'https://example.com/image.jpg',
            helperText: _formatHint ??
                'Paste a permanent public https URL (stored in MongoDB).',
            helperMaxLines: 2,
            helperStyle: AppTextStyles.caption.copyWith(
              color: _formatHint == null
                  ? AppColors.warmGray
                  : AppColors.primaryDark,
            ),
            prefixIcon: const Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Text('Preview', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.warmGray.withValues(alpha: 0.55),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: AppColors.warmGray,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No image URL yet',
                        style: TextStyle(color: AppColors.warmGray),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      imageUrl: url,
                      height: 160,
                      width: double.infinity,
                      borderRadius: 0,
                      icon: Icons.broken_image_outlined,
                      iconSize: 40,
                    ),
                    if (_formatHint != null)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Material(
                          color: AppColors.primaryDark.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              _formatHint!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.cream,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
