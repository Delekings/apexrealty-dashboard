// lib/features/clients/presentation/screens/onboard_client_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/clients_providers.dart';

const _nigerianStates = [
  'Abia','Adamawa','Akwa Ibom','Anambra','Bauchi','Bayelsa','Benue','Borno',
  'Cross River','Delta','Ebonyi','Edo','Ekiti','Enugu','FCT','Gombe','Imo',
  'Jigawa','Kaduna','Kano','Katsina','Kebbi','Kogi','Kwara','Lagos','Nasarawa',
  'Niger','Ogun','Ondo','Osun','Oyo','Plateau','Rivers','Sokoto','Taraba',
  'Yobe','Zamfara',
];

class OnboardClientScreen extends ConsumerStatefulWidget {
  const OnboardClientScreen({super.key});

  @override
  ConsumerState<OnboardClientScreen> createState() => _OnboardClientScreenState();
}

class _OnboardClientScreenState extends ConsumerState<OnboardClientScreen> {
  int _step = 0;
  bool _submitting = false;
  String? _error;

  // Step 1 — Basic info
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _state;
  final _occupation = TextEditingController();
  final _address = TextEditingController();
  String? _assignedAgentId;

  // Step 2 — KYC
  final _bvn = TextEditingController();
  final _nin = TextEditingController();

  // Step 3 — Next of kin
  final _nokName = TextEditingController();
  final _nokPhone = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _fullName, _phone, _email, _occupation, _address,
      _bvn, _nin, _nokName, _nokPhone, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _step1Valid =>
      _fullName.text.trim().isNotEmpty && _phone.text.trim().length >= 10;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on your profile. Contact your admin.');
      }

      final repo = ref.read(clientsRepoProvider);
      final newId = await repo.create(
        agencyId: profile!.agencyId!,
        fullName: _fullName.text,
        phone: _phone.text,
        email: _email.text,
        state: _state,
        occupation: _occupation.text,
        address: _address.text,
        assignedAgentId: _assignedAgentId,
        bvn: _bvn.text,
        nin: _nin.text,
        nextOfKinName: _nokName.text,
        nextOfKinPhone: _nokPhone.text,
        notes: _notes.text,
      );

      // Bust the clients list cache so the new row appears
      ref.invalidate(clientsPageProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_fullName.text} onboarded successfully'),
            backgroundColor: AppColors.brand,
          ),
        );
        context.go('/clients/$newId');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => context.go('/clients'),
              ),
              const SizedBox(width: 4),
              const Text('Onboard Client',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),

          // Stepper indicator
          _StepperBar(currentStep: _step),
          const SizedBox(height: 16),

          // Form card
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: switch (_step) {
                        0 => _Step1Basic(state: this),
                        1 => _Step2Kyc(state: this),
                        _ => _Step3Nok(state: this),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          ],

          const SizedBox(height: 12),

          // Footer actions
          Row(
            children: [
              if (_step > 0)
                TextButton(
                  onPressed: _submitting ? null : () => setState(() => _step--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (_step < 2)
                FilledButton(
                  onPressed: _step1Valid || _step > 0
                      ? () => setState(() => _step++)
                      : null,
                  child: const Text('Continue'),
                )
              else
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(_submitting ? 'Onboarding…' : 'Onboard client'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperBar extends StatelessWidget {
  final int currentStep;
  const _StepperBar({required this.currentStep});

  static const _labels = ['Basic info', 'KYC', 'Next of kin'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: i <= currentStep ? AppColors.brand : AppColors.bg2,
              shape: BoxShape.circle,
              border: Border.all(
                color: i <= currentStep ? AppColors.brand : AppColors.border,
              ),
            ),
            alignment: Alignment.center,
            child: i < currentStep
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: i <= currentStep ? Colors.white : AppColors.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            _labels[i],
            style: TextStyle(
              fontSize: 13,
              color: i <= currentStep ? AppColors.text : AppColors.muted,
              fontWeight: i == currentStep ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          if (i < _labels.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                height: 1,
                color: i < currentStep ? AppColors.brand : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _Step1Basic extends ConsumerWidget {
  final _OnboardClientScreenState state;
  const _Step1Basic({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Basic information',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Name and phone are required — the rest you can fill in later.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),

        _Field(
          label: 'Full name *',
          controller: state._fullName,
          hint: 'e.g. Chukwuemeka Adebayo',
          onChanged: (_) => state.setState(() {}),
        ),
        _TwoCol(
          left: _Field(
            label: 'Phone *',
            controller: state._phone,
            hint: '080X XXX XXXX',
            keyboardType: TextInputType.phone,
            onChanged: (_) => state.setState(() {}),
          ),
          right: _Field(
            label: 'Email',
            controller: state._email,
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        _TwoCol(
          left: _DropdownField(
            label: 'State',
            value: state._state,
            items: _nigerianStates,
            onChanged: (v) => state.setState(() => state._state = v),
          ),
          right: _Field(
            label: 'Occupation',
            controller: state._occupation,
            hint: 'e.g. Software engineer',
          ),
        ),
        _Field(
          label: 'Address',
          controller: state._address,
          hint: 'Street, city',
          maxLines: 2,
        ),
        agentsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (agents) => _DropdownField<String>(
            label: 'Assigned agent',
            value: state._assignedAgentId,
            items: agents.map((a) => a.id).toList(),
            itemLabel: (id) {
              final a = agents.firstWhere(
                (a) => a.id == id,
                orElse: () => Profile(
                    id: '', agencyId: null, fullName: '—', role: UserRole.agent),
              );
              return a.fullName;
            },
            onChanged: (v) => state.setState(() => state._assignedAgentId = v),
          ),
        ),
      ],
    );
  }
}

class _Step2Kyc extends StatelessWidget {
  final _OnboardClientScreenState state;
  const _Step2Kyc({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Identity verification',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Optional but recommended. BVN and NIN are stored encrypted.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        _Field(
          label: 'BVN',
          controller: state._bvn,
          hint: '11-digit Bank Verification Number',
          keyboardType: TextInputType.number,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _Field(
          label: 'NIN',
          controller: state._nin,
          hint: '11-digit National Identity Number',
          keyboardType: TextInputType.number,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can upload ID documents (passport, utility bill, etc.) '
                  'from the client detail page after onboarding.',
                  style: TextStyle(fontSize: 12, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step3Nok extends StatelessWidget {
  final _OnboardClientScreenState state;
  const _Step3Nok({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Next of kin',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Useful for emergency contact and to satisfy SEC/EFCC documentation '
          'requirements on high-value transactions.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        _TwoCol(
          left: _Field(
            label: 'Name',
            controller: state._nokName,
            hint: 'Full name',
          ),
          right: _Field(
            label: 'Phone',
            controller: state._nokPhone,
            hint: '080X XXX XXXX',
            keyboardType: TextInputType.phone,
          ),
        ),
        _Field(
          label: 'Notes (internal)',
          controller: state._notes,
          hint: 'Anything your team should know about this client',
          maxLines: 3,
        ),
      ],
    );
  }
}

// --- Reusable form bits ---

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T)? itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            value: value,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final v in items)
                DropdownMenuItem<T>(
                  value: v,
                  child: Text(itemLabel != null ? itemLabel!(v) : v.toString(),
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 560;
    if (!wide) {
      return Column(children: [left, right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}
