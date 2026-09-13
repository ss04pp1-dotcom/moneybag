import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Circular profile photo with camera badge.
///
/// Shows the picked photo (or the user's initial as fallback) and opens a
/// Camera / Gallery / Remove sheet on tap. The photo is stored in the app's
/// documents directory and survives restarts.
class MbAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTapOverride;
  final bool showBadge;

  const MbAvatar({
    super.key,
    this.size = 48,
    this.onTapOverride,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MbAppState>();
    final scheme = Theme.of(context).colorScheme;
    final path = state.avatarPath;
    final file = path == null ? null : File(path);

    Widget child;
    if (file != null && file.existsSync()) {
      child = ClipOval(
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initial(context),
        ),
      );
    } else {
      child = _initial(context);
    }

    return Semantics(
      label: context.L.photoTitle,
      button: true,
      child: GestureDetector(
        onTap: onTapOverride ?? () => _openSheet(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MbPalette.green, MbPalette.greenDark],
            ),
            border: Border.all(color: scheme.outlineVariant, width: 1),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (showBadge)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: size * 0.34,
                    height: size * 0.34,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: scheme.primary.withOpacity(0.6), width: 1.2),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: size * 0.2,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initial(BuildContext context) {
    final state = context.watch<MbAppState>();
    final ch = state.userName.isEmpty
        ? '৳'
        : state.userName.characters.first.toUpperCase();
    return Center(
      child: Text(
        ch,
        style: TextStyle(
          color: const Color(0xFF06130C),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final L = context.L;
    final state = context.read<MbAppState>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                L.photoTitle,
                style: const TextStyle(
                  fontFamily: 'NotoSansBengali',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(L.photoCamera),
              onTap: () {
                Navigator.pop(ctx);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(L.photoGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pick(context, ImageSource.gallery);
              },
            ),
            if (state.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: MbPalette.danger),
                title: Text(L.photoRemove,
                    style: const TextStyle(color: MbPalette.danger)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await state.clearAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final state = context.read<MbAppState>();
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 82,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      await state.setAvatarBytes(bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.L.error}: $e')),
        );
      }
    }
  }
}
