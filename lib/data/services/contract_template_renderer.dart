// lib/data/services/contract_template_renderer.dart
//
// Substitutes {{token}} placeholders in contract clause text with real
// values from the contract, client, property, unit type, and agency.
//
// The renderer is pure: given the same context, it always produces the
// same output. This makes it safe to use for snapshots, previews, and
// final PDF generation alike.

import 'package:intl/intl.dart';

import '../models/models.dart';

/// All the data needed to render a contract template's clauses.
/// Built from the get_contract_render_context RPC response.
class ContractRenderContext {
  final Map<String, dynamic> agency;
  final Map<String, dynamic> client;
  final Map<String, dynamic> contract;
  final Map<String, dynamic> property;
  final Map<String, dynamic> unitType;
  final List<Installment> installments;

  ContractRenderContext({
    required this.agency,
    required this.client,
    required this.contract,
    required this.property,
    required this.unitType,
    required this.installments,
  });

  /// Construct from the JSON returned by `get_contract_render_context` RPC.
  factory ContractRenderContext.fromRpcResponse({
    required Map<String, dynamic> rpc,
    required List<Installment> installments,
  }) =>
      ContractRenderContext(
        agency: (rpc['agency'] as Map?)?.cast<String, dynamic>() ?? {},
        client: (rpc['client'] as Map?)?.cast<String, dynamic>() ?? {},
        contract: (rpc['contract'] as Map?)?.cast<String, dynamic>() ?? {},
        property: (rpc['property'] as Map?)?.cast<String, dynamic>() ?? {},
        unitType: (rpc['unit_type'] as Map?)?.cast<String, dynamic>() ?? {},
        installments: installments,
      );
}

