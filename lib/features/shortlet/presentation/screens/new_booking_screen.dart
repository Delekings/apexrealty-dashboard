// lib/features/shortlet/presentation/screens/new_booking_screen.dart
//
// The booking creation form:
//   1. Pick a rental listing (active only)
//   2. Pick check-in/check-out dates (conflict-aware calendar)
//   3. Pick a guest (typeahead with "+ Add new")
//   4. Set guests count, source, optional notes
//   5. Live pricing summary
//   6. Save → handles exclusion-constraint race condition gracefully

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/bookings_repository.dart';
import '../../../../data/repositories/clients_repository.dart';
import '../../../properties/providers/properties_providers.dart';
import '../../../../data/repositories/rental_listings_repository.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../widgets/add_guest_modal.dart';
import '../../widgets/availability_calendar.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class NewBookingScreen extends ConsumerStatefulWidget {
  const NewBookingScreen({super.key});

  @override
  ConsumerState<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends ConsumerState<NewBookingScreen> {
  // Form state
  RentalListing? _listing;
  Property? _listingProperty;
  PropertyUnitType? _listingUnitType;
  DateTime? _checkIn;
  DateTime? _checkOut;
  String? _selectedClientId;
  String? _selectedClientLabel;
  int _guestsCount = 1;
  BookingSource _source = BookingSource.direct;
  final _notes = TextEditingController();

  // Loaded data
  List<RentalListing> _listings = [];
  List<ClientListItem> _clients = [];
  bool _initialLoading = true;
  bool _saving = false;
  String? _error;

  // Client typeahead
  final _clientSearch = TextEditingController();
  bool _showClientPicker = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _notes.dispose();
    _clientSearch.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final listingsRepo = ref.read(rentalListingsRepoProvider);
      final clientsRepo = ClientsRepository();
      final results = await Future.wait([
        listingsRepo.listAllActive(),
        clientsRepo.listAllForPicker(),
      ]);
      if (!mounted) return;
      setState(() {
        _listings = results[0] as List<RentalListing>;
        _clients = results[1] as List<ClientListItem>;
        _initialLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load form data: $e';
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _onListingChanged(String? listingId) async {
    if (listingId == null) {
      setState(() {
        _listing = null;
        _listingProperty = null;
        _listingUnitType = null;
        _checkIn = null;
        _checkOut = null;
      });
      return;
    }
    final listing = _listings.firstWhere((l) => l.id == listingId);
    setState(() {
      _listing = listing;
      _checkIn = null;
      _checkOut = null;
    });
    // Fetch property + unit type info for the summary line
    try {
      final propRepo = ref.read(propertiesRepoProvider);
      final prop = await propRepo.get(listing.propertyId);
      PropertyUnitType? ut;
      if (listing.propertyUnitTypeId != null) {
        ut = await propRepo.getUnitTypeById(listing.propertyUnitTypeId!);
      }
      if (mounted) {
        setState(() {
          _listingProperty = prop;
          _listingUnitType = ut;
        });
      }
    } catch (_) {/* non-fatal */}
  }

  num get _subtotal {
    if (_listing == null || _checkIn == null || _checkOut == null) return 0;
    final nights = _checkOut!.difference(_checkIn!).inDays;
    return _listing!.nightlyRateNgn * nights;
  }

  num get _total {
    if (_listing == null) return 0;
    return _subtotal +
        _listing!.cleaningFeeNgn +
        _listing!.securityDepositNgn;
  }

  int get _nights {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays;
  }

  bool get _canSave =>
      _listing != null &&
          _checkIn != null &&
          _checkOut != null &&
          _selectedClientId != null &&
          _nights >= _listing!.minNights &&
          _nights <= _listing!.maxNights &&
          _guestsCount >= 1 &&
          _guestsCount <= _listing!.maxGuests;

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on profile');
      }

      final id = await ref.read(bookingsRepoProvider).create(
        agencyId: profile!.agencyId!,
        clientId: _selectedClientId!,
        propertyId: _listing!.propertyId,
        propertyUnitTypeId: _listing!.propertyUnitTypeId,
        rentalListingId: _listing!.id,
        checkInDate: _checkIn!,
        checkOutDate: _checkOut!,
        guestsCount: _guestsCount,
        nightlyRateNgn: _listing!.nightlyRateNgn,
        cleaningFeeNgn: _listing!.cleaningFeeNgn,
        securityDepositNgn: _listing!.securityDepositNgn,
        agentId: profile.id,
        source: _source,
        status: BookingStatus.confirmed,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      ref.invalidate(upcomingBookingsProvider);
      ref.invalidate(inHouseBookingsProvider);
      ref.invalidate(pastBookingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking created · $id')),
      );
      context.go('/bookings');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addNewGuest() async {
    final result = await showAddGuestModal(context);
    if (result == null) return;
    setState(() {
      _selectedClientId = result.id;
      _selectedClientLabel = '${result.fullName} · ${result.phone}';
      _showClientPicker = false;
      _clientSearch.clear();
      // Add to local list so typeahead has it without a refetch
      _clients.add(ClientListItem(
        id: result.id,
        fullName: result.fullName,
        phone: result.phone,
        email: result.email,
        createdAt: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
        body: Center(
            child: LintelLoader()),
      );
    }

    return Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 20),
              _listingSection(),
              const SizedBox(height: 20),
              if (_listing != null) ...[
                _datesSection(),
                const SizedBox(height: 20),
                _guestSection(),
                const SizedBox(height: 20),
                _detailsSection(),
                const SizedBox(height: 20),
                _pricingSection(),
                const SizedBox(height: 20),
                if (_error != null) ...[
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
                  const SizedBox(height: 12),
                ],
                _footer(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      IconButton(
        icon: const Icon(Icons.arrow_back, size: 18),
        onPressed: () => context.go('/bookings'),
      ),
      const SizedBox(width: 4),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New booking',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text(
              'Pick a listing, set the dates, and add the guest.',
              style:
              TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _listingSection() {
    if (_listings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warnLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber,
                size: 16, color: AppColors.warn),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No active rental listings yet. Go to Properties and set one up first.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/properties'),
              child: const Text('Properties'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('LISTING'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _listing?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Pick a rental listing',
          ),
          items: _listings
              .map((l) => DropdownMenuItem(
            value: l.id,
            child: Text(
              _listingLabel(l),
              overflow: TextOverflow.ellipsis,
            ),
          ))
              .toList(),
          onChanged: _onListingChanged,
        ),
        if (_listing != null) ...[
          const SizedBox(height: 6),
          Text(
            '${Formatters.naira(_listing!.nightlyRateNgn)}/night · sleeps ${_listing!.maxGuests} · ${_listing!.minNights}-${_listing!.maxNights} nights',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  String _listingLabel(RentalListing l) {
    // We don't have property/unit type names cached for the dropdown,
    // so use the rate as the disambiguator. The selected one shows
    // full details below.
    return '${Formatters.naira(l.nightlyRateNgn)}/night · sleeps ${l.maxGuests}';
  }

  Widget _datesSection() {
    final dateFmt = DateFormat('d MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('DATES'),
        const SizedBox(height: 8),
        AvailabilityCalendar(
          propertyId: _listing!.propertyId,
          propertyUnitTypeId: _listing!.propertyUnitTypeId,
          checkInDate: _checkIn,
          checkOutDate: _checkOut,
          onRangeChanged: (ci, co) => setState(() {
            _checkIn = ci;
            _checkOut = co;
          }),
        ),
        const SizedBox(height: 8),
        if (_checkIn != null && _checkOut != null)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available,
                    size: 14, color: AppColors.brand),
                const SizedBox(width: 6),
                Text(
                  '${dateFmt.format(_checkIn!)} → ${dateFmt.format(_checkOut!)} · $_nights night${_nights == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else if (_checkIn != null)
          const Text(
            'Tap a check-out date',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          )
        else
          const Text(
            'Tap a check-in date',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        if (_nights > 0 &&
            (_nights < _listing!.minNights ||
                _nights > _listing!.maxNights))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _nights < _listing!.minNights
                  ? 'Minimum ${_listing!.minNights} night${_listing!.minNights == 1 ? '' : 's'} for this listing'
                  : 'Maximum ${_listing!.maxNights} nights for this listing',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _guestSection() {
    final query = _clientSearch.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _clients.take(10).toList()
        : _clients
        .where((c) =>
    c.fullName.toLowerCase().contains(query) ||
        c.phone.toLowerCase().contains(query) ||
        (c.email?.toLowerCase().contains(query) ?? false))
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('GUEST'),
        const SizedBox(height: 8),
        if (_selectedClientId != null && !_showClientPicker)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.brand),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_selectedClientLabel ?? '',
                        style: const TextStyle(fontSize: 13))),
                TextButton(
                  onPressed: () => setState(() {
                    _showClientPicker = true;
                    _selectedClientId = null;
                  }),
                  child: const Text('Change'),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _clientSearch,
            decoration: InputDecoration(
              hintText: 'Search clients by name, phone, or email',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 16),
              suffixIcon: TextButton.icon(
                onPressed: _addNewGuest,
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('Add new'),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_clients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No clients yet. Click "Add new" to create one.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.brandLight,
                      child: Text(c.initials,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600)),
                    ),
                    title: Text(c.fullName,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(c.phone,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    onTap: () => setState(() {
                      _selectedClientId = c.id;
                      _selectedClientLabel = '${c.fullName} · ${c.phone}';
                      _showClientPicker = false;
                      _clientSearch.clear();
                    }),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _detailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('DETAILS'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Guests',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 18),
                        onPressed: _guestsCount > 1
                            ? () => setState(() => _guestsCount--)
                            : null,
                      ),
                      Container(
                        width: 32,
                        alignment: Alignment.center,
                        child: Text('$_guestsCount',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        onPressed: (_listing != null &&
                            _guestsCount < _listing!.maxGuests)
                            ? () => setState(() => _guestsCount++)
                            : null,
                      ),
                      Text(
                        'of ${_listing?.maxGuests ?? '?'} max',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<BookingSource>(
                    isExpanded: true,
                    value: _source,
                    isDense: true,
                    decoration: const InputDecoration(isDense: true),
                    items: BookingSource.values
                        .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(bookingSourceLabel(s),
                          style: const TextStyle(fontSize: 13)),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _source = v ?? _source),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText:
            'e.g. arriving late, requested airport pickup, special diet',
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _pricingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('PRICING'),
          const SizedBox(height: 10),
          if (_nights > 0) ...[
            _priceRow(
              '${Formatters.naira(_listing!.nightlyRateNgn)} × $_nights night${_nights == 1 ? '' : 's'}',
              Formatters.naira(_subtotal),
            ),
            if (_listing!.cleaningFeeNgn > 0)
              _priceRow('Cleaning fee',
                  Formatters.naira(_listing!.cleaningFeeNgn)),
            if (_listing!.securityDepositNgn > 0)
              _priceRow('Security deposit',
                  Formatters.naira(_listing!.securityDepositNgn)),
            const Divider(),
            _priceRow('TOTAL', Formatters.naira(_total), bold: true),
          ] else
            const Text('Pick check-in and check-out dates to see pricing',
                style:
                TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 14 : 12,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: bold ? AppColors.text : AppColors.text,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _saving ? null : () => context.go('/bookings'),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: (_canSave && !_saving) ? _save : null,
          icon: _saving
              ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check, size: 14),
          label: Text(_saving ? 'Creating…' : 'Create booking'),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          letterSpacing: 0.5));
}