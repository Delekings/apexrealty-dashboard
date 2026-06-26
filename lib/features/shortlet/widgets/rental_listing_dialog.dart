// lib/features/shortlet/widgets/rental_listing_dialog.dart
//
// Dialog for creating or editing a rental_listing on a property.
// Handles both "whole property" listings and per-unit-type listings
// (e.g. one listing per room type for a hotel).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/rental_listings_repository.dart';
import '../../auth/providers/auth_providers.dart';


/// Common amenities offered by Nigerian shortlets / serviced apartments.
const _amenityOptions = <String, IconData>{
  'wifi': Icons.wifi,
  'air conditioning': Icons.ac_unit,
  'pool': Icons.pool,
  'parking': Icons.local_parking,
  'kitchen': Icons.kitchen,
  'washing machine': Icons.local_laundry_service,
  'tv / netflix': Icons.tv,
  'workspace': Icons.computer,
  'gym': Icons.fitness_center,
  'security / cctv': Icons.security,
  'generator / power backup': Icons.bolt,
  'borehole / running water': Icons.water_drop,
  'cleaning service': Icons.cleaning_services,
  'breakfast included': Icons.restaurant,
};

class RentalListingDialog extends ConsumerStatefulWidget {
  final String propertyId;
  final List<PropertyUnitType> unitTypes;
  final RentalListing? existing;
  final String? prefilledUnitTypeId;

  const RentalListingDialog({
    super.key,
    required this.propertyId,
    required this.unitTypes,
    this.existing,
    this.prefilledUnitTypeId,
  });

  @override
  ConsumerState<RentalListingDialog> createState() =>
      _RentalListingDialogState();
}

class _RentalListingDialogState extends ConsumerState<RentalListingDialog> {
  // Mode
  late bool _isPerUnit;
  String? _unitTypeId;

  // Pricing
  final _nightlyRate = TextEditingController();
  final _weeklyRate = TextEditingController();
  final _monthlyRate = TextEditingController();
  final _cleaningFee = TextEditingController(text: '0');
  final _securityDeposit = TextEditingController(text: '0');

  // Stay rules
  final _maxGuests = TextEditingController(text: '2');
  final _minNights = TextEditingController(text: '1');
  final _maxNights = TextEditingController(text: '30');
  TimeOfDay _checkInTime = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay _checkOutTime = const TimeOfDay(hour: 11, minute: 0);

