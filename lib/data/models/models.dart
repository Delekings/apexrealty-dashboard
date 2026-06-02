// lib/data/models/models.dart
//
// Plain Dart models that mirror the Supabase tables.
// Swap to Freezed + json_serializable once you run build_runner.

enum UserRole { superAdmin, agencyAdmin, manager, agent, viewer }

UserRole roleFromString(String? s) => switch (s) {
  'super_admin' => UserRole.superAdmin,
  'agency_admin' => UserRole.agencyAdmin,
  'manager' => UserRole.manager,
  'viewer' => UserRole.viewer,
  _ => UserRole.agent,
};

class Profile {
  final String id;
  final String? agencyId;
  final String fullName;
  final String? phone;
  final UserRole role;
  final String? avatarUrl;

  Profile({
    required this.id,
    required this.agencyId,
    required this.fullName,
    required this.role,
    this.phone,
    this.avatarUrl,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    agencyId: m['agency_id'] as String?,
    fullName: (m['full_name'] ?? '') as String,
    phone: m['phone'] as String?,
    role: roleFromString(m['role'] as String?),
    avatarUrl: m['avatar_url'] as String?,
  );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class Client {
  final String id;
  final String agencyId;
  final String fullName;
  final String phone;
  final String? email;
  final String? state;
  final String? address;
  final String? gender;
  final String? nationality;
  final String? occupation;
  final DateTime? dateOfBirth;
  final String? bvn;
  final String? nin;
  final String? nextOfKinName;
  final String? nextOfKinPhone;
  final String? notes;
  final String? assignedAgentId;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.agencyId,
    required this.fullName,
    required this.phone,
    required this.createdAt,
    this.email,
    this.state,
    this.address,
    this.gender,
    this.nationality,
    this.occupation,
    this.dateOfBirth,
    this.bvn,
    this.nin,
    this.nextOfKinName,
    this.nextOfKinPhone,
    this.notes,
    this.assignedAgentId,
  });

