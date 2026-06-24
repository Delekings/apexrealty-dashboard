// lib/data/repositories/expenses_repository.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/supabase_service.dart';

/// Fixed, app-enforced expense categories (stored as text on the row).
/// Keep this list stable — the P&L report groups on these exact strings.
const kExpenseCategories = <String>[
  'Rent',
  'Salaries & wages',
  'Utilities',
  'Marketing & advertising',
  'Legal & professional fees',
  'Transport & fuel',
  'Office supplies',
  'Agent commissions',
  'Taxes & levies',
  'Repairs & maintenance',
  'Bank charges',
  'Other',
];

class Expense {
  final String id;
  final String agencyId;
  final String category;
  final num amountNgn;
  final DateTime spentOn;
  final String? payee;
  final String? notes;

  /// Storage path of the receipt inside the payment-receipts bucket
  /// (NOT a public URL — fetch a signed URL with [ExpensesRepository.receiptSignedUrl]).
  final String? receiptUrl;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.agencyId,
    required this.category,
    required this.amountNgn,
    required this.spentOn,
    required this.createdAt,
    this.payee,
    this.notes,
    this.receiptUrl,
  });

  bool get hasReceipt => receiptUrl != null && receiptUrl!.isNotEmpty;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        agencyId: m['agency_id'] as String,
        category: m['category'] as String,
        amountNgn: (m['amount_ngn'] as num?) ?? 0,
        spentOn: DateTime.parse(m['spent_on'] as String),
        payee: m['payee'] as String?,
        notes: m['notes'] as String?,
        receiptUrl: m['receipt_url'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class ExpensesRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Reuse the existing private receipts bucket; expense receipts live under
  /// the `<agency_id>/expenses/` prefix so they share the agency-scoped policy.
  static const _receiptBucket = 'payment-receipts';
  static const _uuid = Uuid();

  Future<String?> _myAgencyId() async {
    final userId = _c.auth.currentUser?.id;
    if (userId == null) return null;
    final r = await _c
        .from('profiles')
        .select('agency_id')
        .eq('id', userId)
        .maybeSingle();
    return r?['agency_id'] as String?;
  }

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Receipts
  // ---------------------------------------------------------------------------

  String _ext(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot == -1) return 'bin';
    return filename.substring(dot + 1).toLowerCase();
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads receipt bytes and returns the storage path to save on the row.
  Future<String> uploadReceipt({
    required Uint8List bytes,
    required String filename,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');
    final ext = _ext(filename);
    final path = '$agencyId/expenses/${_uuid.v4()}.$ext';
    await _c.storage.from(_receiptBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _mimeFor(ext), upsert: false),
        );
    return path;
  }

  /// A short-lived signed URL for viewing a receipt (1 hour).
  Future<String> receiptSignedUrl(String path) async {
    return _c.storage.from(_receiptBucket).createSignedUrl(path, 3600);
  }

  Future<void> deleteReceipt(String path) async {
    await _c.storage.from(_receiptBucket).remove([path]);
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Expenses for the caller's agency, newest spend first. Optional date-range
  /// and category filters (used by later slices / the P&L report).
  Future<List<Expense>> list({
    DateTime? from,
    DateTime? to,
    String? category,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];

    var q = _c.from('expenses').select().eq('agency_id', agencyId);
    if (from != null) q = q.gte('spent_on', _d(from));
    if (to != null) q = q.lte('spent_on', _d(to));
    if (category != null) q = q.eq('category', category);

    final rows = await q.order('spent_on', ascending: false);
    return (rows as List)
        .map((r) => Expense.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Expense> create({
    required String category,
    required num amountNgn,
    required DateTime spentOn,
    String? payee,
    String? notes,
    String? receiptUrl,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');

    final row = await _c
        .from('expenses')
        .insert({
          'agency_id': agencyId,
          'recorded_by': _c.auth.currentUser?.id,
          'category': category,
          'amount_ngn': amountNgn,
          'spent_on': _d(spentOn),
          'payee': (payee == null || payee.trim().isEmpty) ? null : payee.trim(),
          'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
          'receipt_url': receiptUrl,
        })
        .select()
        .single();
    return Expense.fromMap(row);
  }

  Future<Expense> update(
    String id, {
    String? category,
    num? amountNgn,
    DateTime? spentOn,
    String? payee,
    String? notes,
    String? receiptUrl,
    bool clearReceipt = false,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (category != null) patch['category'] = category;
    if (amountNgn != null) patch['amount_ngn'] = amountNgn;
    if (spentOn != null) patch['spent_on'] = _d(spentOn);
    if (payee != null) {
      patch['payee'] = payee.trim().isEmpty ? null : payee.trim();
    }
    if (notes != null) {
      patch['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }
    if (clearReceipt) {
      patch['receipt_url'] = null;
    } else if (receiptUrl != null) {
      patch['receipt_url'] = receiptUrl;
    }

    final row = await _c
        .from('expenses')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Expense.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _c.from('expenses').delete().eq('id', id);
  }
}
