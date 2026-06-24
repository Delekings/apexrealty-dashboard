// lib/features/properties/presentation/screens/edit_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../providers/properties_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

const _nigerianStates = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
  'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT',
  'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi',
  'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo',
  'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
];

class EditPropertyScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const EditPropertyScreen({super.key, required this.propertyId});

  @override
  ConsumerState<EditPropertyScreen> createState() =>
      _EditPropertyScreenState();
}

class _EditPropertyScreenState extends ConsumerState<EditPropertyScreen> {
  // Basic details
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _lga = TextEditingController();
  final _description = TextEditingController();
  String? _state;

  // Legal / contract details (used by the contract generator)
  final _surveyPlanNo = TextEditingController();
  final _cOfO = TextEditingController();
  final _parcelSize = TextEditingController();
  final _legalDescription = TextEditingController();

  bool _initialized = false;
  bool _submitting = false;
  String? _error;

  void _initFrom(Property p) {
    _title.text = p.title;
    _location.text = p.location;
    _lga.text = p.lga ?? '';
    _description.text = p.description ?? '';
    _state = p.state;
    _surveyPlanNo.text = p.surveyPlanNo ?? '';
    _cOfO.text = p.certificateOfOccupancyNo ?? '';
    _parcelSize.text = p.parentParcelSizeSqm?.toString() ?? '';
    _legalDescription.text = p.fullLegalDescription ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    for (final c in [
      _title, _location, _lga, _description,
      _surveyPlanNo, _cOfO, _parcelSize, _legalDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _state != null &&
      _location.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final sizeText = _parcelSize.text.trim().replaceAll(',', '');
      final patch = <String, dynamic>{
        'title': _title.text.trim(),
        'state': _state,
        'lga': _lga.text.trim().isEmpty ? null : _lga.text.trim(),
        'location': _location.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'survey_plan_no': _surveyPlanNo.text.trim().isEmpty
            ? null
            : _surveyPlanNo.text.trim(),
        'certificate_of_occupancy_no':
            _cOfO.text.trim().isEmpty ? null : _cOfO.text.trim(),
        'parent_parcel_size_sqm':
            sizeText.isEmpty ? null : num.tryParse(sizeText),
        'full_legal_description': _legalDescription.text.trim().isEmpty
            ? null
            : _legalDescription.text.trim(),
      };

      await ref
          .read(propertiesRepoProvider)
          .update(widget.propertyId, patch);

      ref.invalidate(propertyDetailProvider(widget.propertyId));
      ref.invalidate(propertiesPageProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Property "${_title.text.trim()}" updated'),
            backgroundColor: AppColors.brand,
          ),
        );
        context.go('/properties/${widget.propertyId}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyDetailProvider(widget.propertyId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: async.when(
        loading: () => const Center(
            child: LintelLoader()),
        error: (e, _) => Center(
          child: Text("Couldn't load property: $e",
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (p) {
          if (!_initialized) _initFrom(p);
          return _form(context);
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () =>
                  context.go('/properties/${widget.propertyId}'),
            ),
            const SizedBox(width: 4),
            const Text('Edit property',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ----- Property details -----
                    _card(
                      title: 'Property details',
                      children: [
                        _label('Property name *'),
                        TextField(
                          controller: _title,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'e.g. New Touch Estate',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('State *'),
                                  DropdownButtonFormField<String>(
                                    value: _state,
                                    isDense: true,
                                    decoration:
                                        const InputDecoration(isDense: true),
                                    items: [
                                      for (final s in _nigerianStates)
                                        DropdownMenuItem(
                                          value: s,
                                          child: Text(s,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _state = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('LGA'),
                                  TextField(
                                    controller: _lga,
                                    decoration: const InputDecoration(
                                        hintText: 'e.g. Ojo', isDense: true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _label('Address / location *'),
                        TextField(
                          controller: _location,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText:
                                'e.g. Off Volkswagen Bus Stop, Lagos-Badagry Expressway',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label('Description'),
                        TextField(
                          controller: _description,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Brief description of the estate (optional)',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ----- Legal / title details -----
                    _card(
                      title: 'Legal & title details',
                      subtitle:
                          'Used to fill the contract of sale. Leave blank if not yet available.',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Survey plan no.'),
                                  TextField(
                                    controller: _surveyPlanNo,
                                    decoration: const InputDecoration(
                                        hintText: 'e.g. LA/2021/0456',
                                        isDense: true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Certificate of Occupancy no.'),
                                  TextField(
                                    controller: _cOfO,
                                    decoration: const InputDecoration(
                                        hintText: 'e.g. 1234/2019',
                                        isDense: true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _label('Parent parcel size (square metres)'),
                        TextField(
                          controller: _parcelSize,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'e.g. 4000',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label('Full legal description'),
                        TextField(
                          controller: _legalDescription,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'The exact parcel description as it should appear in the contract. '
                                'If left blank, one is generated from the survey plan and location.',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.danger)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => context
                                  .go('/properties/${widget.propertyId}'),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed:
                              (_submitting || !_valid) ? null : _save,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                              _submitting ? 'Saving…' : 'Save changes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required List<Widget> children,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
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