  factory Client.fromMap(Map<String, dynamic> m) => Client(
    id: m['id'] as String,
    agencyId: m['agency_id'] as String,
    fullName: m['full_name'] as String,
    phone: m['phone'] as String,
    email: m['email'] as String?,
    state: m['state'] as String?,
    address: m['address'] as String?,
    gender: m['gender'] as String?,
    nationality: m['nationality'] as String?,
    occupation: m['occupation'] as String?,
    dateOfBirth: m['date_of_birth'] != null
        ? DateTime.parse(m['date_of_birth'] as String)
        : null,
    bvn: m['bvn'] as String?,
    nin: m['nin'] as String?,
    nextOfKinName: m['next_of_kin_name'] as String?,
    nextOfKinPhone: m['next_of_kin_phone'] as String?,
    notes: m['notes'] as String?,
    assignedAgentId: m['assigned_agent_id'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

enum PropertyType {
  land, house, duplex, bungalow, apartment, estate, commercial, office
}

enum PropertyStatus {
  available, reserved, partiallySold, soldOut, inactive
}

class Property {
  final String id;
  final String agencyId;
  final String title;
  final PropertyType type;
  final PropertyStatus status;
  final String location;
  final String state;
  final String? lga;
  final String? description;
  final num basePrice;
  final int totalUnits;
  final int availableUnits;
  final String? coverImageUrl;
  final List<String> gallery;
  final String? surveyPlanNo;
  final String? certificateOfOccupancyNo;
  final num? parentParcelSizeSqm;
  final String? fullLegalDescription;

  Property({
    required this.id,
    required this.agencyId,
    required this.title,
    required this.type,
    required this.status,
    required this.location,
    required this.state,
    required this.basePrice,
    required this.totalUnits,
    required this.availableUnits,
    this.lga,
    this.description,
    this.coverImageUrl,
    this.gallery = const [],
    this.surveyPlanNo,
    this.certificateOfOccupancyNo,
    this.parentParcelSizeSqm,
    this.fullLegalDescription,
  });

  factory Property.fromMap(Map<String, dynamic> m) {
    // Parse gallery: it can come back as jsonb List or null
    final rawGallery = m['gallery'];
    final List<String> gallery = rawGallery is List
        ? rawGallery.map((e) => e.toString()).toList()
        : (m['gallery_urls'] is List
        ? (m['gallery_urls'] as List).map((e) => e.toString()).toList()
        : const <String>[]);

    return Property(
      id: m['id'] as String,
      agencyId: m['agency_id'] as String,
      title: m['title'] as String,
      type: PropertyType.values.firstWhere(
            (t) => t.name == m['property_type'],
        orElse: () => PropertyType.land,
      ),
      status: switch (m['status']) {
        'reserved' => PropertyStatus.reserved,
        'partially_sold' => PropertyStatus.partiallySold,
        'sold_out' => PropertyStatus.soldOut,
        'inactive' => PropertyStatus.inactive,
        _ => PropertyStatus.available,
      },
      location: m['location'] as String,
      state: m['state'] as String,
      lga: m['lga'] as String?,
      description: m['description'] as String?,
      basePrice: (m['base_price_ngn'] as num?) ?? 0,
      totalUnits: (m['total_units'] as num?)?.toInt() ?? 1,
      availableUnits: (m['available_units'] as num?)?.toInt() ?? 1,
      coverImageUrl: m['cover_image_url'] as String?,
      gallery: gallery,
      surveyPlanNo: m['survey_plan_no'] as String?,
      certificateOfOccupancyNo: m['certificate_of_occupancy_no'] as String?,
      parentParcelSizeSqm: m['parent_parcel_size_sqm'] as num?,
      fullLegalDescription: m['full_legal_description'] as String?,
    );
  }
}

/// A unit type belonging to a property. A property can have multiple
/// unit types (e.g. "Standard 300sqm" and "Corner 500sqm"). Each unit
/// type has its own count, base price, and tracked availability.
class PropertyUnitType {
  final String id;
  final String agencyId;
  final String propertyId;
  final String title;
  final String? description;
  final num? sizeSqm;
  final num basePriceNgn;
  final int totalUnits;
  final int reservedUnits;
  final int soldUnits;
  final int availableUnits;
  final int displayOrder;
  final DateTime createdAt;

  PropertyUnitType({
    required this.id,
    required this.agencyId,
    required this.propertyId,
    required this.title,
    required this.basePriceNgn,
    required this.totalUnits,
    required this.reservedUnits,
    required this.soldUnits,
    required this.availableUnits,
    required this.displayOrder,
    required this.createdAt,
    this.description,
    this.sizeSqm,
  });

  factory PropertyUnitType.fromMap(Map<String, dynamic> m) {
    final total = (m['total_units'] as num?)?.toInt() ?? 0;
    final reserved = (m['reserved_units'] as num?)?.toInt() ?? 0;
    final sold = (m['sold_units'] as num?)?.toInt() ?? 0;
    final available = (m['available_units'] as num?)?.toInt() ??
        (total - reserved - sold);

    return PropertyUnitType(
      id: m['id'] as String,
      agencyId: m['agency_id'] as String,
      propertyId: m['property_id'] as String,
      title: m['title'] as String,
      description: m['description'] as String?,
      sizeSqm: m['size_sqm'] as num?,
      basePriceNgn: m['base_price_ngn'] as num,
      totalUnits: total,
      reservedUnits: reserved,
      soldUnits: sold,
      availableUnits: available,
      displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Human-friendly summary like "Standard 300sqm · ₦5,000,000"
  String summary() {
    final size = sizeSqm != null ? ' · ${sizeSqm}sqm' : '';
    return '$title$size';
  }
}

enum InstallmentStatus { pending, paid, partial, overdue, waived }

class Installment {
  final String id;
  final String contractId;
  final int sequence;
  final DateTime dueDate;
  final num amount;
  final num amountPaid;
  final InstallmentStatus status;

  Installment({
    required this.id,
    required this.contractId,
    required this.sequence,
    required this.dueDate,
    required this.amount,
    required this.amountPaid,
    required this.status,
  });

  num get balance => amount - amountPaid;

  factory Installment.fromMap(Map<String, dynamic> m) => Installment(
    id: m['id'] as String,
    contractId: m['contract_id'] as String,
    sequence: (m['sequence'] as num).toInt(),
    dueDate: DateTime.parse(m['due_date'] as String),
    amount: m['amount_ngn'] as num,
    amountPaid: (m['amount_paid_ngn'] as num?) ?? 0,
    status: InstallmentStatus.values.firstWhere(
          (s) => s.name == m['status'],
      orElse: () => InstallmentStatus.pending,
    ),
  );
}

class ActivityEntry {
  final String id;
  final String? actorName;
  final String entityType;
  final String action;
  final String? description;
  final DateTime createdAt;

  ActivityEntry({
    required this.id,
    required this.entityType,
    required this.action,
    required this.createdAt,
    this.actorName,
    this.description,
  });

  factory ActivityEntry.fromMap(Map<String, dynamic> m) => ActivityEntry(
    id: m['id'] as String,
    entityType: m['entity_type'] as String,
    action: m['action'] as String,
    description: m['description'] as String?,
    actorName: (m['actor'] as Map?)?['full_name'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

/// Pre-computed numbers for the dashboard.
class DashboardStats {
  final int totalClients;
  final int newClientsThisMonth;
  final num revenueThisMonth;
  final double revenueChangePct;
  final int overduePayments;
  final int newOverdueToday;
  final int activeProperties;
  final int fullySoldProperties;

  const DashboardStats({
    required this.totalClients,
    required this.newClientsThisMonth,
    required this.revenueThisMonth,
    required this.revenueChangePct,
    required this.overduePayments,
    required this.newOverdueToday,
    required this.activeProperties,
    required this.fullySoldProperties,
  });

  static const empty = DashboardStats(
    totalClients: 0,
    newClientsThisMonth: 0,
    revenueThisMonth: 0,
    revenueChangePct: 0,
    overduePayments: 0,
    newOverdueToday: 0,
    activeProperties: 0,
    fullySoldProperties: 0,
  );
}

// ============= Contracts (richer than ContractSummary) =============

enum PaymentPlan { outright, monthly, quarterly, biannual, annual, custom }
enum ContractStatus { draft, pendingSignature, active, completed, cancelled, defaulted }
enum PaymentChannel {
  bankTransfer, cash, card, ussd, paystack, flutterwave, cheque, other
}

String paymentPlanToDb(PaymentPlan p) => switch (p) {
  PaymentPlan.outright => 'outright',
  PaymentPlan.monthly => 'monthly',
  PaymentPlan.quarterly => 'quarterly',
  PaymentPlan.biannual => 'biannual',
  PaymentPlan.annual => 'annual',
  PaymentPlan.custom => 'custom',
};

PaymentPlan paymentPlanFromDb(String s) => switch (s) {
  'outright' => PaymentPlan.outright,
  'quarterly' => PaymentPlan.quarterly,
  'biannual' => PaymentPlan.biannual,
  'annual' => PaymentPlan.annual,
  'custom' => PaymentPlan.custom,
  _ => PaymentPlan.monthly,
};

ContractStatus contractStatusFromDb(String s) => switch (s) {
  'draft' => ContractStatus.draft,
  'pending_signature' => ContractStatus.pendingSignature,
  'completed' => ContractStatus.completed,
  'cancelled' => ContractStatus.cancelled,
  'defaulted' => ContractStatus.defaulted,
  _ => ContractStatus.active,
};

String paymentChannelToDb(PaymentChannel c) => switch (c) {
  PaymentChannel.bankTransfer => 'bank_transfer',
  PaymentChannel.cash => 'cash',
  PaymentChannel.card => 'card',
  PaymentChannel.ussd => 'ussd',
  PaymentChannel.paystack => 'paystack',
  PaymentChannel.flutterwave => 'flutterwave',
  PaymentChannel.cheque => 'cheque',
  PaymentChannel.other => 'other',
};

String paymentChannelLabel(PaymentChannel c) => switch (c) {
  PaymentChannel.bankTransfer => 'Bank transfer',
  PaymentChannel.cash => 'Cash',
  PaymentChannel.card => 'Card',
  PaymentChannel.ussd => 'USSD',
  PaymentChannel.paystack => 'Paystack',
  PaymentChannel.flutterwave => 'Flutterwave',
  PaymentChannel.cheque => 'Cheque',
  PaymentChannel.other => 'Other',
};

class Contract {
  final String id;
  final String agencyId;
  final String contractNo;
  final String clientId;
  final String propertyId;
  final String? propertyUnitTypeId; // NEW: which unit type this contract is for
  final String? unitLabel;
  final String? agentId;
  final num totalPrice;
  final num initialDeposit;
  final PaymentPlan paymentPlan;
  final int? planMonths;
  final DateTime startDate;
  final ContractStatus status;
  final String? notes;
  final DateTime createdAt;

  Contract({
    required this.id,
    required this.agencyId,
    required this.contractNo,
    required this.clientId,
    required this.propertyId,
    required this.totalPrice,
    required this.initialDeposit,
    required this.paymentPlan,
    required this.startDate,
    required this.status,
    required this.createdAt,
    this.propertyUnitTypeId,
    this.unitLabel,
    this.agentId,
    this.planMonths,
    this.notes,
  });

  factory Contract.fromMap(Map<String, dynamic> m) => Contract(
    id: m['id'] as String,
    agencyId: m['agency_id'] as String,
    contractNo: m['contract_no'] as String,
    clientId: m['client_id'] as String,
    propertyId: m['property_id'] as String,
    propertyUnitTypeId: m['property_unit_type_id'] as String?,
    unitLabel: m['unit_label'] as String?,
    agentId: m['agent_id'] as String?,
    totalPrice: m['total_price_ngn'] as num,
    initialDeposit: (m['initial_deposit_ngn'] as num?) ?? 0,
    paymentPlan: paymentPlanFromDb(m['payment_plan'] as String),
    planMonths: (m['plan_months'] as num?)?.toInt(),
    startDate: DateTime.parse(m['start_date'] as String),
    status: contractStatusFromDb(m['status'] as String),
    notes: m['notes'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

// ============================================================
// Contract template models
// ============================================================

class ContractTemplate {
  final String id;
  final String agencyId;
  final String name;
  final String? description;
  final bool isDefault;
  final bool isActive;
  final String? customAppendixText;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContractTemplate({
    required this.id,
    required this.agencyId,
    required this.name,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.customAppendixText,
  });

  factory ContractTemplate.fromMap(Map<String, dynamic> m) => ContractTemplate(
    id: m['id'] as String,
    agencyId: m['agency_id'] as String,
    name: m['name'] as String,
    description: m['description'] as String?,
    isDefault: (m['is_default'] as bool?) ?? false,
    isActive: (m['is_active'] as bool?) ?? true,
    customAppendixText: m['custom_appendix_text'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );
}

class ContractClause {
  final String id;
  final String templateId;
  final String agencyId;
  final String sectionKey;
  final String? sectionNumber;
  final String sectionTitle;
  final int sortOrder;
  final String bodyMarkdown;
  final bool isLocked;
  final bool isHidden;
  final DateTime updatedAt;

  ContractClause({
    required this.id,
    required this.templateId,
    required this.agencyId,
    required this.sectionKey,
    required this.sectionTitle,
    required this.sortOrder,
    required this.bodyMarkdown,
    required this.isLocked,
    required this.isHidden,
    required this.updatedAt,
    this.sectionNumber,
  });

  factory ContractClause.fromMap(Map<String, dynamic> m) => ContractClause(
    id: m['id'] as String,
    templateId: m['template_id'] as String,
    agencyId: m['agency_id'] as String,
    sectionKey: m['section_key'] as String,
    sectionNumber: m['section_number'] as String?,
    sectionTitle: m['section_title'] as String,
    sortOrder: (m['sort_order'] as num).toInt(),
    bodyMarkdown: m['body_markdown'] as String,
    isLocked: (m['is_locked'] as bool?) ?? false,
    isHidden: (m['is_hidden'] as bool?) ?? false,
    updatedAt: DateTime.parse(m['updated_at'] as String),
  );

  ContractClause copyWith({
    String? bodyMarkdown,
    bool? isHidden,
    int? sortOrder,
  }) =>
      ContractClause(
        id: id,
        templateId: templateId,
        agencyId: agencyId,
        sectionKey: sectionKey,
        sectionNumber: sectionNumber,
        sectionTitle: sectionTitle,
        sortOrder: sortOrder ?? this.sortOrder,
        bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
        isLocked: isLocked,
        isHidden: isHidden ?? this.isHidden,
        updatedAt: updatedAt,
      );
}

class TemplateVariable {
  final String token;
  final String category;
  final String displayName;
  final String? description;
  final String? exampleValue;
  final int sortOrder;

  TemplateVariable({
    required this.token,
    required this.category,
    required this.displayName,
    required this.sortOrder,
    this.description,
    this.exampleValue,
  });

  factory TemplateVariable.fromMap(Map<String, dynamic> m) => TemplateVariable(
    token: m['token'] as String,
    category: m['category'] as String,
    displayName: m['display_name'] as String,
    description: m['description'] as String?,
    exampleValue: m['example_value'] as String?,
    sortOrder: (m['sort_order'] as num).toInt(),
  );

  /// Human-friendly category label
  String get categoryLabel => switch (category) {
    'vendor' => 'Vendor (Agency)',
    'purchaser' => 'Purchaser',
    'property' => 'Property',
    'contract' => 'Contract',
    'payment' => 'Payment',
    'witness' => 'Witnesses',
    'lawyer' => 'Lawyer',
    'legal' => 'Legal / Boilerplate',
    'constant' => 'Constants',
    _ => category,
  };
}

// ============================================================
// SHORTLET — Rental Listings
// ============================================================

enum CancellationPolicy { flexible, moderate, strict, nonRefundable }

CancellationPolicy cancellationPolicyFromDb(String s) => switch (s) {
  'flexible' => CancellationPolicy.flexible,
  'strict' => CancellationPolicy.strict,
  'non_refundable' => CancellationPolicy.nonRefundable,
  _ => CancellationPolicy.moderate,
};

String cancellationPolicyToDb(CancellationPolicy p) => switch (p) {
  CancellationPolicy.flexible => 'flexible',
  CancellationPolicy.moderate => 'moderate',
  CancellationPolicy.strict => 'strict',
  CancellationPolicy.nonRefundable => 'non_refundable',
};

String cancellationPolicyLabel(CancellationPolicy p) => switch (p) {
  CancellationPolicy.flexible => 'Flexible — refund up to 24h before',
  CancellationPolicy.moderate => 'Moderate — refund up to 5 days before',
  CancellationPolicy.strict => 'Strict — 50% refund up to 7 days before',
  CancellationPolicy.nonRefundable => 'Non-refundable',
};

class RentalListing {
  final String id;
  final String agencyId;
  final String propertyId;
  final String? propertyUnitTypeId; // null = whole property
  final num nightlyRateNgn;
  final num? weeklyRateNgn;
  final num? monthlyRateNgn;
  final num cleaningFeeNgn;
  final num securityDepositNgn;
  final String checkInTime;  // 'HH:MM'
  final String checkOutTime; // 'HH:MM'
  final int minNights;
  final int maxNights;
  final int maxGuests;
  final String? description;
  final List<String> amenities;
  final String? houseRulesMarkdown;
  final CancellationPolicy cancellationPolicy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RentalListing({
    required this.id,
    required this.agencyId,
    required this.propertyId,
    required this.nightlyRateNgn,
    required this.cleaningFeeNgn,
    required this.securityDepositNgn,
    required this.checkInTime,
    required this.checkOutTime,
    required this.minNights,
    required this.maxNights,
    required this.maxGuests,
    required this.amenities,
    required this.cancellationPolicy,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.propertyUnitTypeId,
    this.weeklyRateNgn,
    this.monthlyRateNgn,
    this.description,
    this.houseRulesMarkdown,
  });

  factory RentalListing.fromMap(Map<String, dynamic> m) {
    final rawAmenities = m['amenities'];
    final amenities = rawAmenities is List
        ? rawAmenities.map((e) => e.toString()).toList()
        : <String>[];

    return RentalListing(
      id: m['id'] as String,
      agencyId: m['agency_id'] as String,
      propertyId: m['property_id'] as String,
      propertyUnitTypeId: m['property_unit_type_id'] as String?,
      nightlyRateNgn: m['nightly_rate_ngn'] as num,
      weeklyRateNgn: m['weekly_rate_ngn'] as num?,
      monthlyRateNgn: m['monthly_rate_ngn'] as num?,
      cleaningFeeNgn: (m['cleaning_fee_ngn'] as num?) ?? 0,
      securityDepositNgn: (m['security_deposit_ngn'] as num?) ?? 0,
      checkInTime: (m['check_in_time'] as String?) ?? '15:00',
      checkOutTime: (m['check_out_time'] as String?) ?? '11:00',
      minNights: (m['min_nights'] as num?)?.toInt() ?? 1,
      maxNights: (m['max_nights'] as num?)?.toInt() ?? 30,
      maxGuests: (m['max_guests'] as num?)?.toInt() ?? 2,
      description: m['description'] as String?,
      amenities: amenities,
      houseRulesMarkdown: m['house_rules_markdown'] as String?,
      cancellationPolicy:
      cancellationPolicyFromDb(m['cancellation_policy'] as String? ?? 'moderate'),
      isActive: (m['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }
}

// ============================================================
// SHORTLET — Bookings
// ============================================================

enum BookingStatus {
  pending,
  confirmed,
  checkedIn,
  checkedOut,
  cancelled,
  noShow,
}

BookingStatus bookingStatusFromDb(String s) => switch (s) {
  'confirmed' => BookingStatus.confirmed,
  'checked_in' => BookingStatus.checkedIn,
  'checked_out' => BookingStatus.checkedOut,
  'cancelled' => BookingStatus.cancelled,
  'no_show' => BookingStatus.noShow,
  _ => BookingStatus.pending,
};

String bookingStatusToDb(BookingStatus s) => switch (s) {
  BookingStatus.pending => 'pending',
  BookingStatus.confirmed => 'confirmed',
  BookingStatus.checkedIn => 'checked_in',
  BookingStatus.checkedOut => 'checked_out',
  BookingStatus.cancelled => 'cancelled',
  BookingStatus.noShow => 'no_show',
};

String bookingStatusLabel(BookingStatus s) => switch (s) {
  BookingStatus.pending => 'Pending',
  BookingStatus.confirmed => 'Confirmed',
  BookingStatus.checkedIn => 'Checked in',
  BookingStatus.checkedOut => 'Checked out',
  BookingStatus.cancelled => 'Cancelled',
  BookingStatus.noShow => 'No show',
};

enum BookingPaymentStatus { unpaid, partial, paid, refunded }

BookingPaymentStatus bookingPaymentStatusFromDb(String s) => switch (s) {
  'partial' => BookingPaymentStatus.partial,
  'paid' => BookingPaymentStatus.paid,
  'refunded' => BookingPaymentStatus.refunded,
  _ => BookingPaymentStatus.unpaid,
};

String bookingPaymentStatusLabel(BookingPaymentStatus s) => switch (s) {
  BookingPaymentStatus.unpaid => 'Unpaid',
  BookingPaymentStatus.partial => 'Partial',
  BookingPaymentStatus.paid => 'Paid',
  BookingPaymentStatus.refunded => 'Refunded',
};

enum BookingSource { direct, website, walkIn, agent, phone }

BookingSource bookingSourceFromDb(String s) => switch (s) {
  'website' => BookingSource.website,
  'walk_in' => BookingSource.walkIn,
  'agent' => BookingSource.agent,
  'phone' => BookingSource.phone,
  _ => BookingSource.direct,
};

String bookingSourceToDb(BookingSource s) => switch (s) {
  BookingSource.direct => 'direct',
  BookingSource.website => 'website',
  BookingSource.walkIn => 'walk_in',
  BookingSource.agent => 'agent',
  BookingSource.phone => 'phone',
};

String bookingSourceLabel(BookingSource s) => switch (s) {
  BookingSource.direct => 'Direct',
  BookingSource.website => 'Website',
  BookingSource.walkIn => 'Walk-in',
  BookingSource.agent => 'Agent referral',
  BookingSource.phone => 'Phone call',
};

/// Full booking record from the bookings_overview view
class BookingOverview {
  final String id;
  final String bookingNo;
  final BookingStatus status;
  final BookingPaymentStatus paymentStatus;
  final BookingSource source;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int nights;
  final int guestsCount;
  final num totalNgn;
  final num amountPaidNgn;
  final num balanceNgn;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final DateTime createdAt;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String? clientEmail;
  final String propertyId;
  final String propertyTitle;
  final String propertyLocation;
  final String? unitTypeId;
  final String? unitTitle;
  final String? agentId;
  final String? agentName;

  BookingOverview({
    required this.id,
    required this.bookingNo,
    required this.status,
    required this.paymentStatus,
    required this.source,
    required this.checkInDate,
    required this.checkOutDate,
    required this.nights,
    required this.guestsCount,
    required this.totalNgn,
    required this.amountPaidNgn,
    required this.balanceNgn,
    required this.createdAt,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyLocation,
    this.checkedInAt,
    this.checkedOutAt,
    this.clientEmail,
    this.unitTypeId,
    this.unitTitle,
    this.agentId,
    this.agentName,
  });

  factory BookingOverview.fromMap(Map<String, dynamic> m) => BookingOverview(
    id: m['id'] as String,
    bookingNo: m['booking_no'] as String,
    status: bookingStatusFromDb(m['status'] as String),
    paymentStatus:
    bookingPaymentStatusFromDb(m['payment_status'] as String),
    source: bookingSourceFromDb(m['source'] as String),
    checkInDate: DateTime.parse(m['check_in_date'] as String),
    checkOutDate: DateTime.parse(m['check_out_date'] as String),
    nights: (m['nights'] as num).toInt(),
    guestsCount: (m['guests_count'] as num).toInt(),
    totalNgn: m['total_ngn'] as num,
    amountPaidNgn: (m['amount_paid_ngn'] as num?) ?? 0,
    balanceNgn: (m['balance_ngn'] as num?) ?? 0,
    checkedInAt: m['checked_in_at'] != null
        ? DateTime.parse(m['checked_in_at'] as String)
        : null,
    checkedOutAt: m['checked_out_at'] != null
        ? DateTime.parse(m['checked_out_at'] as String)
        : null,
    createdAt: DateTime.parse(m['created_at'] as String),
    clientId: m['client_id'] as String,
    clientName: m['client_name'] as String,
    clientPhone: m['client_phone'] as String,
    clientEmail: m['client_email'] as String?,
    propertyId: m['property_id'] as String,
    propertyTitle: m['property_title'] as String,
    propertyLocation: m['property_location'] as String,
    unitTypeId: m['unit_type_id'] as String?,
    unitTitle: m['unit_title'] as String?,
    agentId: m['agent_id'] as String?,
    agentName: m['agent_name'] as String?,
  );

  /// "Mr Adebayo — Plot 12, Lekki · 3 nights"
  String summary() {
    final unit = unitTitle != null ? ' ($unitTitle)' : '';
    return '$clientName — $propertyTitle$unit · $nights night${nights == 1 ? '' : 's'}';
  }
}

/// Lightweight booking range used by the calendar
class BookedRange {
  final String bookingId;
  final String bookingNo;
  final String clientName;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final BookingStatus status;

  BookedRange({
    required this.bookingId,
    required this.bookingNo,
    required this.clientName,
    required this.checkInDate,
    required this.checkOutDate,
    required this.status,
  });

  factory BookedRange.fromMap(Map<String, dynamic> m) => BookedRange(
    bookingId: m['booking_id'] as String,
    bookingNo: m['booking_no'] as String,
    clientName: m['client_name'] as String,
    checkInDate: DateTime.parse(m['check_in_date'] as String),
    checkOutDate: DateTime.parse(m['check_out_date'] as String),
    status: bookingStatusFromDb(m['status'] as String),
  );
}