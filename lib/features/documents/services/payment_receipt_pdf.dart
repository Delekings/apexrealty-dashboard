// lib/features/documents/services/payment_receipt_pdf.dart

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'sale_agreement_pdf.dart' show DirectorSignature;

class PaymentReceiptInput {
  // Agency
  final String agencyName;
  final String? agencyRcNumber;
  final String? agencyAddress;
  final Uint8List? agencyLogoBytes;

  // Receipt
  final String receiptNo;
  final DateTime issuedOn;

  // Client
  final String clientFullName;
  final String? clientPhone;
  final String? clientEmail;
  final String? clientAddress;

  // Payment details
  final num amountNgn;
  final String channel; // cash | bank_transfer | pos | cheque | card | ussd
  final String? reference;
  final String? notes;

  // Contract context
  final String contractNo;
  final String propertyTitle;
  final String? unitLabel;
  final String? installmentLabel; // e.g. "Installment 3 of 12"

  // Running totals
  final num totalContractPriceNgn;
  final num totalPaidToDateNgn;

  // Issuer
  // Issuer
  final String agencyRepName;
  final String? agencyRepTitle;

  // Receipt branding (Phase 3 — pre-embedded director signature + common seal)
  final DirectorSignature? receiptSigner;
  final Uint8List? commonSealImage;
  final String receiptBlockStyle; // 'director_only' | 'seal_only' | 'director_and_seal'

  PaymentReceiptInput({
    required this.agencyName,
    this.agencyRcNumber,
    this.agencyAddress,
    this.agencyLogoBytes,
    required this.receiptNo,
    required this.issuedOn,
    required this.clientFullName,
    this.clientPhone,
    this.clientEmail,
    this.clientAddress,
    required this.amountNgn,
    required this.channel,
    this.reference,
    this.notes,
    required this.contractNo,
    required this.propertyTitle,
    this.unitLabel,
    this.installmentLabel,
    required this.totalContractPriceNgn,
    required this.totalPaidToDateNgn,
    required this.agencyRepName,
    this.agencyRepTitle,
    this.receiptSigner,
    this.commonSealImage,
    this.receiptBlockStyle = 'director_only',
  });

  num get remainingBalance =>
      (totalContractPriceNgn - totalPaidToDateNgn).clamp(0, double.infinity);
}

class PaymentReceiptPdf {
  static final _nairaFormat = NumberFormat('#,##0.00', 'en_NG');
  static final _dateFmt = DateFormat('d MMMM yyyy');