  // Content
  final _description = TextEditingController();
  final _houseRules = TextEditingController();
  final Set<String> _amenities = {};
  CancellationPolicy _cancellationPolicy = CancellationPolicy.moderate;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;
  bool get _hasUnitTypes => widget.unitTypes.isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final e = widget.existing!;
      _isPerUnit = e.propertyUnitTypeId != null;
      _unitTypeId = e.propertyUnitTypeId;
      _nightlyRate.text = e.nightlyRateNgn.toStringAsFixed(0);
      _weeklyRate.text = e.weeklyRateNgn?.toStringAsFixed(0) ?? '';
      _monthlyRate.text = e.monthlyRateNgn?.toStringAsFixed(0) ?? '';
      _cleaningFee.text = e.cleaningFeeNgn.toStringAsFixed(0);
      _securityDeposit.text = e.securityDepositNgn.toStringAsFixed(0);
      _maxGuests.text = e.maxGuests.toString();
      _minNights.text = e.minNights.toString();
      _maxNights.text = e.maxNights.toString();
      _checkInTime = _parseTime(e.checkInTime);
      _checkOutTime = _parseTime(e.checkOutTime);
      _description.text = e.description ?? '';
      _houseRules.text = e.houseRulesMarkdown ?? '';
      _amenities.addAll(e.amenities);
      _cancellationPolicy = e.cancellationPolicy;
    } else {
      _isPerUnit = widget.prefilledUnitTypeId != null;
      _unitTypeId = widget.prefilledUnitTypeId;
    }
  }

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 15,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? _checkInTime : _checkOutTime,
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _nightlyRate.dispose();
    _weeklyRate.dispose();
    _monthlyRate.dispose();
    _cleaningFee.dispose();
    _securityDeposit.dispose();
    _maxGuests.dispose();
    _minNights.dispose();
    _maxNights.dispose();
    _description.dispose();
    _houseRules.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nightly = num.tryParse(_nightlyRate.text.trim());
    if (nightly == null || nightly <= 0) {
      setState(() => _error = 'Nightly rate is required');
      return;
    }
    final maxGuests = int.tryParse(_maxGuests.text.trim());
    if (maxGuests == null || maxGuests < 1) {
      setState(() => _error = 'Max guests must be at least 1');
      return;
    }
    if (_isPerUnit && _unitTypeId == null) {
      setState(() => _error = 'Pick which unit type this listing is for');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on profile');
      }
      final repo = ref.read(rentalListingsRepoProvider);

      if (_isEditing) {
        await repo.update(widget.existing!.id, {
          'nightly_rate_ngn': nightly,
          'weekly_rate_ngn': num.tryParse(_weeklyRate.text.trim()),
          'monthly_rate_ngn': num.tryParse(_monthlyRate.text.trim()),
          'cleaning_fee_ngn': num.tryParse(_cleaningFee.text.trim()) ?? 0,
          'security_deposit_ngn':
          num.tryParse(_securityDeposit.text.trim()) ?? 0,
          'max_guests': maxGuests,
          'min_nights': int.tryParse(_minNights.text.trim()) ?? 1,
          'max_nights': int.tryParse(_maxNights.text.trim()) ?? 30,
          'check_in_time': _fmtTime(_checkInTime),
          'check_out_time': _fmtTime(_checkOutTime),
          'description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          'house_rules_markdown': _houseRules.text.trim().isEmpty
              ? null
              : _houseRules.text.trim(),
          'amenities': _amenities.toList(),
          'cancellation_policy':
          cancellationPolicyToDb(_cancellationPolicy),
        });
      } else {
        await repo.create(
          agencyId: profile!.agencyId!,
          propertyId: widget.propertyId,
          propertyUnitTypeId: _isPerUnit ? _unitTypeId : null,
          nightlyRateNgn: nightly,
          weeklyRateNgn: num.tryParse(_weeklyRate.text.trim()),
          monthlyRateNgn: num.tryParse(_monthlyRate.text.trim()),
          cleaningFeeNgn: num.tryParse(_cleaningFee.text.trim()) ?? 0,
          securityDepositNgn:
          num.tryParse(_securityDeposit.text.trim()) ?? 0,
          maxGuests: maxGuests,
          minNights: int.tryParse(_minNights.text.trim()) ?? 1,
          maxNights: int.tryParse(_maxNights.text.trim()) ?? 30,
          checkInTime: _fmtTime(_checkInTime),
          checkOutTime: _fmtTime(_checkOutTime),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          houseRulesMarkdown: _houseRules.text.trim().isEmpty
              ? null
              : _houseRules.text.trim(),
          amenities: _amenities.toList(),
          cancellationPolicy: _cancellationPolicy,
        );
      }

      ref.invalidate(propertyListingsProvider(widget.propertyId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      // The unique constraint will surface as duplicate key violation
      if (msg.contains('rental_listings_property_id') ||
          msg.contains('23505')) {
        setState(() => _error =
        'This unit already has a rental listing. Edit the existing one instead.');
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasUnitTypes && !_isEditing) _modeSection(),
                    _pricingSection(),
                    const SizedBox(height: 20),
                    _staySection(),
                    const SizedBox(height: 20),
                    _amenitiesSection(),
                    const SizedBox(height: 20),
                    _contentSection(),
                    const SizedBox(height: 20),
                    _policySection(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
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
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? 'Edit rental listing'
                    : 'Make this bookable for short stays',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _isEditing
                    ? 'Update pricing, rules, or amenities.'
                    : 'Set up nightly pricing and stay rules. Guests will be able to book this unit.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Widget _footer() => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
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
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check, size: 14),
          label: Text(_saving
              ? 'Saving…'
              : (_isEditing ? 'Save changes' : 'Create listing')),
        ),
      ],
    ),
  );

  Widget _modeSection() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('What gets booked'),
        const SizedBox(height: 6),
        const Text(
          "This property has multiple unit types. Each one can be its own rental listing.",
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _modeOption(
                title: 'Whole property',
                subtitle: 'Booking takes the entire property',
                selected: !_isPerUnit,
                onTap: () => setState(() {
                  _isPerUnit = false;
                  _unitTypeId = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _modeOption(
                title: 'One unit type',
                subtitle: 'Booking takes one room/unit only',
                selected: _isPerUnit,
                onTap: () => setState(() => _isPerUnit = true),
              ),
            ),
          ],
        ),
        if (_isPerUnit) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _unitTypeId,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Unit type',
            ),
            items: [
              for (final u in widget.unitTypes)
                DropdownMenuItem(
                  value: u.id,
                  child: Text(u.summary()),
                ),
            ],
            onChanged: (v) => setState(() => _unitTypeId = v),
          ),
        ],
      ],
    ),
  );

  Widget _modeOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandLight : null,
          border: Border.all(
              color: selected ? AppColors.brand : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.brand : AppColors.text)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _pricingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Pricing'),
      const SizedBox(height: 10),
      _row(
        _ngnField(_nightlyRate, 'Nightly rate *', hint: '25000'),
        _ngnField(_maxGuests, 'Max guests *', hint: '2', noNaira: true),
      ),
      const SizedBox(height: 10),
      _row(
        _ngnField(_weeklyRate, 'Weekly rate (optional)',
            hint: 'Auto = nightly × 7'),
        _ngnField(_monthlyRate, 'Monthly rate (optional)',
            hint: 'Auto = nightly × 30'),
      ),
      const SizedBox(height: 10),
      _row(
        _ngnField(_cleaningFee, 'Cleaning fee', hint: '5000'),
        _ngnField(_securityDeposit, 'Security deposit', hint: '0'),
      ),
    ],
  );

  Widget _staySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Stay rules'),
      const SizedBox(height: 10),
      _row(
        _ngnField(_minNights, 'Min nights', hint: '1', noNaira: true),
        _ngnField(_maxNights, 'Max nights', hint: '30', noNaira: true),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _pickTime(true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Check-in time',
                  isDense: true,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(_fmtTime(_checkInTime),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _pickTime(false),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Check-out time',
                  isDense: true,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(_fmtTime(_checkOutTime),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _amenitiesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Amenities'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final entry in _amenityOptions.entries)
            _amenityChip(entry.key, entry.value),
        ],
      ),
    ],
  );

  Widget _amenityChip(String name, IconData icon) {
    final selected = _amenities.contains(name);
    return FilterChip(
      selected: selected,
      avatar: Icon(icon,
          size: 14, color: selected ? AppColors.brand : AppColors.muted),
      label: Text(name,
          style: TextStyle(
              fontSize: 11,
              color: selected ? AppColors.brand : AppColors.text)),
      selectedColor: AppColors.brandLight,
      onSelected: (v) => setState(() {
        if (v) {
          _amenities.add(name);
        } else {
          _amenities.remove(name);
        }
      }),
    );
  }

  Widget _contentSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Description & house rules'),
      const SizedBox(height: 10),
      TextField(
        controller: _description,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Description (shown to guests)',
          hintText:
          'A cozy 2-bedroom apartment in the heart of Lekki Phase 1...',
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _houseRules,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'House rules / terms (guests will sign these)',
          hintText:
          'No smoking indoors. No pets. Check-in by 9PM. Quiet hours after 10PM...',
          isDense: true,
        ),
      ),
    ],
  );

  Widget _policySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Cancellation policy'),
      const SizedBox(height: 8),
      for (final p in CancellationPolicy.values)
        RadioListTile<CancellationPolicy>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: p,
          groupValue: _cancellationPolicy,
          onChanged: (v) => setState(
                  () => _cancellationPolicy = v ?? _cancellationPolicy),
          title: Text(
            cancellationPolicyLabel(p),
            style: const TextStyle(fontSize: 12),
          ),
        ),
    ],
  );

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          letterSpacing: 0.5));

  Widget _row(Widget left, Widget right) => Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );

  Widget _ngnField(TextEditingController c, String label,
      {String? hint, bool noNaira = false}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        prefixText: noNaira ? null : '₦ ',
      ),
    );
  }
}