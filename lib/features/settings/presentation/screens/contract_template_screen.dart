// lib/features/settings/presentation/screens/contract_template_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/contract_templates_repository.dart';
import '../../../../data/services/supabase_service.dart';
import '../../../documents/services/sale_agreement_pdf.dart';

final _templateRepoProvider =
Provider((_) => ContractTemplatesRepository());

final _defaultTemplateProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_templateRepoProvider).getDefault();
});

final _variableCatalogProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_templateRepoProvider).getVariableCatalog();
});

class ContractTemplateScreen extends ConsumerStatefulWidget {
  const ContractTemplateScreen({super.key});

  @override
  ConsumerState<ContractTemplateScreen> createState() =>
      _ContractTemplateScreenState();
}

class _ContractTemplateScreenState
    extends ConsumerState<ContractTemplateScreen> {
  bool _showVariablesPanel = false;
  bool _generatingPreview = false;
  String? _previewError;

  // Edit state
  String? _editingClauseId;
  final _editController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tplAsync = ref.watch(_defaultTemplateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract Template'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Variables',
            onPressed: () =>
                setState(() => _showVariablesPanel = !_showVariablesPanel),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            icon: _generatingPreview
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.picture_as_pdf, size: 16),
            label: Text(_generatingPreview ? 'Generating…' : 'Preview PDF'),
            onPressed: _generatingPreview ? null : _generatePreview,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: _showVariablesPanel ? 7 : 10,
            child: tplAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load template: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (twc) => _buildClauseList(twc),
            ),
          ),
          if (_showVariablesPanel)
            SizedBox(
              width: 360,
              child: _variablesPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildClauseList(TemplateWithClauses twc) {
    final clauses = twc.clauses;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerCard(twc.template),
              const SizedBox(height: 24),
              if (_previewError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_previewError!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger)),
                ),
                const SizedBox(height: 16),
              ],
              for (final c in clauses) _clauseTile(c),
              const SizedBox(height: 24),
              _AppendixSection(template: twc.template),
              const SizedBox(height: 24),
              const _BoilerplateConfigCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(ContractTemplate t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    if (t.description != null)
                      Text(t.description!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Edit clauses below to match your agency\'s wording. Variables like '
                '{{purchaser_name}} are filled in automatically when contracts are generated. '
                'Open the variables panel (icon top-right) to see the full list.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _clauseTile(ContractClause c) {
    final isEditing = _editingClauseId == c.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isEditing ? AppColors.brand : AppColors.border,
            width: isEditing ? 1.0 : 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isEditing
                  ? AppColors.brand.withOpacity(0.06)
                  : AppColors.bg2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                if (c.sectionNumber != null) ...[
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(c.sectionNumber!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(c.sectionTitle,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                if (c.isLocked)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: 'Required clause — body editable, cannot be hidden',
                      child: Icon(Icons.lock_outline,
                          size: 14, color: AppColors.muted),
                    ),
                  ),
                if (c.isHidden && !isEditing)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warnLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('HIDDEN',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.warn,
                            fontWeight: FontWeight.bold)),
                  ),
                if (!isEditing) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: 'Edit',
                    onPressed: () => _beginEdit(c),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 16),
                    onSelected: (v) => _handleClauseAction(c, v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'reset',
                          child: Text('Reset to default',
                              style: TextStyle(fontSize: 12))),
                      if (!c.isLocked)
                        PopupMenuItem(
                            value: 'toggle_hidden',
                            child: Text(c.isHidden ? 'Show' : 'Hide',
                                style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: isEditing ? _editPane(c) : _clauseBodyText(c.bodyMarkdown),
          ),
        ],
      ),
    );
  }

  Widget _editPane(ContractClause c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          minLines: 8,
          style: const TextStyle(
              fontSize: 12, height: 1.5, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Clause body...',
            isDense: true,
            border: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  size: 12, color: AppColors.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Use {{variable_name}} placeholders. Click any variable in the '
                      'panel on the right to copy it to clipboard.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveEdit(c),
              icon: _saving
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 14),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _clauseBodyText(String body) {
    final pattern = RegExp(r'(\{\{\w+\}\})');
    final spans = <TextSpan>[];
    int last = 0;

    for (final m in pattern.allMatches(body)) {
      if (m.start > last) {
        spans.add(TextSpan(text: body.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ));
      last = m.end;
    }
    if (last < body.length) {
      spans.add(TextSpan(text: body.substring(last)));
    }

    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 12,
          height: 1.6,
          color: AppColors.text,
        ),
      ),
    );
  }

  // ============================================================
  // Editing actions
  // ============================================================

  void _beginEdit(ContractClause c) {
    setState(() {
      _editingClauseId = c.id;
      _editController.text = c.bodyMarkdown;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingClauseId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEdit(ContractClause c) async {
    final newBody = _editController.text.trim();
    if (newBody.isEmpty) {
      _toast('Clause body cannot be empty', isError: true);
      return;
    }
    if (newBody == c.bodyMarkdown) {
      _cancelEdit();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save changes to "${c.sectionTitle}"?'),
        content: const Text(
          'This change will apply to all NEW contracts going forward. '
              'Existing contracts in flight will keep using the version they were '
              'sent with.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(_templateRepoProvider).updateClauseBody(
        clauseId: c.id,
        newBody: newBody,
      );
      _toast('Clause updated');
      _cancelEdit();
      ref.invalidate(_defaultTemplateProvider);
    } catch (e) {
      _toast('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleClauseAction(ContractClause c, String action) async {
    switch (action) {
      case 'reset':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset to default?'),
            content: Text(
              'This will replace the body of "${c.sectionTitle}" with the '
                  'system default. Your customizations will be lost.',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Reset')),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await ref.read(_templateRepoProvider).resetClauseToDefault(
            clauseId: c.id,
            sectionKey: c.sectionKey,
          );
          _toast('Reset to default');
          ref.invalidate(_defaultTemplateProvider);
        } catch (e) {
          _toast('Reset failed: $e', isError: true);
        }
        break;

      case 'toggle_hidden':
        try {
          await ref.read(_templateRepoProvider).setClauseHidden(
            clauseId: c.id,
            hidden: !c.isHidden,
          );
          _toast(c.isHidden ? 'Clause shown' : 'Clause hidden');
          ref.invalidate(_defaultTemplateProvider);
        } catch (e) {
          _toast('Failed: $e', isError: true);
        }
        break;
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.brand,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ============================================================
  // Variables panel
  // ============================================================

  Widget _variablesPanel() {
    final varsAsync = ref.watch(_variableCatalogProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(
          left: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Variables',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text(
                        'Click any to copy. Use in clauses with {{token}}.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      setState(() => _showVariablesPanel = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: varsAsync.when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed: $e',
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12)),
              ),
              data: (vars) => _groupedVariablesList(vars),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupedVariablesList(List<TemplateVariable> vars) {
    final groups = <String, List<TemplateVariable>>{};
    for (final v in vars) {
      groups.putIfAbsent(v.category, () => []).add(v);
    }

    const order = [
      'vendor',
      'purchaser',
      'property',
      'contract',
      'payment',
      'witness',
      'lawyer',
      'legal',
      'constant',
    ];
    final orderedKeys = order.where(groups.containsKey).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final key in orderedKeys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              vars.firstWhere((v) => v.category == key).categoryLabel,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.muted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          for (final v in groups[key]!) _variableTile(v),
        ],
      ],
    );
  }

  Widget _variableTile(TemplateVariable v) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: '{{${v.token}}}'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied {{${v.token}}}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.brand,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.displayName,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text('{{${v.token}}}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppColors.brand)),
                  if (v.exampleValue != null && v.exampleValue!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'e.g. ${v.exampleValue}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.content_copy_outlined,
                size: 14, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Preview PDF
  // ============================================================

  Future<void> _generatePreview() async {
    setState(() {
      _generatingPreview = true;
      _previewError = null;
    });

    try {
      final supa = SupabaseService.client;
      final contractRows = await supa
          .from('contracts')
          .select('id, contract_no')
          .order('created_at', ascending: false)
          .limit(1);

      if (contractRows is! List || contractRows.isEmpty) {
        throw Exception(
            'No contracts exist yet — create a contract first to preview.');
      }

      final c = contractRows.first as Map<String, dynamic>;
      final contractId = c['id'] as String;
      final contractNo = c['contract_no'] as String;

      final detail = await supa.from('contracts').select('''
        *, 
        client:clients(*),
        property:properties(*),
        agency:agencies(*)
      ''').eq('id', contractId).single();

      final client = detail['client'] as Map<String, dynamic>;
      final property = detail['property'] as Map<String, dynamic>;
      final agency = detail['agency'] as Map<String, dynamic>;

      final input = SaleAgreementInput(
        contractId: contractId,
        agencyName: agency['name'] as String,
        agencyRcNumber: agency['rc_number'] as String?,
        agencyAddress:
        (agency['registered_address'] ?? agency['address'] ?? '') as String,
        agencySignerName: agency['director_1_name'] as String? ?? 'Director',
        clientFullName: client['full_name'] as String,
        clientAddress: client['address'] as String?,
        clientPhone: client['phone'] as String,
        clientEmail: client['email'] as String?,
        propertyTitle: property['title'] as String,
        propertyLocation: property['location'] as String,
        propertyState: property['state'] as String,
        propertyLga: (property['lga'] as String?) ?? '',
        propertySizeSqm: property['size_sqm'] as num?,
        unitLabel: detail['unit_label'] as String?,
        contractNo: contractNo,
        totalPriceNgn: detail['total_price_ngn'] as num,
        initialDeposit: (detail['initial_deposit_ngn'] as num?) ?? 0,
        paymentPlanLabel: detail['payment_plan'] as String,
        planMonths: detail['plan_months'] as int?,
        startDate: DateTime.parse(detail['start_date'] as String),
        agreementDate: DateTime.now(),
        vendorWitnessName: 'Preview Witness',
      );

      final Uint8List pdfBytes = await SaleAgreementPdf.build(input);

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Template Preview — $contractNo.pdf',
      );
    } catch (e) {
      setState(() =>
      _previewError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generatingPreview = false);
    }
  }
}

// ============================================================
// PIECE 9: Custom appendix section (editable freeform clauses)
// ============================================================

class _AppendixSection extends ConsumerStatefulWidget {
  final ContractTemplate template;
  const _AppendixSection({required this.template});

  @override
  ConsumerState<_AppendixSection> createState() => _AppendixSectionState();
}

class _AppendixSectionState extends ConsumerState<_AppendixSection> {
  bool _editing = false;
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.template.customAppendixText ?? '';
  }

  @override
  void didUpdateWidget(_AppendixSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template.customAppendixText !=
        widget.template.customAppendixText &&
        !_editing) {
      _ctrl.text = widget.template.customAppendixText ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final txt = _ctrl.text.trim();
      await ref.read(_templateRepoProvider).updateAppendix(
        templateId: widget.template.id,
        text: txt.isEmpty ? null : txt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Additional terms updated'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.brand,
      ));
      setState(() => _editing = false);
      ref.invalidate(_defaultTemplateProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = widget.template.customAppendixText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Additional Terms',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Custom clauses appended to the end of every contract. Optional.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (!_editing)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit',
                  onPressed: () => setState(() => _editing = true),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_editing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _ctrl,
                  maxLines: null,
                  minLines: 6,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                  decoration: InputDecoration(
                    hintText:
                    'Type any additional clauses here. Use {{variable_name}} '
                        'tokens if you want them substituted (e.g. {{purchaser_name}}).',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                        setState(() {
                          _editing = false;
                          _ctrl.text = txt ?? '';
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 14),
                      label: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ],
                ),
              ],
            )
          else if (txt == null || txt.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'No additional terms set. Click edit to add custom clauses.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(txt,
                  style: const TextStyle(fontSize: 12, height: 1.6)),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PIECE 9: Agency boilerplate config card
// (refund %, transfer fee %, construction deadline, etc.)
// ============================================================

class _BoilerplateConfigCard extends ConsumerStatefulWidget {
  const _BoilerplateConfigCard();

  @override
  ConsumerState<_BoilerplateConfigCard> createState() =>
      _BoilerplateConfigCardState();
}

class _BoilerplateConfigCardState
    extends ConsumerState<_BoilerplateConfigCard> {
  Map<String, dynamic>? _agency;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Controllers
  final _refundPctCtrl = TextEditingController();
  final _transferFeePctCtrl = TextEditingController();
  final _constructionYearsCtrl = TextEditingController();
  final _gracePeriodDaysCtrl = TextEditingController();
  final _governingLawCtrl = TextEditingController();
  final _disputeBodyCtrl = TextEditingController();
  final _paymentWindowCtrl = TextEditingController();

  final _rcNumberCtrl = TextEditingController();
  final _registeredAddrCtrl = TextEditingController();
  final _headOfficeAddrCtrl = TextEditingController();
  final _director1Ctrl = TextEditingController();
  final _director2Ctrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _agencyEmailCtrl = TextEditingController();

  final _lawyerNameCtrl = TextEditingController();
  final _lawyerFirmCtrl = TextEditingController();
  final _lawyerAddrCtrl = TextEditingController();
  final _lawyerEmailCtrl = TextEditingController();
  final _lawyerPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _refundPctCtrl,
      _transferFeePctCtrl,
      _constructionYearsCtrl,
      _gracePeriodDaysCtrl,
      _governingLawCtrl,
      _disputeBodyCtrl,
      _paymentWindowCtrl,
      _rcNumberCtrl,
      _registeredAddrCtrl,
      _headOfficeAddrCtrl,
      _director1Ctrl,
      _director2Ctrl,
      _websiteCtrl,
      _agencyEmailCtrl,
      _lawyerNameCtrl,
      _lawyerFirmCtrl,
      _lawyerAddrCtrl,
      _lawyerEmailCtrl,
      _lawyerPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final supa = SupabaseService.client;
      final row = await supa
          .from('agencies')
          .select()
          .eq('id', (await _myAgencyId()))
          .single();
      setState(() {
        _agency = row;
        _populateControllers(row);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _myAgencyId() async {
    final supa = SupabaseService.client;
    final r = await supa
        .from('profiles')
        .select('agency_id')
        .eq('id', supa.auth.currentUser!.id)
        .single();
    return r['agency_id'] as String;
  }

  void _populateControllers(Map<String, dynamic> a) {
    _refundPctCtrl.text = (a['default_refund_admin_pct'] ?? 30).toString();
    _transferFeePctCtrl.text =
        (a['default_transfer_processing_fee_pct'] ?? 10).toString();
    _constructionYearsCtrl.text =
        (a['default_construction_deadline_years'] ?? 2).toString();
    _gracePeriodDaysCtrl.text =
        (a['default_grace_period_days'] ?? 30).toString();
    _governingLawCtrl.text =
        (a['default_governing_law'] ?? 'Federal Republic of Nigeria')
            .toString();
    _disputeBodyCtrl.text =
        (a['default_dispute_resolution_body'] ?? 'Lagos Multi-Door Courthouse')
            .toString();
    _paymentWindowCtrl.text = (a['default_payment_window_phrase'] ??
        'on or before the last working day of every successive month')
        .toString();
    _rcNumberCtrl.text = (a['rc_number'] ?? '').toString();
    _registeredAddrCtrl.text = (a['registered_address'] ?? '').toString();
    _headOfficeAddrCtrl.text = (a['head_office_address'] ?? '').toString();
    _director1Ctrl.text = (a['director_1_name'] ?? '').toString();
    _director2Ctrl.text = (a['director_2_name'] ?? '').toString();
    _websiteCtrl.text = (a['website'] ?? '').toString();
    _agencyEmailCtrl.text = (a['email'] ?? '').toString();
    _lawyerNameCtrl.text = (a['lawyer_name'] ?? '').toString();
    _lawyerFirmCtrl.text = (a['lawyer_firm'] ?? '').toString();
    _lawyerAddrCtrl.text = (a['lawyer_address'] ?? '').toString();
    _lawyerEmailCtrl.text = (a['lawyer_email'] ?? '').toString();
    _lawyerPhoneCtrl.text = (a['lawyer_phone'] ?? '').toString();
  }

  Future<void> _save() async {
    if (_agency == null) return;
    setState(() => _saving = true);
    try {
      final supa = SupabaseService.client;
      await supa.from('agencies').update({
        'default_refund_admin_pct': num.tryParse(_refundPctCtrl.text) ?? 30,
        'default_transfer_processing_fee_pct':
        num.tryParse(_transferFeePctCtrl.text) ?? 10,
        'default_construction_deadline_years':
        int.tryParse(_constructionYearsCtrl.text) ?? 2,
        'default_grace_period_days':
        int.tryParse(_gracePeriodDaysCtrl.text) ?? 30,
        'default_governing_law': _governingLawCtrl.text.trim(),
        'default_dispute_resolution_body': _disputeBodyCtrl.text.trim(),
        'default_payment_window_phrase': _paymentWindowCtrl.text.trim(),
        'rc_number': _emptyAsNull(_rcNumberCtrl.text),
        'registered_address': _emptyAsNull(_registeredAddrCtrl.text),
        'head_office_address': _emptyAsNull(_headOfficeAddrCtrl.text),
        'director_1_name': _emptyAsNull(_director1Ctrl.text),
        'director_2_name': _emptyAsNull(_director2Ctrl.text),
        'website': _emptyAsNull(_websiteCtrl.text),
        'email': _emptyAsNull(_agencyEmailCtrl.text),
        'lawyer_name': _emptyAsNull(_lawyerNameCtrl.text),
        'lawyer_firm': _emptyAsNull(_lawyerFirmCtrl.text),
        'lawyer_address': _emptyAsNull(_lawyerAddrCtrl.text),
        'lawyer_email': _emptyAsNull(_lawyerEmailCtrl.text),
        'lawyer_phone': _emptyAsNull(_lawyerPhoneCtrl.text),
      }).eq('id', _agency!['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Agency details saved'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.brand,
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyAsNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Failed to load agency: $_error',
            style: const TextStyle(color: AppColors.danger, fontSize: 12)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agency details for contract templates',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text(
            'These values fill in the variables used throughout your contracts. '
                'Empty fields will appear as placeholders like "[lawyer_name not set]".',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Company details'),
          _field('RC Number', _rcNumberCtrl, hint: 'e.g. 1234567'),
          _field('Registered address', _registeredAddrCtrl, hint: 'CAC-registered office', multiline: true),
          _field('Head office address', _headOfficeAddrCtrl, hint: 'Operations address', multiline: true),
          _field('Website', _websiteCtrl, hint: 'e.g. www.youragency.com'),
          _field('Agency email', _agencyEmailCtrl, hint: 'hello@youragency.com'),

          const SizedBox(height: 16),
          _sectionTitle('Directors (for signature page)'),
          _field('Director 1 name', _director1Ctrl),
          _field('Director 2 name', _director2Ctrl),

          const SizedBox(height: 16),
          _sectionTitle('Lawyer / preparing attorney'),
          _field('Lawyer name', _lawyerNameCtrl, hint: 'e.g. John Doe Esq.'),
          _field('Law firm', _lawyerFirmCtrl),
          _field('Lawyer address', _lawyerAddrCtrl, multiline: true),
          _field('Lawyer email', _lawyerEmailCtrl),
          _field('Lawyer phone', _lawyerPhoneCtrl),

          const SizedBox(height: 16),
          _sectionTitle('Default contract terms'),
          Row(
            children: [
              Expanded(
                child: _field('Refund admin charge (%)', _refundPctCtrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Transfer processing fee (%)', _transferFeePctCtrl),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _field('Construction deadline (years)', _constructionYearsCtrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Grace period (days)', _gracePeriodDaysCtrl),
              ),
            ],
          ),
          _field('Governing law', _governingLawCtrl),
          _field('Dispute resolution body', _disputeBodyCtrl),
          _field('Payment window phrase', _paymentWindowCtrl, multiline: true),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 14),
                label: Text(_saving ? 'Saving…' : 'Save agency details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.muted,
          letterSpacing: 0.8),
    ),
  );

  Widget _field(String label, TextEditingController c,
      {String? hint, bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 3),
          TextField(
            controller: c,
            maxLines: multiline ? null : 1,
            minLines: multiline ? 2 : 1,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}