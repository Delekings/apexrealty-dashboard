// lib/features/legal/markdown_view.dart
//
// A small, dependency-free Markdown renderer covering exactly the subset used
// by Lintel's legal documents: ATX headings (#..######), **bold** / *italic*
// inline, bullet lists (- or *), pipe tables (with an optional :---: separator
// row), horizontal rules, and paragraphs. Returns a flat list of widgets so the
// caller can drop them into a lazy ListView for long documents.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const _bodyStyle = TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.text);

List<Widget> markdownToWidgets(String data) {
  final lines = data.replaceAll('\r\n', '\n').split('\n');
  final out = <Widget>[];
  var i = 0;
  while (i < lines.length) {
    final t = lines[i].trim();

    if (t.isEmpty) {
      out.add(const SizedBox(height: 9));
      i++;
      continue;
    }

    // Heading: #..######
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(t);
    if (h != null) {
      out.add(_heading(h.group(1)!.length, h.group(2)!));
      i++;
      continue;
    }

    // Horizontal rule
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(t)) {
      out.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: AppColors.border),
      ));
      i++;
      continue;
    }

    // Table: a run of lines starting with '|'
    if (t.startsWith('|')) {
      final rows = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add(lines[i].trim());
        i++;
      }
      out.add(_table(rows));
      continue;
    }

    // Bullet list: a run of '- ' or '* ' lines
    if (RegExp(r'^[*\-]\s+').hasMatch(t)) {
      final items = <String>[];
      while (i < lines.length && RegExp(r'^[*\-]\s+').hasMatch(lines[i].trim())) {
        items.add(lines[i].trim().replaceFirst(RegExp(r'^[*\-]\s+'), ''));
        i++;
      }
      out.add(_bullets(items));
      continue;
    }

    // Paragraph (one source line == one block; matches the docx export)
    out.add(Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: _rich(t, _bodyStyle),
    ));
    i++;
  }
  return out;
}

Widget _heading(int level, String text) {
  const sizes = <int, double>{
    1: 23,
    2: 18.5,
    3: 16,
    4: 15,
    5: 14,
    6: 13,
  };
  final size = sizes[level] ?? 14.0;
  return Padding(
    padding: EdgeInsets.only(top: level <= 2 ? 20 : 14, bottom: 7),
    child: Text(
      _stripEmphasis(text),
      style: TextStyle(
        fontSize: size,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: level <= 2 ? AppColors.brand : AppColors.text,
      ),
    ),
  );
}

Widget _bullets(List<String> items) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7, left: 4, right: 9),
                  child: Icon(Icons.circle, size: 5, color: AppColors.muted),
                ),
                Expanded(child: _rich(it, _bodyStyle)),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _table(List<String> rawRows) {
  List<String> cells(String r) {
    var s = r;
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s.split('|').map((c) => c.trim()).toList();
  }

  final parsed = rawRows.map(cells).toList();
  if (parsed.isEmpty) return const SizedBox.shrink();

  bool isSeparator(List<String> c) =>
      c.isNotEmpty &&
      c.every((x) => RegExp(r'^:?-{2,}:?$').hasMatch(x.replaceAll(' ', '')));

  var headerIndex = -1;
  List<List<String>> body;
  if (parsed.length >= 2 && isSeparator(parsed[1])) {
    headerIndex = 0;
    body = [parsed[0], ...parsed.sublist(2)];
  } else {
    body = parsed;
  }

  final cols = body.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  if (cols == 0) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Table(
      border: TableBorder.all(color: AppColors.border, width: 1),
      defaultColumnWidth: const FlexColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (var r = 0; r < body.length; r++)
          TableRow(
            decoration: r == headerIndex
                ? const BoxDecoration(color: AppColors.bg3)
                : null,
            children: [
              for (var c = 0; c < cols; c++)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: r == headerIndex
                      ? Text(
                          _stripEmphasis(c < body[r].length ? body[r][c] : ''),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        )
                      : _rich(
                          c < body[r].length ? body[r][c] : '',
                          const TextStyle(
                              fontSize: 13, height: 1.4, color: AppColors.text),
                        ),
                ),
            ],
          ),
      ],
    ),
  );
}

/// Removes markdown emphasis markers and backslash escapes, returning plain text.
String _stripEmphasis(String s) {
  final sb = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    if (ch == '\\' && i + 1 < s.length) {
      sb.write(s[i + 1]);
      i += 2;
      continue;
    }
    if (ch == '*') {
      i++;
      continue;
    }
    sb.write(ch);
    i++;
  }
  return sb.toString();
}

/// Inline renderer: parses **bold**, *italic*, and \-escapes into a RichText.
Widget _rich(String s, TextStyle base) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  var bold = false;
  var italic = false;

  TextStyle current() => base.copyWith(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  void flush() {
    if (buf.isNotEmpty) {
      spans.add(TextSpan(text: buf.toString(), style: current()));
      buf.clear();
    }
  }

  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    if (ch == '\\' && i + 1 < s.length) {
      buf.write(s[i + 1]);
      i += 2;
      continue;
    }
    if (ch == '*' && i + 1 < s.length && s[i + 1] == '*') {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }
    if (ch == '*') {
      flush();
      italic = !italic;
      i++;
      continue;
    }
    buf.write(ch);
    i++;
  }
  flush();

  return RichText(text: TextSpan(style: base, children: spans));
}
