// lib/features/clients/presentation/screens/import_clients_screen.dart
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/clients_repository.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/client_tags_providers.dart';
import '../widgets/tag_picker.dart';
import '../../services/import_parser.dart';

final _clientsRepoProvider = Provider((_) => ClientsRepository());

class ImportClientsScreen extends ConsumerStatefulWidget {
  const ImportClientsScreen({super.key});

  @override
  ConsumerState<ImportClientsScreen> createState() =>
      _ImportClientsScreenState();
}

class _ImportClientsScreenState extends ConsumerState<ImportClientsScreen> {
  // Parsing state
  List<String> _headers = [];
  List<List<String>> _rawRows = [];

  // Tags applied to the whole imported batch (2A).
  Set<String> _batchTagIds = {};
  Map<String, int> _mapping = {};

  // Editable state
  List<ImportRow> _rows = [];

  // Import state
  bool _importing = false;
  int _importDone = 0;
  int _importTotal = 0;
  List<ClientImportResultRow>? _results;
  String? _parseError;

  // Paste textarea
  final _pasteCtrl = TextEditingController();

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  // ---------- Source handlers ----------

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    if (f.bytes == null) {
      setState(() => _parseError = 'Could not read file');
      return;
    }
    try {
      if (f.extension == 'csv') {
        final parsed = parseCsv(utf8.decode(f.bytes!));
        _onParsed(parsed.headers, parsed.rows);
      } else {
        final parsed = parseExcel(f.bytes!);
        _onParsed(parsed.headers, parsed.rows);
      }
    } catch (e) {
      setState(() => _parseError = 'Failed to parse file: $e');
    }
  }

  void _parsePasted() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      final parsed = parsePastedTable(text);
      _onParsed(parsed.headers, parsed.rows);
    } catch (e) {
      setState(() => _parseError = 'Failed to parse pasted data: $e');
    }
  }

  void _onParsed(List<String> headers, List<List<String>> rows) {
    if (headers.isEmpty || rows.isEmpty) {
      setState(() => _parseError =
      'No data found. Make sure the first row has column headers.');
      return;
    }
    setState(() {
      _parseError = null;
      _headers = headers;
      _rawRows = rows;
      _mapping = autoDetectColumns(headers, rows);
      _rows = mapRows(rows, _mapping);
      _results = null;
    });
  }

  Future<void> _downloadTemplate() async {
    await Clipboard.setData(ClipboardData(text: templateCsvContent()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Template CSV copied to clipboard. Paste it into Excel/Sheets.')));
  }

  // ---------- Import ----------

  Future<void> _import() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No valid rows to import. Fix errors first.')));
      return;
    }

    setState(() {
      _importing = true;
      _importTotal = validRows.length;
      _importDone = 0;
    });
    try {
      final res = await ref
          .read(_clientsRepoProvider)
          .bulkImportChunked(
            validRows.map((r) => r.toRpcMap()).toList(),
            onProgress: (done, total) {
              if (mounted) {
                setState(() {
                  _importDone = done;
                  _importTotal = total;
                });
              }
            },
          );
      setState(() => _results = res);

      // Apply the batch tags to every successfully inserted client (2A).
      if (_batchTagIds.isNotEmpty) {
        final insertedIds = res
            .where((r) => r.isSuccess && r.clientId != null)
            .map((r) => r.clientId!)
            .toList();
        final profile = ref.read(currentProfileProvider).value;
        if (insertedIds.isNotEmpty && profile?.agencyId != null) {
          await ref.read(clientTagsRepoProvider).assignTagsToClients(
                agencyId: profile!.agencyId!,
                clientIds: insertedIds,
                tagIds: _batchTagIds.toList(),
              );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _reset() {
    setState(() {
      _headers = [];
      _rawRows = [];
      _mapping = {};
      _rows = [];
      _results = null;
      _parseError = null;
      _pasteCtrl.clear();
    });
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 18),
                    onPressed: _importing ? null : () => context.go('/clients'),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Import clients',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Bring in your existing client list from a CSV, Excel file, or by pasting from a spreadsheet.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (_results != null)
                _resultsView()
              else if (_rows.isEmpty)
                _sourcePicker()
              else
                _editGrid(),
            ],
          ),
        ),
        if (_importing) _importOverlay(),
      ],
    );
  }

  Widget _importOverlay() {
    final total = _importTotal == 0 ? 1 : _importTotal;
    final frac = (_importDone / total).clamp(0.0, 1.0);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.center,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Importing clients…',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '$_importDone of $_importTotal added',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 10,
                  backgroundColor: AppColors.brand.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please keep this window open until it finishes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourcePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Option 1 — Upload a file',
                  style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text(
                  'CSV (.csv) or Excel (.xlsx, .xls). First row should be column headers.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Choose file'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Copy template CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Option 2 — Paste from spreadsheet',
                  style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text(
                  'Select rows in Excel/Google Sheets, copy, then paste below. Include the header row.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: _pasteCtrl,
                maxLines: 6,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText:
                  'first_name\tlast_name\tphone\temail\n...paste here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _parsePasted,
                icon: const Icon(Icons.table_view, size: 16),
                label: const Text('Parse pasted data'),
              ),
            ],
          ),
        ),
        if (_parseError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_parseError!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ),
        ],
      ],
    );
  }

  Widget _editGrid() {
    final validCount = _rows.where((r) => r.isValid).length;
    final errorCount = _rows.length - validCount;
    final unmappedRequired = !_mapping.containsKey('fullName') &&
        !(_mapping.containsKey('firstName') &&
            _mapping.containsKey('lastName'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.table_chart, size: 16, color: AppColors.brand),
              const SizedBox(width: 8),
              Text('${_rows.length} rows parsed',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              if (validCount > 0)
                _badge('$validCount ready', AppColors.brand),
              if (errorCount > 0) ...[
                const SizedBox(width: 6),
                _badge('$errorCount with errors', AppColors.danger),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Start over'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _columnMapper(),
        if (unmappedRequired) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warnLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: AppColors.warn),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "We couldn't detect a name column. Edit the 'Full name' cells manually below.",
                    style: TextStyle(fontSize: 12, color: AppColors.warn),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // The grid
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 56,
              headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Full name *')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('State')),
                DataColumn(label: Text('Address')),
                DataColumn(label: Text('DOB (YYYY-MM-DD)')),
                DataColumn(label: Text('Occupation')),
              ],
              rows: [
                for (int i = 0; i < _rows.length; i++) _buildRow(i),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.brandLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tag this batch (optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Any tags you pick here are applied to every client in this '
                'import — handy for grouping them for future campaigns.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TagPicker(
                selectedTagIds: _batchTagIds,
                onChanged: (ids) => setState(() => _batchTagIds = ids),
                label: 'Apply to all imported clients',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _importing ? null : _reset,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: (_importing || validCount == 0) ? null : _import,
              icon: _importing
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: Text(_importing
                  ? 'Importing…'
                  : 'Import $validCount client${validCount == 1 ? '' : 's'}'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _columnMapper() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.swap_horiz, size: 15, color: AppColors.brand),
              SizedBox(width: 6),
              Text('Match your columns',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'We guessed these from your file. If a column is wrong, pick the '
            'right one — the preview updates instantly.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _mapField('Full name', 'fullName'),
              _mapField('First name', 'firstName'),
              _mapField('Last name', 'lastName'),
              _mapField('Phone', 'phone'),
              _mapField('Email', 'email'),
              _mapField('State', 'state'),
              _mapField('Address', 'address'),
              _mapField('Date of birth', 'dateOfBirth'),
              _mapField('Occupation', 'occupation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapField(String label, String key) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          DropdownButtonFormField<int?>(
            value: _mapping[key],
            isExpanded: true,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('— Not mapped —',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              for (int i = 0; i < _headers.length; i++)
                DropdownMenuItem<int?>(
                  value: i,
                  child: Text(
                    _headers[i].trim().isEmpty
                        ? 'Column ${i + 1}'
                        : _headers[i].trim(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            onChanged: (v) => _setMapping(key, v),
          ),
        ],
      ),
    );
  }

  void _setMapping(String field, int? idx) {
    setState(() {
      if (idx == null) {
        _mapping.remove(field);
      } else {
        _mapping[field] = idx;
      }
      _rows = mapRows(_rawRows, _mapping);
    });
  }

  DataRow _buildRow(int idx) {
    final row = _rows[idx];
    final validation = row.validate();

    return DataRow(cells: [
      DataCell(Text('${idx + 1}',
          style: const TextStyle(
              fontSize: 11, color: AppColors.muted))),
      _editCell(
        value: row.fullName,
        error: validation['fullName'],
        onChanged: (v) => setState(() => row.fullName = v),
      ),
      _editCell(
        value: row.phone,
        error: validation['phone'],
        onChanged: (v) => setState(() => row.phone = v),
      ),
      _editCell(
        value: row.email,
        error: validation['email'],
        onChanged: (v) => setState(() => row.email = v),
      ),
      _editCell(
        value: row.state,
        onChanged: (v) => setState(() => row.state = v),
      ),
      _editCell(
        value: row.address,
        onChanged: (v) => setState(() => row.address = v),
      ),
      _editCell(
        value: row.dateOfBirth,
        error: validation['dateOfBirth'],
        onChanged: (v) => setState(() => row.dateOfBirth = v),
      ),
      _editCell(
        value: row.occupation,
        onChanged: (v) => setState(() => row.occupation = v),
      ),
    ]);
  }

  DataCell _editCell({
    required String value,
    required ValueChanged<String> onChanged,
    String? error,
  }) {
    return DataCell(
      Tooltip(
        message: error ?? '',
        child: SizedBox(
          width: 140,
          child: TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(offset: value.length),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              filled: error != null,
              fillColor: error != null ? AppColors.dangerLight : null,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  // ---------- Results view ----------

  Widget _resultsView() {
    final results = _results!;
    final inserted = results.where((r) => r.isSuccess).length;
    final duplicates = results.where((r) => r.isDuplicate).length;
    final errors = results.where((r) => r.isError).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.brand, size: 40),
                const SizedBox(height: 8),
                Text('$inserted clients imported',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${results.length} rows processed · $duplicates duplicates · $errors errors',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (duplicates > 0 || errors > 0) ...[
          const Text('Skipped rows:',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ...results.where((r) => !r.isSuccess).map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  r.isDuplicate ? Icons.copy_all : Icons.error_outline,
                  size: 14,
                  color: r.isDuplicate
                      ? AppColors.warn
                      : AppColors.danger,
                ),
                const SizedBox(width: 8),
                Text('Row ${r.rowIndex + 1}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.message ?? r.status,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _reset,
              child: const Text('Import more'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => context.go('/clients'),
              child: const Text('Go to Clients'),
            ),
          ],
        ),
      ],
    );
  }
}
