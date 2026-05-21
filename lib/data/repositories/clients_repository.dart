// lib/data/repositories/clients_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

/// All client-related database operations.
///
/// Every method relies on Supabase RLS to scope rows to the caller's agency,
/// so we never have to pass agency_id explicitly when reading.
class ClientsRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Paginated list with optional text search and agent filter.
  Future<ClientsPage> list({
    String? search,
    String? agentId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Start with the base select.
    var filterQuery = _c.from('clients').select('''
          *,
          agent:profiles!assigned_agent_id(id, full_name)
        ''');

    // Apply filters BEFORE ordering / ranging.
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      filterQuery = filterQuery.or(
        'full_name.ilike.%$s%,phone.ilike.%$s%,email.ilike.%$s%',
      );
    }
    if (agentId != null) {
      filterQuery = filterQuery.eq('assigned_agent_id', agentId);
    }

    // Get total count for the same filters.
    final total = await _buildCountQuery(search: search, agentId: agentId);

    // Now order and range.
    final rows = await filterQuery
        .order('created_at', ascending: false)
        .range(from, to);

    return ClientsPage(
      items: (rows as List)
          .map((r) => ClientListItem.fromMap(r as Map<String, dynamic>))
          .toList(),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<int> _buildCountQuery({String? search, String? agentId}) async {
    var q = _c.from('clients').select('id');
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      q = q.or('full_name.ilike.%$s%,phone.ilike.%$s%,email.ilike.%$s%');
    }
    if (agentId != null) {
      q = q.eq('assigned_agent_id', agentId);
    }
    final res = await q.count(CountOption.exact);
    return res.count;
  }

  /// Fetch a single client with their contracts, recent payments, and activity.
  Future<ClientDetail> getDetail(String id) async {
    final clientRow = await _c.from('clients').select('''
          *,
          agent:profiles!assigned_agent_id(id, full_name)
        ''').eq('id', id).single();

    final contracts = await _c
        .from('contracts')
        .select('*, property:properties(title, location)')
        .eq('client_id', id)
        .order('created_at', ascending: false);

    final contractIds =
    (contracts as List).map((r) => r['id'] as String).toList();

    final payments = contractIds.isEmpty
        ? <dynamic>[]
        : await _c
        .from('payments')
        .select('*, contract:contracts(contract_no)')
        .inFilter('contract_id', contractIds)
        .order('paid_at', ascending: false)
        .limit(20);

    final activity = await _c
        .from('activity_log')
        .select('*, actor:profiles(full_name)')
        .eq('entity_id', id)
        .order('created_at', ascending: false)
        .limit(20);

    return ClientDetail(
      client: Client.fromMap(clientRow),
      contracts: contracts
          .map((r) => ContractSummary.fromMap(r as Map<String, dynamic>))
          .toList(),
      recentPayments: (payments as List)
          .map((r) => PaymentSummary.fromMap(r as Map<String, dynamic>))
          .toList(),
      activity: (activity as List)
          .map((r) => ActivityEntry.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Create a new client. agency_id is filled in by a database trigger
  /// (or we set it here from the current profile — see below).
  Future<String> create({
    required String agencyId,
    required String fullName,
    required String phone,
    String? email,
    String? state,
    String? occupation,
    String? bvn,
    String? nin,
    String? address,
    String? nextOfKinName,
    String? nextOfKinPhone,
    String? assignedAgentId,
    String? notes,
  }) async {
    final res = await _c
        .from('clients')
        .insert({
      'agency_id': agencyId,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (state != null) 'state': state,
      if (occupation != null && occupation.trim().isNotEmpty)
        'occupation': occupation.trim(),
      if (bvn != null && bvn.trim().isNotEmpty) 'bvn': bvn.trim(),
      if (nin != null && nin.trim().isNotEmpty) 'nin': nin.trim(),
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
      if (nextOfKinName != null && nextOfKinName.trim().isNotEmpty)
        'next_of_kin_name': nextOfKinName.trim(),
      if (nextOfKinPhone != null && nextOfKinPhone.trim().isNotEmpty)
        'next_of_kin_phone': nextOfKinPhone.trim(),
      if (assignedAgentId != null) 'assigned_agent_id': assignedAgentId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    })
        .select('id')
        .single();

    final newId = res['id'] as String;

    // Log to activity feed
    await _c.from('activity_log').insert({
      'agency_id': agencyId,
      'entity_type': 'client',
      'entity_id': newId,
      'action': 'created',
      'description': '$fullName onboarded',
    });

    return newId;
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _c.from('clients').update(patch).eq('id', id);
  }
  /// Lightweight list of all clients in the agency, for picker dropdowns.
  Future<List<ClientListItem>> listAllForPicker() async {
    final rows = await _c
        .from('clients')
        .select('''
          *,
          agent:profiles!assigned_agent_id(id, full_name)
        ''')
        .order('full_name')
        .limit(500);
    return (rows as List)
        .map((r) => ClientListItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }
  /// Fetch the list of agents in the current agency (for dropdowns).
  Future<List<Profile>> listAgents() async {
    final rows = await _c
        .from('profiles')
        .select()
        .eq('is_active', true)
        .inFilter('role', ['agent', 'manager', 'agency_admin'])
        .order('full_name');
    return (rows as List).map((r) => Profile.fromMap(r)).toList();
  }
}

// --- Auxiliary types used by the repository ---

class ClientsPage {
  final List<ClientListItem> items;
  final int total;
  final int page;
  final int pageSize;
  ClientsPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  int get totalPages =>
      pageSize == 0 ? 0 : (total / pageSize).ceil().clamp(0, 1 << 30);
  bool get hasNext => (page + 1) < totalPages;
  bool get hasPrev => page > 0;
}

class ClientListItem {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? state;
  final String? agentName;
  final DateTime createdAt;

  ClientListItem({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.createdAt,
    this.email,
    this.state,
    this.agentName,
  });

  factory ClientListItem.fromMap(Map<String, dynamic> m) => ClientListItem(
    id: m['id'] as String,
    fullName: m['full_name'] as String,
    phone: m['phone'] as String,
    email: m['email'] as String?,
    state: m['state'] as String?,
    agentName: (m['agent'] as Map?)?['full_name'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class ClientDetail {
  final Client client;
  final List<ContractSummary> contracts;
  final List<PaymentSummary> recentPayments;
  final List<ActivityEntry> activity;
  ClientDetail({
    required this.client,
    required this.contracts,
    required this.recentPayments,
    required this.activity,
  });
}

class ContractSummary {
  final String id;
  final String contractNo;
  final String? propertyTitle;
  final String? propertyLocation;
  final num totalPrice;
  final String status;
  final DateTime startDate;

  ContractSummary({
    required this.id,
    required this.contractNo,
    required this.totalPrice,
    required this.status,
    required this.startDate,
    this.propertyTitle,
    this.propertyLocation,
  });

  factory ContractSummary.fromMap(Map<String, dynamic> m) => ContractSummary(
    id: m['id'] as String,
    contractNo: m['contract_no'] as String,
    propertyTitle: (m['property'] as Map?)?['title'] as String?,
    propertyLocation: (m['property'] as Map?)?['location'] as String?,
    totalPrice: m['total_price_ngn'] as num,
    status: m['status'] as String,
    startDate: DateTime.parse(m['start_date'] as String),
  );
}

class PaymentSummary {
  final String id;
  final String? contractNo;
  final num amount;
  final String channel;
  final DateTime paidAt;

  PaymentSummary({
    required this.id,
    required this.amount,
    required this.channel,
    required this.paidAt,
    this.contractNo,
  });

  factory PaymentSummary.fromMap(Map<String, dynamic> m) => PaymentSummary(
    id: m['id'] as String,
    contractNo: (m['contract'] as Map?)?['contract_no'] as String?,
    amount: m['amount_ngn'] as num,
    channel: m['channel'] as String,
    paidAt: DateTime.parse(m['paid_at'] as String),
  );
}