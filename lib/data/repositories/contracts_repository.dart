// lib/data/repositories/contracts_repository.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../../features/documents/services/payment_receipt_pdf.dart';

class GeneratedReceipt {
  final String path;
  final String receiptNo;
  GeneratedReceipt({required this.path, required this.receiptNo});
}

class ContractsRepository {
  final SupabaseClient _c = SupabaseService.client;
  static const _uuid = Uuid();

  // ============================================================
  // Receipts
  // ============================================================

  Future<GeneratedReceipt> generateAndUploadReceipt({
    required String paymentId,
    required String agencyId,
  }) async {
    // 1. Fetch payment with all related data
    final payment = await _c.from('payments').select('''
    *,
    contract:contracts(
      id, contract_no, total_price_ngn,
      property:properties(title),
      client:clients(full_name, phone, email, address)
    ),
    installment:installments(sequence)
  ''').eq('id', paymentId).single();

    // Count total installments for this contract (for the label)
    final allInstallments = await _c
        .from('installments')
        .select('id')
        .eq('contract_id', payment['contract_id']);
    final totalInstallments = (allInstallments as List).length;

    // 2. Total paid to date for this contract
    final paid = await _c
        .from('payments')
        .select('amount_ngn')
        .eq('contract_id', payment['contract_id']);
    final totalPaid = (paid as List).fold<num>(
        0, (sum, p) => sum + (p['amount_ngn'] as num));

    // 3. Agency info
    final agency = await _c
        .from('agencies')
        .select('name, rc_number, address')
        .eq('id', agencyId)
        .single();

    // 4. Profile of the actor (the one recording the payment)
    final profile = await _c
        .from('profiles')
        .select('full_name, title')
        .eq('id', SupabaseService.client.auth.currentUser!.id)
        .single();

    // 5. Build inputs
    final contract = payment['contract'] as Map<String, dynamic>;
    final property = contract['property'] as Map<String, dynamic>;
    final client = contract['client'] as Map<String, dynamic>;
    final installment = payment['installment'] as Map<String, dynamic>?;

    String? installmentLabel;
    if (installment != null) {
      installmentLabel =
      'Installment ${installment['sequence']} of $totalInstallments';
    }

    final receiptNo = payment['receipt_no'] as String;

    final input = PaymentReceiptInput(
      agencyName: agency['name'] as String,
      agencyRcNumber: agency['rc_number'] as String?,
      agencyAddress: agency['address'] as String?,
      receiptNo: receiptNo,
      issuedOn: DateTime.parse(payment['created_at'] as String),
      clientFullName: client['full_name'] as String,
      clientPhone: client['phone'] as String?,
      clientEmail: client['email'] as String?,
      clientAddress: client['address'] as String?,
      amountNgn: payment['amount_ngn'] as num,
      channel: payment['channel'] as String,
      reference: payment['reference'] as String?,
      notes: payment['notes'] as String?,
      contractNo: contract['contract_no'] as String,
      propertyTitle: property['title'] as String,
      installmentLabel: installmentLabel,
      totalContractPriceNgn: contract['total_price_ngn'] as num,
      totalPaidToDateNgn: totalPaid,
      agencyRepName: profile['full_name'] as String,
      agencyRepTitle: profile['title'] as String?,
    );

    // 6. Generate PDF
    final pdfBytes = await PaymentReceiptPdf.build(input);

    // 7. Upload to storage
    final filename =
        '${receiptNo}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = '$agencyId/$filename';
    await _c.storage.from('payment-receipts').uploadBinary(
      path,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );

    // 8. Save the path on the payment row
    await _c
        .from('payments')
        .update({'receipt_pdf_path': path}).eq('id', paymentId);

    return GeneratedReceipt(path: path, receiptNo: receiptNo);
  }

  Future<String> receiptUrl(String storagePath) async {
    return await _c.storage
        .from('payment-receipts')
        .createSignedUrl(storagePath, 3600);
  }

  // ============================================================
  // Contracts
  // ============================================================

