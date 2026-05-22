// lib/features/signing/widgets/typed_signature.dart
//
// Renders the signer's name in a cursive font as their signature.
// Outputs PNG bytes ready to embed in the PDF.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_theme.dart';

class TypedSignaturePad extends StatefulWidget {
  final void Function(Uint8List pngBytes, String typedName) onSaved;
  final String initialName;

  const TypedSignaturePad({
    super.key,
    required this.onSaved,
    this.initialName = '',
  });

  @override
  State<TypedSignaturePad> createState() => _TypedSignaturePadState();
}

class _TypedSignaturePadState extends State<TypedSignaturePad> {
  late final TextEditingController _name;
  final GlobalKey _renderKey = GlobalKey();
  bool _saving = false;

  // A handful of cursive-feeling font styles to pick from.
  static const _styles = <_SigStyle>[
    _SigStyle('Casual', 'Cursive',
        FontStyle.italic, FontWeight.w600, 1.0),
    _SigStyle('Elegant', 'Serif',
        FontStyle.italic, FontWeight.w400, 1.1),
    _SigStyle('Bold', 'Sans',
        FontStyle.italic, FontWeight.w700, 0.95),
  ];
  int _styleIndex = 0;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final boundary = _renderKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      widget.onSaved(byteData!.buffer.asUint8List(), _name.text.trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styles[_styleIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Type your full name',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Style:',
                style: TextStyle(
                    fontSize: 12, color: AppColors.muted)),
            const SizedBox(width: 8),
            for (var i = 0; i < _styles.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _styleIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _styleIndex == i
                          ? AppColors.brandLight
                          : AppColors.bg,
                      border: Border.all(
                        color: _styleIndex == i
                            ? AppColors.brand
                            : AppColors.border,
                        width: _styleIndex == i ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_styles[i].label,
                        style: TextStyle(
                            fontSize: 11,
                            color: _styleIndex == i
                                ? AppColors.brand
                                : AppColors.text)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: RepaintBoundary(
            key: _renderKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              alignment: Alignment.center,
              child: _name.text.trim().isEmpty
                  ? const Text('Your signature appears here',
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 13))
                  : Text(
                _name.text.trim(),
                style: TextStyle(
                  fontSize: 36 * style.scale,
                  fontStyle: style.style,
                  fontWeight: style.weight,
                  color: const Color(0xFF1A1A2E),
                  fontFamily: style.family,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: (_name.text.trim().isNotEmpty && !_saving)
                ? _save
                : null,
            icon: _saving
                ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 14),
            label: Text(_saving ? 'Saving…' : 'Use this signature'),
          ),
        ),
      ],
    );
  }
}

class _SigStyle {
  final String label;
  final String family;
  final FontStyle style;
  final FontWeight weight;
  final double scale;
  const _SigStyle(this.label, this.family, this.style, this.weight, this.scale);
}