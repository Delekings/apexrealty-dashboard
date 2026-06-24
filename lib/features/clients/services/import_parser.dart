// lib/features/clients/services/import_parser.dart
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// One row of imported client data, normalized and ready for validation.
class ImportRow {
  String fullName;
  String phone;
  String email;
  String state;
  String address;
  String dateOfBirth; // ISO yyyy-MM-dd
  String occupation;

  ImportRow({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.state = '',
    this.address = '',
    this.dateOfBirth = '',
    this.occupation = '',
  });

  Map<String, String?> validate() => {
    'fullName': fullName.trim().isEmpty ? 'Full name is required' : null,
    'phone': _validatePhone(phone),
    'email': _validateEmail(email),
    'dateOfBirth': _validateDate(dateOfBirth),
  };

  bool get isValid => validate().values.every((v) => v == null);

  Map<String, dynamic> toRpcMap() => {
    'full_name': fullName.trim(),
    'phone': phone.trim(),
    if (email.trim().isNotEmpty) 'email': email.trim(),
    if (state.trim().isNotEmpty) 'state': state.trim(),
    if (address.trim().isNotEmpty) 'address': address.trim(),
    if (dateOfBirth.trim().isNotEmpty) 'date_of_birth': dateOfBirth.trim(),
    if (occupation.trim().isNotEmpty) 'occupation': occupation.trim(),
  };

  static String? _validatePhone(String p) {
    final s = p.trim();
    if (s.isEmpty) return null; // phone is optional
    if (s.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').length < 10) {
      return 'Phone looks too short';
    }
    return null;
  }

  static String? _validateEmail(String e) {
    final s = e.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
      return 'Invalid email format';
    }
    return null;
  }

  static String? _validateDate(String d) {
    final s = d.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      return 'Use YYYY-MM-DD format';
    }
    try {
      DateTime.parse(s);
      return null;
    } catch (_) {
      return 'Invalid date';
    }
  }
}

const _columnAliases = <String, List<String>>{
  'fullName': [
    'full name', 'name', 'client name', 'customer name', 'contact name',
  ],
  'firstName': ['first name', 'firstname', 'fname', 'given name'],
  'lastName': ['last name', 'lastname', 'lname', 'surname', 'family name'],
  'phone': [
    'phone', 'phone number', 'mobile', 'mobile number', 'tel', 'telephone',
    'telephone number', 'whatsapp', 'cell', 'msisdn', 'number',
  ],
  'email': ['email', 'email address', 'e-mail', 'mail'],
  'state': ['state', 'region', 'province', 'state of origin'],
  'address': ['address', 'street', 'home address', 'residential address'],
  'dateOfBirth': ['date of birth', 'dob', 'birthday', 'birthdate', 'born'],
  'occupation': ['occupation', 'job', 'profession', 'role', 'job title'],
};

Map<String, int> autoDetectColumns(List<String> headers,
    [List<List<String>> sampleRows = const []]) {
  final mapping = <String, int>{};
  final lower = headers.map((h) => h.toLowerCase().trim()).toList();

  for (final entry in _columnAliases.entries) {
    for (int i = 0; i < lower.length; i++) {
      if (entry.value.contains(lower[i])) {
        mapping.putIfAbsent(entry.key, () => i);
        break;
      }
    }
  }

  // Data-aware refinement. Header names alone are unreliable on messy exports
  // (e.g. a "Email" column that actually contains "anonymous"). When we have
  // sample rows, prefer the column whose VALUES look like the field — but only
  // if the header-guessed column clearly doesn't.
  if (sampleRows.isNotEmpty) {
    int score(int col, bool Function(String) test) {
      var n = 0;
      for (final r in sampleRows) {
        if (col >= 0 && col < r.length && test(r[col])) n++;
      }
      return n;
    }

    void refine(String field, bool Function(String) test) {
      final cur = mapping[field];
      final curScore = cur == null ? 0 : score(cur, test);
      final threshold = (sampleRows.length / 2).ceil();
      if (curScore >= threshold) return; // current pick already looks right
      int? best = cur;
      var bestScore = curScore;
      for (int i = 0; i < headers.length; i++) {
        final sc = score(i, test);
        if (sc > bestScore) {
          best = i;
          bestScore = sc;
        }
      }
      if (best != null && bestScore > curScore) mapping[field] = best;
    }

    refine('email', _looksLikeEmail);
    refine('phone', _looksLikePhone);
  }

  return mapping;
}

