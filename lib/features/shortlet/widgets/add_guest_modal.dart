// lib/features/shortlet/widgets/add_guest_modal.dart
//
// Inline modal for quickly adding a new client (guest) during the
// booking flow. Reuses the existing clientsRepo.create() method.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/clients_repository.dart';
import '../../auth/providers/auth_providers.dart';

class AddGuestModal extends ConsumerStatefulWidget {
  const AddGuestModal({super.key});

  @override
  ConsumerState<AddGuestModal> createState() => _AddGuestModalState();
}

class _AddGuestModalState extends ConsumerState<AddGuestModal> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Full name and phone are required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentProfileProvider).value;
      if (profile?.agencyId == null) {
        throw Exception('No agency on profile');
      }
      final repo = ClientsRepository();
      final id = await repo.create(
        agencyId: profile!.agencyId!,
        fullName: name,
        phone: phone,
        email: email.isEmpty ? null : email,
      );
      if (!mounted) return;
      Navigator.pop(context, _NewGuestResult(
        id: id,
        fullName: name,
        phone: phone,
        email: email.isEmpty ? null : email,
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Add new guest',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed:
                    _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Saves to your client list. You can fill in more details later.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  hintText: '+234 800 000 0000',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  isDense: true,
                ),
                onSubmitted: (_) => _save(),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                    _saving ? null : () => Navigator.pop(context),
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
                        : const Icon(Icons.person_add, size: 14),
                    label: Text(_saving ? 'Saving…' : 'Add guest'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returned from the modal when a new guest is created.
class _NewGuestResult {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  _NewGuestResult({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
  });
}

class NewGuestResult {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  NewGuestResult({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
  });
}

/// Public API: show the modal, get a guest back (or null if cancelled).
Future<NewGuestResult?> showAddGuestModal(BuildContext context) async {
  final result = await showDialog<_NewGuestResult>(
    context: context,
    builder: (_) => const AddGuestModal(),
  );
  if (result == null) return null;
  return NewGuestResult(
    id: result.id,
    fullName: result.fullName,
    phone: result.phone,
    email: result.email,
  );
}