// lib/features/documents/widgets/signature_pad.dart
//
// A widget that captures a signature via one of:
//   - Drawing on a canvas with mouse/finger
//   - Uploading an image file
// Returns PNG bytes on save.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_theme.dart';

enum SignatureMode { draw, upload }

class SignaturePadResult {
  final Uint8List pngBytes;
  final String method; // 'drawn' or 'uploaded'
  SignaturePadResult(this.pngBytes, this.method);
}

class SignaturePad extends StatefulWidget {
  final void Function(SignaturePadResult result) onSaved;
  final double height;

  const SignaturePad({
    super.key,
    required this.onSaved,
    this.height = 180,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  SignatureMode _mode = SignatureMode.draw;
  final GlobalKey _canvasKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  Uint8List? _uploadedBytes;
  bool _isSaving = false;

  bool get _hasContent =>
      _mode == SignatureMode.draw ? _strokes.isNotEmpty : _uploadedBytes != null;

  Future<void> _pickUpload() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() => _uploadedBytes = f.bytes);
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = [];
      _uploadedBytes = null;
    });
  }

  Future<void> _save() async {
    if (!_hasContent) return;
    setState(() => _isSaving = true);
    try {
      if (_mode == SignatureMode.draw) {
        final bytes = await _exportCanvas();
        widget.onSaved(SignaturePadResult(bytes, 'drawn'));
      } else if (_uploadedBytes != null) {
        widget.onSaved(SignaturePadResult(_uploadedBytes!, 'uploaded'));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<Uint8List> _exportCanvas() async {
    final boundary = _canvasKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode picker
        Row(
          children: [
            _modeChip(SignatureMode.draw, 'Draw', Icons.gesture),
            const SizedBox(width: 6),
            _modeChip(SignatureMode.upload, 'Upload image', Icons.upload),
            const Spacer(),
            if (_hasContent)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Clear',
                    style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Canvas / upload zone
        if (_mode == SignatureMode.draw)
          _canvas()
        else
          _uploadZone(),

        const SizedBox(height: 10),

        // Save button
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: (_hasContent && !_isSaving) ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 14),
            label: Text(_isSaving ? 'Saving…' : 'Save signature'),
          ),
        ),
      ],
    );
  }

  Widget _modeChip(SignatureMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = mode;
        _strokes.clear();
        _current = [];
        _uploadedBytes = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandLight : AppColors.bg,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? AppColors.brand : AppColors.muted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? AppColors.brand : AppColors.text)),
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RepaintBoundary(
        key: _canvasKey,
        child: Stack(
          children: [
            // White background
            Container(color: Colors.white),
            // Drawing surface
            GestureDetector(
              onPanStart: (d) {
                _current = [d.localPosition];
                setState(() => _strokes.add(_current));
              },
              onPanUpdate: (d) {
                setState(() => _current.add(d.localPosition));
              },
              child: CustomPaint(
                painter: _SigPainter(_strokes),
                size: Size.infinite,
              ),
            ),
            // Placeholder text
            if (_strokes.isEmpty)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'Sign here with mouse or finger',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            // Bottom signature line
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                height: 0.6,
                color: AppColors.border,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadZone() {
    if (_uploadedBytes == null) {
      return InkWell(
        onTap: _pickUpload,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.border,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 28, color: AppColors.muted),
                SizedBox(height: 6),
                Text('Click to upload signature image',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.muted)),
                Text('PNG, JPG, or WEBP — max 2MB',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Image.memory(_uploadedBytes!, fit: BoxFit.contain),
      ),
    );
  }
}

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SigPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.1, paint..style = PaintingStyle.fill);
        }
        continue;
      }
      paint.style = PaintingStyle.stroke;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SigPainter old) => old.strokes != strokes;
}