bool _looksLikeEmail(String s) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s.trim());

bool _looksLikePhone(String s) {
  final d = s.trim().replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
  return d.length >= 7 && d.length <= 15 && RegExp(r'^\d+$').hasMatch(d);
}

List<ImportRow> mapRows(
    List<List<String>> rows,
    Map<String, int> mapping,
    ) {
  final out = <ImportRow>[];
  for (final row in rows) {
    String pick(String field) {
      final idx = mapping[field];
      if (idx == null || idx >= row.length) return '';
      return row[idx];
    }

    final firstName = pick('firstName');
    final lastName = pick('lastName');
    final combinedName = pick('fullName');
    final fullName = combinedName.isNotEmpty
        ? combinedName
        : [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    out.add(ImportRow(
      fullName: fullName.trim(),
      phone: pick('phone'),
      email: pick('email'),
      state: pick('state'),
      address: pick('address'),
      dateOfBirth: _normalizeDate(pick('dateOfBirth')),
      occupation: pick('occupation'),
    ));
  }
  return out;
}

String _normalizeDate(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  // Excel date cells (and the excel package's date wrapper) serialise with a
  // time component, e.g. '2026-07-03T00:00:00.000' or '2026-07-03 00:00:00'.
  // Keep only the date part before validating/normalising.
  if (s.contains('T')) s = s.split('T').first.trim();
  if (RegExp(r'\s\d{1,2}:\d{2}').hasMatch(s)) s = s.split(RegExp(r'\s')).first.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
  final m =
  RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$').firstMatch(s);
  if (m != null) {
    final d = m.group(1)!.padLeft(2, '0');
    final mo = m.group(2)!.padLeft(2, '0');
    final y = m.group(3)!;
    return '$y-$mo-$d';
  }
  return s;
}

({List<String> headers, List<List<String>> rows}) parseCsv(String csv) {
  final parsed = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(csv.replaceAll('\r\n', '\n'));

  if (parsed.isEmpty) return (headers: [], rows: []);
  final headers =
  parsed.first.map((c) => c.toString()).toList(growable: false);
  final rows = parsed
      .skip(1)
      .map<List<String>>(
          (r) => r.map((c) => c?.toString() ?? '').toList(growable: false))
      .where((r) => r.any((cell) => cell.trim().isNotEmpty))
      .toList();
  return (headers: headers, rows: rows);
}

({List<String> headers, List<List<String>> rows}) parsePastedTable(
    String pasted) {
  final lines = pasted
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return (headers: [], rows: []);

  final sep = lines.first.contains('\t') ? '\t' : ',';

  final headers = lines.first.split(sep).map((c) => c.trim()).toList();
  final rows = lines.skip(1).map((l) {
    final cells = l.split(sep);
    return List<String>.generate(
      headers.length,
          (i) => i < cells.length ? cells[i].trim() : '',
    );
  }).toList();
  return (headers: headers, rows: rows);
}

({List<String> headers, List<List<String>> rows}) parseExcel(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) return (headers: [], rows: []);
  final sheet = excel.tables.values.first;
  if (sheet.rows.isEmpty) return (headers: [], rows: []);

  String cellToStr(dynamic c) {
    if (c == null) return '';
    final v = c.value;
    if (v == null) return '';
    if (v is DateTime) {
      return '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    return v.toString();
  }

  final headers =
  sheet.rows.first.map(cellToStr).toList(growable: false);
  final rows = sheet.rows
      .skip(1)
      .map<List<String>>((r) => r.map<String>(cellToStr).toList())
      .where((r) => r.any((cell) => cell.trim().isNotEmpty))
      .toList();
  return (headers: headers, rows: rows);
}

String templateCsvContent() {
  return [
    'first_name,last_name,phone,email,state,address,date_of_birth,occupation',
    'John,Adebayo,+2348012345678,john@example.com,Lagos,12 Allen Avenue Ikeja,1990-05-15,Banker',
    'Mary,Okonkwo,+2348098765432,mary@example.com,Abuja,Wuse 2 Plot 88,1985-11-22,Doctor',
    'Chinwe,Eze,+2348023456789,,Enugu,GRA Independence Layout,,Teacher',
  ].join('\n');
}