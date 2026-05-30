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