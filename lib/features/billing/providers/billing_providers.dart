// lib/features/billing/providers/billing_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../data/services/supabase_service.dart';

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class BillingPlan {
  final String code;
  final String name;
  final int priceNaira;
  final int? maxUsers; // null = unlimited
  final int? maxClients;
  final int? maxProperties;
  final List<String> features;
  final String? flutterwavePlanId;

  const BillingPlan({
    required this.code,
    required this.name,
    required this.priceNaira,
    this.maxUsers,
    this.maxClients,
    this.maxProperties,
    this.features = const [],
    this.flutterwavePlanId,
  });

  factory BillingPlan.fromMap(Map<String, dynamic> m) => BillingPlan(
        code: m['code'] as String,
        name: m['name'] as String,
        priceNaira: (m['price_naira'] as num?)?.toInt() ?? 0,
        maxUsers: (m['max_users'] as num?)?.toInt(),
        maxClients: (m['max_clients'] as num?)?.toInt(),
        maxProperties: (m['max_properties'] as num?)?.toInt(),
        features: ((m['features'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        flutterwavePlanId: m['flutterwave_plan_id'] as String?,
      );

  bool get isFree => priceNaira <= 0;
  bool has(String feature) => features.contains(feature);
}

class AgencySubscription {
  final String planCode;
  final String status; // trialing | active | past_due | canceled
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final BillingPlan? plan;

  const AgencySubscription({
    required this.planCode,
    required this.status,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.plan,
  });

  factory AgencySubscription.fromMap(Map<String, dynamic> m) {
    final planRaw = m['plan'];
    return AgencySubscription(
      planCode: m['plan_code'] as String? ?? 'free',
      status: m['status'] as String? ?? 'active',
      trialEndsAt: _dt(m['trial_ends_at']),
      currentPeriodEnd: _dt(m['current_period_end']),
      cancelAtPeriodEnd: m['cancel_at_period_end'] as bool? ?? false,
      plan: planRaw is Map
          ? BillingPlan.fromMap(Map<String, dynamic>.from(planRaw))
          : null,
    );
  }

  bool get isTrialing => status == 'trialing';
  bool get isActive => status == 'active';
  bool get isPastDue => status == 'past_due';

  int get trialDaysLeft {
    if (trialEndsAt == null) return 0;
    final hrs = trialEndsAt!.difference(DateTime.now()).inHours;
    final d = (hrs / 24).ceil();
    return d < 0 ? 0 : d;
  }
}

class BillingUsage {
  final int users;
  final int clients;
  final int properties;
  const BillingUsage(
      {required this.users, required this.clients, required this.properties});
}

class BillingTxn {
  final String? planCode;
  final int amountNaira;
  final String status; // pending | successful | failed
  final DateTime? paidAt;
  final DateTime? createdAt;

  const BillingTxn({
    this.planCode,
    required this.amountNaira,
    required this.status,
    this.paidAt,
    this.createdAt,
  });

  factory BillingTxn.fromMap(Map<String, dynamic> m) => BillingTxn(
        planCode: m['plan_code'] as String?,
        amountNaira: (m['amount_naira'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? 'pending',
        paidAt: _dt(m['paid_at']),
        createdAt: _dt(m['created_at']),
      );
}

/// The current agency's subscription, with its plan embedded. RLS scopes this
/// to the caller's own agency, so a bare select returns the single right row.
final subscriptionProvider = FutureProvider<AgencySubscription?>((ref) async {
  final row = await SupabaseService.client
      .from('subscriptions')
      .select('*, plan:plans(*)')
      .maybeSingle();
  if (row == null) return null;
  return AgencySubscription.fromMap(Map<String, dynamic>.from(row));
});

final plansProvider = FutureProvider<List<BillingPlan>>((ref) async {
  final rows = await SupabaseService.client
      .from('plans')
      .select('*')
      .eq('is_active', true)
      .order('sort_order');
  return (rows as List)
      .map((e) => BillingPlan.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

final usageProvider = FutureProvider<BillingUsage>((ref) async {
  final c = SupabaseService.client;
  final u = await c.from('profiles').select('id').count(CountOption.exact);
  final cl = await c.from('clients').select('id').count(CountOption.exact);
  final pr = await c.from('properties').select('id').count(CountOption.exact);
  return BillingUsage(users: u.count, clients: cl.count, properties: pr.count);
});

final billingHistoryProvider = FutureProvider<List<BillingTxn>>((ref) async {
  final rows = await SupabaseService.client
      .from('billing_transactions')
      .select('plan_code, amount_naira, status, paid_at, created_at')
      .order('created_at', ascending: false)
      .limit(10);
  return (rows as List)
      .map((e) => BillingTxn.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

final billingRepositoryProvider = Provider((_) => BillingRepository());

class BillingRepository {
  /// Starts a Flutterwave checkout for [planCode] and returns the payment link.
  Future<String> checkout(String planCode) async {
    final res = await SupabaseService.client.functions.invoke(
      'billing-checkout',
      body: {'planCode': planCode},
    );
    final data = res.data;
    if (data is Map && data['ok'] == true && data['link'] is String) {
      return data['link'] as String;
    }
    final err = (data is Map ? data['error'] : null) ?? 'Could not start checkout';
    throw Exception(err.toString());
  }
}
