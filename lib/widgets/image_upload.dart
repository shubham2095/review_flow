import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/gbp_service.dart';

class UploadedImage {
  UploadedImage({required this.url, required this.bytes});

  final String url;
  final Uint8List bytes;
}

/// Lets the user pick from the gallery or take a photo, then uploads it and
/// returns the public URL. Returns null when the user backs out. Throws on a
/// failed upload so the caller can show the message.
Future<UploadedImage?> pickAndUploadImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  var name = picked.name.isEmpty ? 'photo.jpg' : picked.name;
  if (!name.contains('.')) name = '$name.jpg';

  final url = await GbpService.uploadImage(bytes, name);
  return UploadedImage(url: url, bytes: bytes);
}
