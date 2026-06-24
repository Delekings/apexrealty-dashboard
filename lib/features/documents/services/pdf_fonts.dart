// lib/features/documents/services/pdf_fonts.dart
//
// Shared PDF font theme. The pdf package's built-in Helvetica has no glyph for
// the Naira sign (₦, U+20A6), so amounts render as a tofu box. Noto Sans covers
// it, so we load it via printing's Google Fonts helper and use it as the
// document theme. The fonts are fetched once and cached for the session.

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfFonts {
  PdfFonts._();

  static pw.ThemeData? _cached;

  /// A theme whose base/bold/italic fonts all support the Naira sign.
  ///
  /// Falls back to `null` (the default Helvetica) if the fonts can't be
  /// fetched, so document generation never fails because of font loading —
  /// in that rare offline case amounts simply lose the ₦ glyph.
  static Future<pw.ThemeData?> theme() async {
    if (_cached != null) return _cached;
    try {
      final theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
        italic: await PdfGoogleFonts.notoSansItalic(),
        boldItalic: await PdfGoogleFonts.notoSansBoldItalic(),
      );
      _cached = theme;
      return theme;
    } catch (_) {
      return null;
    }
  }
}