class ContractTemplateRenderer {
  /// Substitute {{tokens}} in [body] with values from [ctx].
  /// Unknown tokens render as `[unknown: token]` so they stand out
  /// in preview but don't crash the document.
  static String render(String body, ContractRenderContext ctx) {
    final values = buildValueMap(ctx);

    return body.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
      final token = m.group(1)!;
      if (!values.containsKey(token)) {
        return '[unknown: $token]';
      }
      final v = values[token];
      if (v == null || (v is String && v.isEmpty)) {
        return '[$token not set]';
      }
      return v.toString();
    });
  }

  /// Returns just the value map for previews/debugging.
  static Map<String, String?> buildValueMap(ContractRenderContext ctx) {
    final a = ctx.agency;
    final cl = ctx.client;
    final c = ctx.contract;
    final p = ctx.property;
    final ut = ctx.unitType;

    final dateFmt = DateFormat('d MMMM yyyy');

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    final startDate = parseDate(c['start_date']);

    // Total + deposit + per-installment math
    final total = (c['total_price_ngn'] as num?) ?? 0;
    final deposit = (c['initial_deposit_ngn'] as num?) ?? 0;
    final balance = total - deposit;
    final hasDeposit = deposit > 0;

    // The schedule stores the initial deposit as the first installment row
    // (sequence 1) whenever a deposit exists. For the recurring-installment
    // tokens (count / amount / dates) we drop that leading deposit row.
    final recurring = (hasDeposit && ctx.installments.length > 1)
        ? ctx.installments.sublist(1)
        : ctx.installments;

    final int installmentCount = recurring.length;
    final num installmentAmount =
        recurring.isNotEmpty ? recurring.first.amount : 0;

    final firstInstDate =
        recurring.isNotEmpty ? recurring.first.dueDate : startDate;
    final finalInstDate =
        recurring.isNotEmpty ? recurring.last.dueDate : startDate;

    return {
      // --- Vendor ---
      'vendor_name': (a['name'] as String?)?.toUpperCase(),
      'vendor_rc': _formatRc(a['rc_number'] as String?),
      'vendor_legal_form':
      'limited liability company registered under the Companies and Allied Matters Act, 2020',
      'vendor_registered_address':
      (a['registered_address'] as String?) ?? (a['address'] as String?),
      'vendor_head_office_address':
      (a['head_office_address'] as String?) ?? (a['address'] as String?),
      'vendor_phone': a['phone'] as String?,
      'vendor_email': a['email'] as String?,
      'vendor_website': a['website'] as String?,
      'vendor_director_1': a['director_1_name'] as String?,
      'vendor_director_2': a['director_2_name'] as String?,

      // --- Purchaser ---
      'purchaser_name': (cl['full_name'] as String?)?.toUpperCase(),
      'purchaser_gender_designation': _genderDesignation(
        cl['gender'] as String?,
        (cl['nationality'] as String?) ?? 'Nigerian',
      ),
      'purchaser_address': cl['address'] as String?,
      'purchaser_phone': cl['phone'] as String?,
      'purchaser_email': cl['email'] as String?,
      'purchaser_occupation': cl['occupation'] as String?,

      // --- Property ---
      'property_title': (p['title'] as String?)?.toUpperCase(),
      'property_location': p['location'] as String?,
      'property_state': p['state'] as String?,
      'property_lga': p['lga'] as String?,
      'property_full_legal_description':
      _propertyFullDescription(p, ut),
      'property_survey_plan_no': p['survey_plan_no'] as String?,
      'property_certificate_of_occupancy_no':
      p['certificate_of_occupancy_no'] as String?,
      'property_parent_parcel_size': p['parent_parcel_size_sqm'] != null
          ? '${p['parent_parcel_size_sqm']} square meters'
          : null,

      // --- Unit type ---
      'unit_type_title': ut['title'] as String?,
      'unit_count': '1',
      'unit_count_words': 'ONE',
      'unit_size_sqm': ut['size_sqm']?.toString(),
      'unit_total_size_sqm': ut['size_sqm']?.toString(),
      'unit_size_description': _unitSizeDescription(ut),

      // --- Contract ---
      'contract_no': c['contract_no'] as String?,
      'contract_date': dateFmt.format(startDate),
      'contract_date_full':
      'the ${_ordinal(startDate.day)} day of ${DateFormat('MMMM yyyy').format(startDate)}',
      'contract_day_ordinal': _ordinal(startDate.day),
      'contract_month_name': DateFormat('MMMM').format(startDate),
      'contract_year': startDate.year.toString(),

      // --- Payment ---
      'total_price_ngn': _naira(total),
      'total_price_words': _amountInWords(total),
      'down_payment_ngn': _naira(deposit),
      'down_payment_words': _amountInWords(deposit),
      'balance_after_deposit_ngn': _naira(balance),
      'installment_count': installmentCount.toString(),
      'installment_count_words': _intInWords(installmentCount).toUpperCase(),
      'installment_amount_ngn': _naira(installmentAmount),
      'installment_frequency':
      _frequencyWord((c['payment_plan'] as String?) ?? 'monthly')
          .toUpperCase(),
      'installment_payment_window':
      a['default_payment_window_phrase'] as String? ??
          'on or before the last working day of every successive month',
      'first_installment_date': dateFmt.format(firstInstDate),
      'final_installment_date': dateFmt.format(finalInstDate),

      // --- Witnesses (filled in at sign time) ---
      'vendor_witness_name': null,
      'vendor_witness_address': null,
      'vendor_witness_occupation': null,
      'buyer_witness_name': null,
      'buyer_witness_address': null,
      'buyer_witness_occupation': null,

      // --- Lawyer ---
      'lawyer_name': a['lawyer_name'] as String?,
      'lawyer_firm': a['lawyer_firm'] as String?,
      'lawyer_address': a['lawyer_address'] as String?,
      'lawyer_email': a['lawyer_email'] as String?,
      'lawyer_phone': a['lawyer_phone'] as String?,

      // --- Legal / boilerplate ---
      'governing_law':
      (a['default_governing_law'] as String?) ?? 'Federal Republic of Nigeria',
      'dispute_resolution_body':
      (a['default_dispute_resolution_body'] as String?) ??
          'Lagos Multi-Door Courthouse',
      'refund_admin_pct': '${a['default_refund_admin_pct'] ?? 30}%',
      'transfer_processing_fee_pct':
      '${a['default_transfer_processing_fee_pct'] ?? 10}%',
      'construction_deadline_years': _intInWords(
          (a['default_construction_deadline_years'] as num?)?.toInt() ?? 2),
      'grace_period_days':
      '${a['default_grace_period_days'] ?? 30} working days',

      // --- Constants ---
      'today': dateFmt.format(DateTime.now()),
      'current_year': DateTime.now().year.toString(),
    };
  }

  // ---------------- Helpers ----------------

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  static String _naira(num amount) {
    final f = NumberFormat('#,##0', 'en_US');
    return '₦${f.format(amount)}';
  }

  static String _genderDesignation(String? gender, String nationality) {
    final g = switch (gender) {
      'male' => 'Male',
      'female' => 'Female',
      _ => 'Adult'
    };
    return '$g and $nationality Citizen';
  }

  static String _frequencyWord(String plan) => switch (plan) {
    'outright' => 'one-time',
    'monthly' => 'monthly',
    'quarterly' => 'quarterly',
    'biannual' => 'biannual',
    'annual' => 'annual',
    _ => 'periodic',
  };

  static String _propertyFullDescription(
      Map<String, dynamic> p,
      Map<String, dynamic> ut,
      ) {
    // Prefer an explicit, agency-authored legal description when present.
    final stored = (p['full_legal_description'] as String?)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;

    final size = ut['size_sqm']?.toString() ?? p['size_sqm']?.toString() ?? '';
    final survey = (p['survey_plan_no'] as String?) ?? '[Survey Plan]';
    final loc = (p['location'] as String?)?.toUpperCase() ?? '';
    final state = (p['state'] as String?)?.toUpperCase() ?? '';
    return 'ONE PLOT OF LAND MEASURING APPROXIMATELY $size SQUARE METERS '
        'FORMING PART OF THE PARCEL DESCRIBED IN THE SURVEY PLAN NO: $survey '
        'LOCATED AT $loc, $state.';
  }

  /// Formats a company registration number as "RC <number>", tolerating a
  /// stored value that already includes an "RC"/"rc" prefix (with or without a
  /// space) so the contract never reads "RC RC123456".
  static String? _formatRc(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final number = s.replaceFirst(RegExp(r'^[Rr][Cc]\s*'), '').trim();
    if (number.isEmpty) return null;
    return 'RC $number';
  }

  static String _unitSizeDescription(Map<String, dynamic> ut) {
    final size = ut['size_sqm']?.toString();
    if (size == null || size.isEmpty) return 'ONE UNIT';
    return 'ONE PLOT OF LAND MEASURING APPROXIMATELY $size SQUARE METERS';
  }

  // --- Number to words ---

  static String _amountInWords(num amount) {
    final n = amount.toInt();
    if (n == 0) return 'Zero Naira';
    return '${_intInWords(n)} Naira';
  }

  static String _intInWords(int n) {
    if (n == 0) return 'Zero';
    if (n < 0) return 'Negative ${_intInWords(-n)}';

    var remaining = n;
    final parts = <String>[];

    final billions = remaining ~/ 1000000000;
    if (billions > 0) {
      parts.add('${_belowThousand(billions)} Billion');
      remaining -= billions * 1000000000;
    }

    final millions = remaining ~/ 1000000;
    if (millions > 0) {
      parts.add('${_belowThousand(millions)} Million');
      remaining -= millions * 1000000;
    }

    final thousands = remaining ~/ 1000;
    if (thousands > 0) {
      parts.add('${_belowThousand(thousands)} Thousand');
      remaining -= thousands * 1000;
    }

    if (remaining > 0) {
      parts.add(_belowThousand(remaining));
    }

    return parts.join(', ');
  }

  static String _belowThousand(int n) {
    if (n == 0) return '';
    if (n < 20) return _ones[n];
    if (n < 100) {
      final tens = n ~/ 10;
      final ones = n % 10;
      return ones == 0 ? _tens[tens] : '${_tens[tens]}-${_ones[ones]}';
    }
    final hundreds = n ~/ 100;
    final remainder = n % 100;
    return remainder == 0
        ? '${_ones[hundreds]} Hundred'
        : '${_ones[hundreds]} Hundred and ${_belowThousand(remainder)}';
  }

  static const _ones = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen'
  ];

  static const _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety'
  ];
}