  /// Create a contract + generate installment schedule + reserve a unit,
  /// all atomically via an RPC. Returns the new contract id.
  ///
  /// [propertyUnitTypeId] is required — every contract must point to a
  /// specific unit type so we can decrement that type's availability.
  Future<String> create({
    required String clientId,
    required String propertyId,
    required String propertyUnitTypeId,
    String? unitLabel,
    String? agentId,
    required num totalPrice,
    required num initialDeposit,
    required PaymentPlan paymentPlan,
    required int? planMonths,
    required DateTime startDate,
    String? notes,
  }) async {
    final res = await _c.rpc('create_contract_with_schedule', params: {
      'p_client_id': clientId,
      'p_property_id': propertyId,
      'p_property_unit_type_id': propertyUnitTypeId,
      'p_unit_label': unitLabel,
      'p_agent_id': agentId,
      'p_total_price': totalPrice,
      'p_initial_deposit': initialDeposit,
      'p_payment_plan': paymentPlanToDb(paymentPlan),
      'p_plan_months': planMonths,
      'p_start_date':
      '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      'p_notes': notes,
    });
    return res as String;
  }

  Future<ContractDetail> getDetail(String id) async {
    final c = await _c.from('contracts').select('''
          *,
          client:clients(id, full_name, phone, email, address),
          property:properties(id, title, location, state, lga, size_sqm, cover_image_url),
          unit_type:property_unit_types(id, title, size_sqm, base_price_ngn),
          agent:profiles!agent_id(id, full_name),
          agency:agencies(id, name, rc_number, address)
        ''').eq('id', id).single();

    final installments = await _c
        .from('installments')
        .select()
        .eq('contract_id', id)
        .order('sequence');

    final payments = await _c
        .from('payments')
        .select()
        .eq('contract_id', id)
        .order('paid_at', ascending: false);

    return ContractDetail(
      contract: Contract.fromMap(c),

      // Client
      clientName: (c['client'] as Map?)?['full_name'] as String? ?? '—',
      clientPhone: (c['client'] as Map?)?['phone'] as String? ?? '',
      clientEmail: (c['client'] as Map?)?['email'] as String?,
      clientAddress: (c['client'] as Map?)?['address'] as String?,

      // Property
      propertyTitle: (c['property'] as Map?)?['title'] as String? ?? '—',
      propertyLocation: (c['property'] as Map?)?['location'] as String? ?? '',
      propertyState: (c['property'] as Map?)?['state'] as String? ?? '',
      propertyLga: (c['property'] as Map?)?['lga'] as String?,
      propertySizeSqm: (c['property'] as Map?)?['size_sqm'] as num?,
      propertyCoverUrl:
      (c['property'] as Map?)?['cover_image_url'] as String?,

      // Unit type
      unitTypeTitle: (c['unit_type'] as Map?)?['title'] as String?,
      unitTypeSizeSqm: (c['unit_type'] as Map?)?['size_sqm'] as num?,

      // Agent
      agentName: (c['agent'] as Map?)?['full_name'] as String?,

      // Agency (for PDF generation)
      agencyName: (c['agency'] as Map?)?['name'] as String?,
      agencyRcNumber: (c['agency'] as Map?)?['rc_number'] as String?,
      agencyAddress: (c['agency'] as Map?)?['address'] as String?,

      installments: (installments as List)
          .map((r) => Installment.fromMap(r as Map<String, dynamic>))
          .toList(),
      payments: (payments as List)
          .map((r) => PaymentRecord.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<ContractListItem>> listByAgency({String? status}) async {
    var q = _c.from('contracts').select('''
          *,
          client:clients(full_name),
          property:properties(title)
        ''');
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('created_at', ascending: false).limit(200);
    return (rows as List)
        .map((r) => ContractListItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // Payments
  // ============================================================

  /// Record a manual payment via the SQL function.
  Future<String> recordManualPayment({
    required String contractId,
    String? installmentId,
    required num amount,
    required PaymentChannel channel,
    required DateTime paidAt,
    String? reference,
    String? notes,
    Uint8List? receiptBytes,
    String? receiptFilename,
    required String agencyId,
  }) async {
    String? receiptUrl;
    if (receiptBytes != null && receiptFilename != null) {
      final ext = receiptFilename.contains('.')
          ? receiptFilename
          .substring(receiptFilename.lastIndexOf('.') + 1)
          .toLowerCase()
          : 'jpg';
      final path = '$agencyId/$contractId/${_uuid.v4()}.$ext';

      await _c.storage.from('payment-receipts').uploadBinary(
        path,
        receiptBytes,
        fileOptions: FileOptions(contentType: _mime(ext)),
      );
      receiptUrl = path;
    }

    final id = await _c.rpc('record_manual_payment', params: {
      'p_contract_id': contractId,
      'p_installment_id': installmentId,
      'p_amount': amount,
      'p_channel': paymentChannelToDb(channel),
      'p_paid_at': paidAt.toIso8601String(),
      'p_reference': reference,
      'p_notes': notes,
      'p_receipt_url': receiptUrl,
    });
    return id as String;
  }

  /// Generate a temporary signed URL to view a receipt screenshot.
  Future<String> signedReceiptUrl(String storagePath) async {
    final res = await _c.storage
        .from('payment-receipts')
        .createSignedUrl(storagePath, 3600); // 1 hour
    return res;
  }

  String _mime(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}

// ============================================================
// Auxiliary types
// ============================================================

class ContractDetail {
  final Contract contract;

  // Client
  final String clientName;
  final String clientPhone;
  final String? clientEmail;
  final String? clientAddress;

  // Property
  final String propertyTitle;
  final String propertyLocation;
  final String propertyState;
  final String? propertyLga;
  final num? propertySizeSqm;
  final String? propertyCoverUrl;

  // Unit type (multi-unit inventory)
  final String? unitTypeTitle;
  final num? unitTypeSizeSqm;

  // Agent
  final String? agentName;

  // Agency (for PDF generation)
  final String? agencyName;
  final String? agencyRcNumber;
  final String? agencyAddress;

  final List<Installment> installments;
  final List<PaymentRecord> payments;

  ContractDetail({
    required this.contract,
    required this.clientName,
    required this.clientPhone,
    required this.propertyTitle,
    required this.propertyLocation,
    required this.propertyState,
    required this.installments,
    required this.payments,
    this.clientEmail,
    this.clientAddress,
    this.propertyLga,
    this.propertySizeSqm,
    this.propertyCoverUrl,
    this.unitTypeTitle,
    this.unitTypeSizeSqm,
    this.agentName,
    this.agencyName,
    this.agencyRcNumber,
    this.agencyAddress,
  });

  num get totalPaid =>
      installments.fold<num>(0, (s, i) => s + i.amountPaid);
  num get totalBalance =>
      installments.fold<num>(0, (s, i) => s + i.balance);
  double get progressFraction {
    final total = contract.totalPrice;
    if (total == 0) return 0;
    return (totalPaid / total).clamp(0, 1).toDouble();
  }
}

class ContractListItem {
  final String id;
  final String contractNo;
  final String? clientName;
  final String? propertyTitle;
  final num totalPrice;
  final ContractStatus status;
  final DateTime createdAt;

  ContractListItem({
    required this.id,
    required this.contractNo,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.clientName,
    this.propertyTitle,
  });

  factory ContractListItem.fromMap(Map<String, dynamic> m) =>
      ContractListItem(
        id: m['id'] as String,
        contractNo: m['contract_no'] as String,
        clientName: (m['client'] as Map?)?['full_name'] as String?,
        propertyTitle: (m['property'] as Map?)?['title'] as String?,
        totalPrice: m['total_price_ngn'] as num,
        status: contractStatusFromDb(m['status'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class PaymentRecord {
  final String id;
  final String? installmentId;
  final num amount;
  final PaymentChannel channel;
  final String? reference;
  final DateTime paidAt;
  final String? receiptUrl;
  final String? notes;
  final String? receiptNo;
  final String? receiptPdfPath;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.channel,
    required this.paidAt,
    this.installmentId,
    this.reference,
    this.receiptUrl,
    this.notes,
    this.receiptNo,
    this.receiptPdfPath,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> m) => PaymentRecord(
    id: m['id'] as String,
    installmentId: m['installment_id'] as String?,
    amount: m['amount_ngn'] as num,
    channel: _channelFromDb(m['channel'] as String),
    reference: m['reference'] as String?,
    paidAt: DateTime.parse(m['paid_at'] as String),
    receiptUrl: m['receipt_url'] as String?,
    notes: m['notes'] as String?,
    receiptNo: m['receipt_no'] as String?,
    receiptPdfPath: m['receipt_pdf_path'] as String?,
  );

  static PaymentChannel _channelFromDb(String s) => switch (s) {
    'bank_transfer' => PaymentChannel.bankTransfer,
    'cash' => PaymentChannel.cash,
    'card' => PaymentChannel.card,
    'ussd' => PaymentChannel.ussd,
    'paystack' => PaymentChannel.paystack,
    'flutterwave' => PaymentChannel.flutterwave,
    'cheque' => PaymentChannel.cheque,
    _ => PaymentChannel.other,
  };
}