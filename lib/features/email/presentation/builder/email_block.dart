// lib/features/email/presentation/builder/email_block.dart
//
// Block model for the drag-and-drop email builder, plus an email-safe HTML
// generator. Pure Dart — no Flutter imports — so the HTML output is easy to
// reason about and reuse. Personalisation placeholders like {{first_name}} are
// left untouched (the Edge Functions substitute them at send time).

enum EmailBlockType { heading, text, image, button, divider, spacer }

extension EmailBlockTypeX on EmailBlockType {
  String get label {
    switch (this) {
      case EmailBlockType.heading:
        return 'Heading';
      case EmailBlockType.text:
        return 'Text';
      case EmailBlockType.image:
        return 'Image / GIF';
      case EmailBlockType.button:
        return 'Button';
      case EmailBlockType.divider:
        return 'Divider';
      case EmailBlockType.spacer:
        return 'Spacer';
    }
  }
}

class EmailBlock {
  final String id;
  EmailBlockType type;
  String text; // heading/text content, or button label
  String url; // image src, or button href
  String link; // optional link wrapping an image
  int height; // spacer height in px
  String align; // 'left' | 'center' | 'right'

  EmailBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.url = '',
    this.link = '',
    this.height = 24,
    this.align = 'left',
  });
}

/// Escapes the five XML/HTML special characters in user-entered text so the
/// content can't break out of the surrounding markup. Placeholders such as
/// {{first_name}} contain none of these, so they pass through unchanged.
String escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Sanitises a URL for use inside a double-quoted HTML attribute. Keeps it
/// simple: strips quotes/angle brackets/whitespace that would break the
/// attribute or inject markup.
String _safeUrl(String raw) {
  final u = raw.trim();
  return u
      .replaceAll('"', '%22')
      .replaceAll('<', '%3C')
      .replaceAll('>', '%3E')
      .replaceAll(' ', '%20');
}

String _blockHtml(EmailBlock b) {
  switch (b.type) {
    case EmailBlockType.heading:
      return '<h2 style="margin:0 0 14px;font-size:22px;font-weight:700;'
          'text-align:${b.align};color:#1a1f2c;">${escapeHtml(b.text)}</h2>';
    case EmailBlockType.text:
      return '<p style="margin:0 0 14px;font-size:15px;line-height:1.6;'
          'text-align:${b.align};color:#222222;">'
          '${escapeHtml(b.text).replaceAll('\n', '<br>')}</p>';
    case EmailBlockType.image:
      if (b.url.trim().isEmpty) return '';
      final margin = b.align == 'center'
          ? '0 auto'
          : (b.align == 'right' ? '0 0 0 auto' : '0');
      final img = '<img src="${_safeUrl(b.url)}" alt="" '
          'style="max-width:100%;height:auto;display:block;margin:$margin;" />';
      return b.link.trim().isEmpty
          ? img
          : '<a href="${_safeUrl(b.link)}" target="_blank">$img</a>';
    case EmailBlockType.button:
      if (b.text.trim().isEmpty) return '';
      final tableMargin = b.align == 'center'
          ? '14px auto'
          : (b.align == 'right' ? '14px 0 14px auto' : '14px 0');
      return '<table role="presentation" cellspacing="0" cellpadding="0" '
          'style="margin:$tableMargin;"><tr><td '
          'style="background:#1A5C38;border-radius:6px;">'
          '<a href="${_safeUrl(b.url)}" target="_blank" '
          'style="display:inline-block;padding:12px 22px;color:#ffffff;'
          'font-size:15px;font-weight:600;text-decoration:none;'
          'font-family:Arial,sans-serif;">${escapeHtml(b.text)}</a>'
          '</td></tr></table>';
    case EmailBlockType.divider:
      return '<hr style="border:none;border-top:1px solid #e5e7eb;'
          'margin:18px 0;" />';
    case EmailBlockType.spacer:
      final h = b.height <= 0 ? 1 : b.height;
      return '<div style="height:${h}px;line-height:${h}px;font-size:1px;">'
          '&nbsp;</div>';
  }
}

/// Renders the full ordered list of blocks into a single send-ready HTML
/// document fragment, wrapped in a centred 600px container.
String blocksToHtml(List<EmailBlock> blocks) {
  final buf = StringBuffer();
  for (final b in blocks) {
    final html = _blockHtml(b);
    if (html.isEmpty) continue;
    buf.writeln(html);
  }
  return '<div style="max-width:600px;margin:0 auto;padding:8px 12px;'
      'font-family:Arial,sans-serif;color:#222222;">\n'
      '$buf'
      '</div>';
}
