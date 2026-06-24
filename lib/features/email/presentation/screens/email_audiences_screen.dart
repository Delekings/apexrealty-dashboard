// lib/features/email/presentation/screens/email_audiences_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_audiences_repository.dart';
import '../../../../data/repositories/email_repository.dart';
import '../../providers/email_audiences_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

final _audEmailRepoProvider = Provider((_) => EmailRepository());

/// Distinct states clients have set — reused for the by-state chips.
final _audClientStatesProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_audEmailRepoProvider).getClientStates();
});

class EmailAudiencesScreen extends ConsumerWidget {
  const EmailAudiencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(emailAudiencesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/email/campaigns'),
        ),
        title: const Text('Audiences'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New audience'),
            onPressed: () => _openEditor(context, ref),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: LintelLoader()),
        error: (e, _) => Center(
          child: Text('Failed to load audiences: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (audiences) => audiences.isEmpty
            ? _empty(context, ref)
            : _list(context, ref, audiences),
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('No saved audiences yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Save a reusable group of recipients — pick it later when sending a campaign.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New audience'),
              onPressed: () => _openEditor(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
      BuildContext context, WidgetRef ref, List<EmailAudience> audiences) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: audiences.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final a = audiences[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child:
                    Icon(Icons.groups_outlined, size: 18, color: AppColors.brand),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(a.filterLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    if (a.description != null &&
                        a.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(a.description!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.text)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                onPressed: () => _openEditor(context, ref, existing: a),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: () => _confirmDelete(context, ref, a),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {EmailAudience? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AudienceEditorDialog(existing: existing),
    );
    if (saved == true) ref.invalidate(emailAudiencesProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, EmailAudience a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete audience?'),
        content: Text(
            '"${a.name}" will be removed. Campaigns already sent are unaffected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(emailAudiencesRepoProvider).delete(a.id);
      ref.invalidate(emailAudiencesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${a.name}"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Create / edit dialog
// ---------------------------------------------------------------------------

class _AudienceEditorDialog extends ConsumerStatefulWidget {
  final EmailAudience? existing;
  const _AudienceEditorDialog({this.existing});

  @override
  ConsumerState<_AudienceEditorDialog> createState() =>
      _AudienceEditorDialogState();
}

class _AudienceEditorDialogState
    extends ConsumerState<_AudienceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  String _filterType = 'all';
  final Set<String> _selectedStates = {};

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    if (e != null) {
      _filterType = e.filterType;
      final states = (e.filter['states'] as List?)?.cast<String>() ?? const [];
      _selectedStates.addAll(states);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFilter() {
    switch (_filterType) {
      case 'by_state':
        return {'type': 'by_state', 'states': _selectedStates.toList()};
      case 'has_active_contract':
        return {'type': 'has_active_contract'};
      case 'has_overdue':
        return {'type': 'has_overdue'};
      case 'all':
      default:
        return {'type': 'all'};
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the audience a name');
      return;
    }
    if (_filterType == 'by_state' && _selectedStates.isEmpty) {
      setState(() => _error = 'Pick at least one state');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(emailAudiencesRepoProvider);
      final filter = _buildFilter();
      if (widget.existing == null) {
        await repo.create(
          name: _name.text,
          description: _description.text,
          filter: filter,
        );
      } else {
        await repo.update(
          widget.existing!.id,
          name: _name.text,
          description: _description.text,
          filter: filter,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(_audClientStatesProvider);
    final editing = widget.existing != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(editing ? 'Edit audience' : 'New audience',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Name *'),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Lagos buyers with overdue payments',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Description'),
                    TextField(
                      controller: _description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Optional note about who this targets',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recipients *',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          _radioOption('all', 'All clients with an email'),
                          _radioOption('has_active_contract',
                              'Clients with an active contract'),
                          _radioOption('has_overdue',
                              'Clients with overdue installments'),
                          _radioOption(
                              'by_state', 'Clients in specific state(s)'),
                          if (_filterType == 'by_state') ...[
                            const SizedBox(height: 8),
                            statesAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: LinearProgressIndicator(),
                              ),
                              error: (e, _) => Text(
                                  'Could not load states: $e',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.danger)),
                              data: (states) {
                                if (states.isEmpty) {
                                  return const Text(
                                    'No clients have a state set.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted),
                                  );
                                }
                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final s in states)
                                      FilterChip(
                                        label: Text(s,
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        selected:
                                            _selectedStates.contains(s),
                                        onSelected: (sel) {
                                          setState(() {
                                            if (sel) {
                                              _selectedStates.add(s);
                                            } else {
                                              _selectedStates.remove(s);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.danger)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: Text(_saving
                        ? 'Saving…'
                        : (editing ? 'Save' : 'Create audience')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioOption(String value, String label) {
    return InkWell(
      onTap: () => setState(() => _filterType = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _filterType,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) {
                if (v != null) setState(() => _filterType = v);
              },
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500)),
      );
}
