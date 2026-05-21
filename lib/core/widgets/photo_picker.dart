// lib/core/widgets/photo_picker.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A photo file selected by the user, ready for upload.
class PickedPhoto {
  final Uint8List bytes;
  final String filename;
  PickedPhoto({required this.bytes, required this.filename});
}

/// Multi-image picker — works on web (uses FilePicker.platform.pickFiles).
/// Shows thumbnails of selected files, lets you remove them before uploading.
class PhotoPicker extends StatefulWidget {
  final ValueChanged<List<PickedPhoto>> onChanged;
  final int maxFiles;

  const PhotoPicker({
    super.key,
    required this.onChanged,
    this.maxFiles = 10,
  });

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  final List<PickedPhoto> _photos = [];

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,  // we need bytes since web has no file paths
    );
    if (res == null) return;

    final picked = <PickedPhoto>[];
    for (final f in res.files) {
      if (f.bytes == null) continue;
      picked.add(PickedPhoto(bytes: f.bytes!, filename: f.name));
    }

    setState(() {
      final remaining = widget.maxFiles - _photos.length;
      _photos.addAll(picked.take(remaining));
    });
    widget.onChanged(_photos);
  }

  void _remove(int i) {
    setState(() => _photos.removeAt(i));
    widget.onChanged(_photos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dashed drop zone
        InkWell(
          onTap: _photos.length < widget.maxFiles ? _pick : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    size: 32, color: AppColors.muted),
                const SizedBox(height: 8),
                Text(
                  _photos.length < widget.maxFiles
                      ? 'Click to select photos'
                      : 'Maximum ${widget.maxFiles} photos reached',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'JPG, PNG, or WebP · up to 10 MB each · max ${widget.maxFiles} photos',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),

        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('${_photos.length} photo${_photos.length == 1 ? '' : 's'} selected',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _photos[i].bytes,
                        width: 80, height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -4, right: -4,
                      child: Material(
                        shape: const CircleBorder(),
                        color: AppColors.text,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _remove(i),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.close,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}