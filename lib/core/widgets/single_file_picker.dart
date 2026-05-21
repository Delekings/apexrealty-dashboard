// lib/core/widgets/single_file_picker.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PickedFile {
  final Uint8List bytes;
  final String filename;
  PickedFile({required this.bytes, required this.filename});
}

/// Single-file image/PDF picker for receipts and similar.
class SingleFilePicker extends StatefulWidget {
  final ValueChanged<PickedFile?> onChanged;
  final String label;
  final List<String> allowedExtensions;

  const SingleFilePicker({
    super.key,
    required this.onChanged,
    this.label = 'Attach file',
    this.allowedExtensions = const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
  });

  @override
  State<SingleFilePicker> createState() => _SingleFilePickerState();
}

class _SingleFilePickerState extends State<SingleFilePicker> {
  PickedFile? _file;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.allowedExtensions,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;

    final picked = PickedFile(bytes: f.bytes!, filename: f.name);
    setState(() => _file = picked);
    widget.onChanged(picked);
  }

  void _clear() {
    setState(() => _file = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return InkWell(
        onTap: _pick,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.attach_file,
                  size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isImage = !_file!.filename.toLowerCase().endsWith('.pdf');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brand, width: 1),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(_file!.bytes,
                  width: 36, height: 36, fit: BoxFit.cover),
            )
          else
            const Icon(Icons.picture_as_pdf,
                size: 28, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_file!.filename,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: _clear,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}