  static Future<Uint8List> build(PaymentReceiptInput i) async {
    final doc = pw.Document(
      title: 'Receipt ${i.receiptNo}',
      author: i.agencyName,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ----- Header -----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(i.agencyName,
                          style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold)),
                      if (i.agencyRcNumber != null)
                        pw.Text('RC: ${i.agencyRcNumber}',
                            style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700)),
                      if (i.agencyAddress != null)
                        pw.Text(i.agencyAddress!,
                            style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('PAYMENT RECEIPT',
                        style: pw.TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(i.receiptNo,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('Issued ${_dateFmt.format(i.issuedOn)}',
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Container(height: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 16),

            // ----- RECEIVED FROM -----
            pw.Text('RECEIVED FROM',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.0,
                    color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(i.clientFullName,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold)),
            if (i.clientPhone != null && i.clientPhone!.isNotEmpty)
              pw.Text('Phone: ${i.clientPhone}',
                  style: const pw.TextStyle(fontSize: 10)),
            if (i.clientEmail != null && i.clientEmail!.isNotEmpty)
              pw.Text('Email: ${i.clientEmail}',
                  style: const pw.TextStyle(fontSize: 10)),

            pw.SizedBox(height: 18),

            // ----- AMOUNT (big green box) -----
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F0F7F2'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(
                    color: PdfColor.fromHex('#1A5C38'), width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('AMOUNT RECEIVED',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.0,
                          color: PdfColor.fromHex('#1A5C38'))),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'NGN ${_nairaFormat.format(i.amountNgn)}',
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1A5C38')),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _amountInWords(i.amountNgn),
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey800),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // ----- Payment details (2 columns) -----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _section('PAYMENT FOR'),
                      _kv('Contract', i.contractNo),
                      _kv('Property', _propertyLine(i)),
                      if (i.installmentLabel != null)
                        _kv('Allocation', i.installmentLabel!),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _section('PAYMENT METHOD'),
                      _kv('Channel', _channelLabel(i.channel)),
                      if (i.reference != null && i.reference!.isNotEmpty)
                        _kv('Reference', i.reference!),
                      if (i.notes != null && i.notes!.isNotEmpty)
                        _kv('Notes', i.notes!),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // ----- Running balance -----
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: _balanceCell(
                        'CONTRACT TOTAL', i.totalContractPriceNgn),
                  ),
                  pw.Expanded(
                    child: _balanceCell(
                        'TOTAL PAID TO DATE', i.totalPaidToDateNgn),
                  ),
                  pw.Expanded(
                    child: _balanceCell(
                      'REMAINING',
                      i.remainingBalance,
                      emphasize: true,
                      complete: i.remainingBalance == 0,
                    ),
                  ),
                ],
              ),
            ),

            // ----- Fixed spacing before signature (no Spacer) -----
            pw.SizedBox(height: 60),

            // ----- Signature line -----
            // ----- Signature block (conditional based on receipt_block_style) -----
            _buildReceiptSignatureBlock(i),

            pw.SizedBox(height: 16),

            // ----- Footer -----
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(
                      color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Center(
                child: pw.Text(
                  'This is a system-generated receipt — Generated by Lintel',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return await doc.save();
  }

  // ---------- helpers ----------

  static String _propertyLine(PaymentReceiptInput i) {
    if (i.unitLabel != null && i.unitLabel!.isNotEmpty) {
      return '${i.propertyTitle} (${i.unitLabel})';
    }
    return i.propertyTitle;
  }

  static pw.Widget _section(String label) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(label,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.0,
            color: PdfColors.grey700)),
  );

  static pw.Widget _kv(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text('$k:',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(v,
              style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );

  static pw.Widget _balanceCell(String label, num amount,
      {bool emphasize = false, bool complete = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700)),
        pw.Text(
          'NGN ${_nairaFormat.format(amount)}',
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
              color:
              complete ? PdfColor.fromHex('#1A5C38') : PdfColors.grey900),
        ),
      ],
    );
  }

  static String _channelLabel(String ch) => switch (ch) {
    'cash' => 'Cash',
    'bank_transfer' => 'Bank Transfer',
    'pos' => 'POS / Card',
    'card' => 'Card',
    'cheque' => 'Cheque',
    'ussd' => 'USSD',
    'paystack' => 'Paystack',
    'flutterwave' => 'Flutterwave',
    _ => ch,
  };

  static String _amountInWords(num n) {
    final int whole = n.floor();
    final int kobo = ((n - whole) * 100).round();

    final words = _numberToWords(whole);
    final wordsCapitalized = words.isEmpty
        ? 'Zero'
        : '${words[0].toUpperCase()}${words.substring(1)}';

    if (kobo > 0) {
      final koboWords = _numberToWords(kobo);
      return '$wordsCapitalized Naira and $koboWords Kobo only';
    }
    return '$wordsCapitalized Naira only';
  }

  static String _numberToWords(int n) {
    if (n == 0) return 'zero';
    const ones = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
      'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen',
      'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty',
      'sixty', 'seventy', 'eighty', 'ninety'
    ];

    String belowThousand(int x) {
      if (x == 0) return '';
      if (x < 20) return ones[x];
      if (x < 100) {
        final t = tens[x ~/ 10];
        final o = x % 10;
        return o == 0 ? t : '$t ${ones[o]}';
      }
      final hundreds = ones[x ~/ 100];
      final remainder = x % 100;
      if (remainder == 0) return '$hundreds hundred';
      return '$hundreds hundred and ${belowThousand(remainder)}';
    }

    final billion = n ~/ 1000000000;
    final million = (n ~/ 1000000) % 1000;
    final thousand = (n ~/ 1000) % 1000;
    final rest = n % 1000;

    final parts = <String>[];
    if (billion > 0) parts.add('${belowThousand(billion)} billion');
    if (million > 0) parts.add('${belowThousand(million)} million');
    if (thousand > 0) parts.add('${belowThousand(thousand)} thousand');
    if (rest > 0) parts.add(belowThousand(rest));
    return parts.join(' ').trim();
  }

  /// Renders the signature/branding block at the bottom of the receipt,
  /// based on the agency's receipt_block_style setting:
  ///   - 'director_only'      → director signature + name + "DIRECTOR" label
  ///   - 'seal_only'          → common seal image only
  ///   - 'director_and_seal'  → director on the left, seal on the right
  ///
  /// Falls back to a blank signature line + agencyRepName when no receipt
  /// signer is configured and the style includes the director.
  static pw.Widget _buildReceiptSignatureBlock(PaymentReceiptInput i) {
    final style = i.receiptBlockStyle;
    final showSigner = style == 'director_only' || style == 'director_and_seal';
    final showSeal = style == 'seal_only' || style == 'director_and_seal';

    pw.MemoryImage? sigImg;
    if (i.receiptSigner != null) {
      sigImg = pw.MemoryImage(i.receiptSigner!.imageBytes);
    }

    pw.MemoryImage? sealImg;
    if (i.commonSealImage != null) {
      sealImg = pw.MemoryImage(i.commonSealImage!);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (showSigner)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (sigImg != null)
                  pw.Container(
                    height: 40,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(sigImg, height: 40),
                  )
                else
                  pw.Container(
                    height: 40,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                            color: PdfColors.grey600, width: 0.5),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  (i.receiptSigner?.name ?? i.agencyRepName).toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('DIRECTOR',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700)),
                pw.Text('For: ${i.agencyName}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        if (showSeal)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: showSigner
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'COMMON SEAL',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                if (sealImg != null)
                  pw.Container(
                    height: 60,
                    alignment: showSigner
                        ? pw.Alignment.centerRight
                        : pw.Alignment.centerLeft,
                    child: pw.Image(sealImg, height: 60),
                  ),
              ],
            ),
          ),
        if (showSigner && !showSeal) pw.Expanded(child: pw.Container()),
        if (showSeal && !showSigner) pw.Expanded(child: pw.Container()),
      ],
    );
  }
}