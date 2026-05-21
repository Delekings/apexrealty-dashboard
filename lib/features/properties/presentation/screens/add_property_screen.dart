// lib/features/properties/presentation/screens/add_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/photo_picker.dart';
import '../../../../data/models/models.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/properties_providers.dart';

const _nigerianStates = [
  'Abia','Adamawa','Akwa Ibom','Anambra','Bauchi','Bayelsa','Benue','Borno',
  'Cross River','Delta','Ebonyi','Edo','Ekiti','Enugu','FCT','Gombe','Imo',
  'Jigawa','Kaduna','Kano','Katsina','Kebbi','Kogi','Kwara','Lagos','Nasarawa',
  'Niger','Ogun','Ondo','Osun','Oyo','Plateau','Rivers','Sokoto','Taraba',
  'Yobe','Zamfara',
];

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  bool _submitting = false;
  String? _error;

  final _title = TextEditingController();
  PropertyType _type = PropertyType.land;
  final _location = TextEditingController();
  String? _state;
  final _lga = TextEditingController();
  final _size = TextEditingController();
  final _basePrice = TextEditingController();
  final _totalUnits = TextEditingController(text: '1');
  final _description = TextEditingController();

  List<PickedPhoto> _photos = [];

  @override
  void dispose() {
    for (final c in [
      _title, _location, _lga, _size, _basePrice, _totalUnits, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_title.text.trim().isEmpty) return false;
    if (_location.text.trim().isEmpty) return false;
    if (_state == null) return false;
    final price = num.tryParse(_basePrice.text.replaceAll(',', ''));
    if (price == null || price <= 0) return false;
    final units = int.tryParse(_totalUnits.text);
    if (units == null || units < 1) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on your profile.');
      }

      final repo = ref.read(propertiesRepoProvider);

      final id = await repo.create(
        agencyId: profile!.agencyId!,
        title: _title.text,
        type: _type,
        location: _location.text,
        state: _state!,
        lga: _lga.text,
        sizeSqm: num.tryParse(_size.text),
        basePrice: num.parse(_basePrice.text.replaceAll(',', '')),
        totalUnits: int.parse(_totalUnits.text),
        description: _description.text,
      );

      // Upload photos if any
      if (_photos.isNotEmpty) {
        await repo.uploadPhotos(
          agencyId: profile.agencyId!,
          propertyId: id,
          files: _photos
              .map((p) => (bytes: p.bytes, filename: p.filename))
              .toList(),
        );
      }

      ref.invalidate(propertiesPageProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${_title.text}" added to your inventory'),
            backgroundColor: AppColors.brand,
          ),
        );
        context.go('/properties/$id');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => context.go('/properties'),
              ),
              const SizedBox(width: 4),
              const Text('Add Property',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section: Basic info
                          const _SectionTitle('Basic information'),
                          const SizedBox(height: 12),
                          _field(
                            label: 'Title *',
                            controller: _title,
                            hint: 'e.g. Lekki Garden Estate, Phase 4',
                            onChanged: (_) => setState(() {}),
                          ),
                          _twoCol(
                            left: _typeDropdown(),
                            right: _field(
                              label: 'Size (sqm)',
                              controller: _size,
                              hint: 'e.g. 500',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const _SectionTitle('Location'),
                          const SizedBox(height: 12),
                          _field(
                            label: 'Address / area *',
                            controller: _location,
                            hint: 'e.g. Ibeju-Lekki, near Dangote Refinery',
                            onChanged: (_) => setState(() {}),
                          ),
                          _twoCol(
                            left: _stateDropdown(),
                            right: _field(
                              label: 'LGA',
                              controller: _lga,
                              hint: 'Local Government Area',
                            ),
                          ),

                          const SizedBox(height: 16),
                          const _SectionTitle('Pricing & inventory'),
                          const SizedBox(height: 4),
                          const Text(
                            'For estates with multiple plots, set total units to the number of plots — each contract reserves one plot.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          _twoCol(
                            left: _field(
                              label: 'Base price per unit (₦) *',
                              controller: _basePrice,
                              hint: 'e.g. 5,000,000',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,]')),
                                _NumberFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                            ),
                            right: _field(
                              label: 'Total units *',
                              controller: _totalUnits,
                              hint: '1 for a single property',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (_) => setState(() {}),
                            ),
                          ),

                          const SizedBox(height: 16),
                          const _SectionTitle('Description'),
                          const SizedBox(height: 12),
                          _field(
                            label: 'Details',
                            controller: _description,
                            hint:
                            'Features, infrastructure, payment options, etc.',
                            maxLines: 4,
                          ),

                          const SizedBox(height: 16),
                          const _SectionTitle('Photos'),
                          const SizedBox(height: 4),
                          const Text(
                            'The first photo becomes the cover. Add more from the property page after creating.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                          const SizedBox(height: 12),
                          PhotoPicker(
                            onChanged: (p) => setState(() => _photos = p),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting ? null : () => context.go('/properties'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_isValid && !_submitting) ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: Text(_submitting
                    ? (_photos.isEmpty
                    ? 'Saving…'
                    : 'Uploading…')
                    : 'Add property'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeDropdown() => _Dropdown<PropertyType>(
    label: 'Property type *',
    value: _type,
    items: PropertyType.values,
    itemLabel: _typeLabel,
    onChanged: (v) => setState(() => _type = v ?? PropertyType.land),
  );

  Widget _stateDropdown() => _Dropdown<String>(
    label: 'State *',
    value: _state,
    items: _nigerianStates,
    onChanged: (v) => setState(() => _state = v),
  );

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int? maxLines,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) =>
      _Field(
        label: label,
        controller: controller,
        hint: hint,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
      );

  Widget _twoCol({required Widget left, required Widget right}) {
    final wide = MediaQuery.of(context).size.width >= 640;
    if (!wide) return Column(children: [left, right]);
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

String _typeLabel(PropertyType t) => switch (t) {
  PropertyType.land => 'Land',
  PropertyType.house => 'House',
  PropertyType.duplex => 'Duplex',
  PropertyType.bungalow => 'Bungalow',
  PropertyType.apartment => 'Apartment',
  PropertyType.estate => 'Estate',
  PropertyType.commercial => 'Commercial',
  PropertyType.office => 'Office',
};

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
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
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            decoration: InputDecoration(hintText: hint, isDense: true),
          ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T)? itemLabel;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
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
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            value: value,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final v in items)
                DropdownMenuItem<T>(
                  value: v,
                  child: Text(
                    itemLabel != null ? itemLabel!(v) : v.toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Formats input as `1,000,000` while typing.
class _NumberFormatter extends TextInputFormatter {
  static final _f = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = _f.format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}