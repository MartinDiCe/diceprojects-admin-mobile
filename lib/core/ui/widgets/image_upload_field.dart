import 'dart:io';

import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadField extends StatefulWidget {
  final String label;
  final String? imageUrl;
  final String helperText;
  final ValueChanged<XFile?> onChanged;
  final double height;

  const ImageUploadField({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.onChanged,
    this.helperText = 'JPG, PNG o WEBP. Podés elegir de galería o tomar foto.',
    this.height = 168,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selected;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 86,
    );
    if (!mounted || file == null) return;
    setState(() => _selected = file);
    widget.onChanged(file);
  }

  void _clear() {
    setState(() => _selected = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveMediaUrl(widget.imageUrl);
    final hasImage = _selected != null || resolvedUrl != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: widget.height,
              width: double.infinity,
              color: AppColors.surfaceVariant,
              child: hasImage
                  ? _selected != null
                      ? Image.file(File(_selected!.path), fit: BoxFit.cover)
                      : Image.network(
                          resolvedUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImageEmptyState(),
                        )
                  : const _ImageEmptyState(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.helperText,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ImageActionButton(
                icon: Icons.photo_library_rounded,
                label: 'Galería',
                onTap: () => _pick(ImageSource.gallery),
              ),
              _ImageActionButton(
                icon: Icons.photo_camera_rounded,
                label: 'Cámara',
                onTap: () => _pick(ImageSource.camera),
              ),
              if (hasImage)
                _ImageActionButton(
                  icon: Icons.close_rounded,
                  label: 'Quitar',
                  onTap: _clear,
                  danger: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageEmptyState extends StatelessWidget {
  const _ImageEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.add_photo_alternate_rounded,
        size: 42,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ImageActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.accent;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
    );
  }
}

String? resolveMediaUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  final apiBase = Uri.parse(AppConfig.apiBaseUrl);
  final origin = '${apiBase.scheme}://${apiBase.host}${apiBase.hasPort ? ':${apiBase.port}' : ''}';

  if (value.startsWith('/api/')) return '$origin$value';
  if (value.startsWith('/')) return '${AppConfig.apiBaseUrl}$value';
  return '${AppConfig.apiBaseUrl}/$value';
}
