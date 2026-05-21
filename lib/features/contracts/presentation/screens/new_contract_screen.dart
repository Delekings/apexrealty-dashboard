// lib/features/contracts/presentation/screens/new_contract_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/clients_repository.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../clients/providers/clients_providers.dart';
import '../../../properties/providers/properties_providers.dart';
import '../../providers/contracts_providers.dart';

class NewContractScreen extends ConsumerStatefulWidget {
  /// Pre-fill the property if we came from the property detail page.
  final String? propertyId;
  const NewContractScreen({super.key, this.propertyId});

  @override
  ConsumerState<NewContractScreen> createState() => _NewContractScreenState();
}

class _NewContractScreenState extends ConsumerState<NewContractScreen> {
  // Selections
  ClientListItem? _client;
  Property? _property;
  final _unitLabel = TextEditingController();

  // Pricing
  final _totalPrice = TextEditingController();
  final _initialDeposit = TextEditingController(text: '0');

  // Plan
  PaymentPlan _plan = PaymentPlan.monthly;
  final _planMonths = TextEditingController(text: '12');
  DateTime _startDate = DateTime.now();

  final _notes = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // If we came from a property page, pre-load it
    if (widget.propertyId != null) {
      _loadProperty(widget.propertyId!);
    }
  }

  Future<void> _loadProperty(String id) async {
    final repo = ref.read(propertiesRepoProvider);
    final p = await repo.get(id);
    if (!mounted) return;
    setState(() {
      _property = p;
      _totalPrice.text = NumberFormat('#,###').format(p.basePrice);
    });
  }

  @override
  void dispose() {
    for (final c in [_unitLabel, _totalPrice, _initialDeposit, _planMonths, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  num? get _parsedTotal => num.tryParse(_totalPrice.text.replaceAll(',', ''));
  num? get _parsedDeposit => num.tryParse(_initialDeposit.text.replaceAll(',', ''));

  bool get _isValid {
    if (_client == null || _property == null) return false;
    final total = _parsedTotal;
    if (total == null || total <= 0) return false;
    final deposit = _parsedDeposit ?? 0;
    if (deposit < 0 || deposit > total) return false;
    if (_plan != PaymentPlan.outright) {
      final months = int.tryParse(_planMonths.text);
      if (months == null || months < 1) return false;
    }
    return true;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(contractsRepoProvider);
      final id = await repo.create(
        clientId: _client!.id,
        propertyId: _property!.id,
        unitLabel: _unitLabel.text.trim().isEmpty ? null : _unitLabel.text.trim(),
        totalPrice: _parsedTotal!,
        initialDeposit: _parsedDeposit ?? 0,
        paymentPlan: _plan,
        planMonths: _plan == PaymentPlan.outright
            ? null
            : int.parse(_planMonths.text),
        startDate: _startDate,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      // Refresh related data
      ref.invalidate(contractsListProvider);
      ref.invalidate(propertyDetailProvider(_property!.id));
      ref.invalidate(propertiesPageProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contract created for ${_client!.fullName}'),
            backgroundColor: AppColors.brand,
          ),
        );
        context.go('/contracts/$id');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(allClientsForPickerProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => context.go(
                  _property != null
                      ? '/properties/${_property!.id}'
                      : '/properties',
                ),
              ),
              const SizedBox(width: 4),
              const Text('New Contract',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
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
                          // --- Section: Who's buying ---
                          const _SectionTitle('Buyer'),
                          const SizedBox(height: 12),
                          clientsAsync.when(
                            loading: () => const _LoadingStub(),
                            error: (e, _) => Text('Could not load clients: $e',
                                style:
                                const TextStyle(color: AppColors.danger)),
                            data: (clients) => _ClientPicker(
                              clients: clients,
                              selected: _client,
                              onChanged: (c) => setState(() => _client = c),
                            ),
                          ),

                          const SizedBox(height: 16),
                          // --- Section: What they're buying ---
                          const _SectionTitle('Property'),
                          const SizedBox(height: 12),
                          if (_property == null)
                            _PickPropertyButton(
                              onPick: (p) => setState(() {
                                _property = p;
                                _totalPrice.text =
                                    NumberFormat('#,###').format(p.basePrice);
                              }),
                            )
                          else
                            _SelectedPropertyCard(
                              property: _property!,
                              onChange: () => setState(() {
                                _property = null;
                                _totalPrice.clear();
                              }),
                            ),

                          if (_property != null && _property!.totalUnits > 1) ...[
                            const SizedBox(height: 12),
                            _LabelledField(
                              label: 'Unit / plot label',
                              controller: _unitLabel,
                              hint: 'e.g. Block A, Plot 7',
                            ),
                          ],

                          const SizedBox(height: 16),
                          const _SectionTitle('Pricing'),
                          const SizedBox(height: 12),
                          _twoCol(
                            left: _LabelledField(
                              label: 'Total price (₦) *',
                              controller: _totalPrice,
                              hint: 'e.g. 5,000,000',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,]')),
                                _NumberFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                            ),
                            right: _LabelledField(
                              label: 'Initial deposit (₦)',
                              controller: _initialDeposit,
                              hint: 'Amount paid upfront',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,]')),
                                _NumberFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                            ),
                          ),

                          const SizedBox(height: 16),
                          const _SectionTitle('Payment plan'),
                          const SizedBox(height: 12),
                          _planChooser(),
                          if (_plan != PaymentPlan.outright) ...[
                            const SizedBox(height: 12),
                            _twoCol(
                              left: _LabelledField(
                                label: _plan == PaymentPlan.monthly
                                    ? 'Number of months *'
                                    : 'Number of installments *',
                                controller: _planMonths,
                                hint: _plan == PaymentPlan.monthly
                                    ? 'e.g. 12'
                                    : 'e.g. 4',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                              right: _dateField(),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            _dateField(),
                          ],

                          // Summary preview
                          if (_isValid) ...[
                            const SizedBox(height: 16),
                            _SummaryCard(
                              totalPrice: _parsedTotal!,
                              deposit: _parsedDeposit ?? 0,
                              plan: _plan,
                              months: int.tryParse(_planMonths.text) ?? 1,
                            ),
                          ],

                          const SizedBox(height: 16),
                          const _SectionTitle('Notes'),
                          const SizedBox(height: 12),
                          _LabelledField(
                            label: 'Internal notes',
                            controller: _notes,
                            hint: 'Anything special about this deal',
                            maxLines: 3,
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
                label: Text(_submitting ? 'Creating…' : 'Create contract'),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  Widget _planChooser() {
    final options = [
      (PaymentPlan.outright, 'Outright', 'One-time full payment'),
      (PaymentPlan.monthly, 'Monthly', 'Equal payments each month'),
      (PaymentPlan.quarterly, 'Quarterly', 'Every 3 months'),
      (PaymentPlan.biannual, 'Biannual', 'Every 6 months'),
      (PaymentPlan.annual, 'Annual', 'Once a year'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (plan, label, desc) in options)
          GestureDetector(
            onTap: () => setState(() => _plan = plan),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _plan == plan ? AppColors.brandLight : AppColors.bg,
                border: Border.all(
                  color: _plan == plan ? AppColors.brand : AppColors.border,
                  width: _plan == plan ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _plan == plan
                              ? AppColors.brand
                              : AppColors.text)),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Start date *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          InkWell(
            onTap: _pickStartDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Text(Formatters.date(_startDate),
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Sub-widgets ======

class _ClientPicker extends StatelessWidget {
  final List<ClientListItem> clients;
  final ClientListItem? selected;
  final ValueChanged<ClientListItem?> onChanged;

  const _ClientPicker({
    required this.clients,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warnLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.warn),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/clients/new'),
                child: const Text(
                  'You have no clients yet. Onboard one first.',
                  style: TextStyle(fontSize: 13, color: AppColors.warn),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<ClientListItem>(
      value: selected,
      isDense: true,
      decoration: const InputDecoration(
        hintText: 'Select a client',
        isDense: true,
        prefixIcon: Icon(Icons.person_outline, size: 18, color: AppColors.muted),
      ),
      isExpanded: true,
      items: [
        for (final c in clients)
          DropdownMenuItem<ClientListItem>(
            value: c,
            child: Text(
              '${c.fullName}  ·  ${c.phone}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _PickPropertyButton extends ConsumerWidget {
  final ValueChanged<Property> onPick;
  const _PickPropertyButton({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(propertiesPageProvider);
    return pageAsync.when(
      loading: () => const _LoadingStub(),
      error: (e, _) => Text('Could not load properties: $e',
          style: const TextStyle(color: AppColors.danger)),
      data: (page) {
        final available = page.items
            .where((p) => p.availableUnits > 0 && p.status != PropertyStatus.inactive)
            .toList();
        if (available.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warnLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.warn),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No properties with available units. Add a property first.',
                    style: TextStyle(fontSize: 13, color: AppColors.warn),
                  ),
                ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<Property>(
          value: null,
          isDense: true,
          decoration: const InputDecoration(
            hintText: 'Select a property',
            isDense: true,
            prefixIcon:
            Icon(Icons.home_work_outlined, size: 18, color: AppColors.muted),
          ),
          isExpanded: true,
          items: [
            for (final p in available)
              DropdownMenuItem<Property>(
                value: p,
                child: Text(
                  '${p.title}  ·  ${Formatters.nairaCompact(p.basePrice)}'
                      '${p.totalUnits > 1 ? "  ·  ${p.availableUnits} of ${p.totalUnits} units" : ""}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onPick(v);
          },
        );
      },
    );
  }
}

class _SelectedPropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onChange;
  const _SelectedPropertyCard({required this.property, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.home_work_outlined, color: AppColors.brand, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(property.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  '${property.location}, ${property.state} · '
                      '${property.availableUnits} of ${property.totalUnits} units available',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final num totalPrice;
  final num deposit;
  final PaymentPlan plan;
  final int months;

  const _SummaryCard({
    required this.totalPrice,
    required this.deposit,
    required this.plan,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final balance = totalPrice - deposit;
    final perInstallment = plan == PaymentPlan.outright
        ? balance
        : (balance / months);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SCHEDULE PREVIEW',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _kv('Total price', Formatters.naira(totalPrice)),
          _kv('Down payment', Formatters.naira(deposit)),
          _kv('Balance to finance', Formatters.naira(balance)),
          const Divider(height: 16),
          if (plan == PaymentPlan.outright)
            _kv('Single payment',
                Formatters.naira(perInstallment),
                emphasize: true)
          else
            _kv(
              '$months payment${months == 1 ? '' : 's'} of',
              Formatters.naira(perInstallment),
              emphasize: true,
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: TextStyle(
                    fontSize: 12,
                    color: emphasize ? AppColors.text : AppColors.muted)),
          ),
          Text(v,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                  color: emphasize ? AppColors.brand : AppColors.text)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
}

class _LabelledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _LabelledField({
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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

class _LoadingStub extends StatelessWidget {
  const _LoadingStub();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
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