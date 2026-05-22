// lib/features/documents/services/sale_agreement_pdf.dart
//
// Generates a sale agreement PDF for a contract. The agency's
// signature is embedded immediately (it's already saved). Client
// and witness slots are blank — they get filled in later as each
// party signs.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SaleAgreementInput {
  // Agency
  final String agencyName;
  final String? agencyRcNumber;
  final String agencyAddress;
  final String? agencyLogoBytesOrNull; // ignored for now; we put text header
  final Uint8List? agencySignatureImage; // PNG bytes
  final String agencySignerName;
  final String? agencySignerTitle;

  // Client signature (filled in after they sign)
  final Uint8List? clientSignatureImage;
  final String? clientSignedAtDisplay; // e.g. "21 May 2026"

// Vendor witness (filled in after they sign)
  final Uint8List? vendorWitnessSignatureImage;
  final String? vendorWitnessSignedAtDisplay;

// Buyer witness (filled in after they sign)
  final Uint8List? buyerWitnessSignatureImage;
  final String? buyerWitnessSignedAtDisplay;

  // Client
  final String clientFullName;
  final String? clientAddress;
  final String clientPhone;
  final String? clientEmail;

  // Property
  final String propertyTitle;
  final String propertyLocation;
  final String propertyState;
  final String propertyLga;
  final num? propertySizeSqm;
  final String? unitLabel; // e.g. "Plot 12"

  // Contract
  final String contractNo;
  final num totalPriceNgn;
  final num? initialDeposit;
  final String paymentPlanLabel; // human-readable
  final int? planMonths;
  final DateTime startDate;
  final DateTime agreementDate;

  // Witnesses (filled-in details get printed; signatures stay blank
  // until they actually sign through their own portals)
  final String vendorWitnessName;
  final String? vendorWitnessOccupation;
  final String? vendorWitnessAddress;

  final String? buyerWitnessName; // may be blank — buyer fills it
  final String? buyerWitnessOccupation;
  final String? buyerWitnessAddress;

  SaleAgreementInput({
    this.clientSignatureImage,
    this.clientSignedAtDisplay,
    this.vendorWitnessSignatureImage,
    this.vendorWitnessSignedAtDisplay,
    this.buyerWitnessSignatureImage,
    this.buyerWitnessSignedAtDisplay,
    required this.agencyName,
    this.agencyRcNumber,
    required this.agencyAddress,
    this.agencyLogoBytesOrNull,
    this.agencySignatureImage,
    required this.agencySignerName,
    this.agencySignerTitle,
    required this.clientFullName,
    this.clientAddress,
    required this.clientPhone,
    this.clientEmail,
    required this.propertyTitle,
    required this.propertyLocation,
    required this.propertyState,
    required this.propertyLga,
    this.propertySizeSqm,
    this.unitLabel,
    required this.contractNo,
    required this.totalPriceNgn,
    this.initialDeposit,
    required this.paymentPlanLabel,
    this.planMonths,
    required this.startDate,
    required this.agreementDate,
    required this.vendorWitnessName,
    this.vendorWitnessOccupation,
    this.vendorWitnessAddress,
    this.buyerWitnessName,
    this.buyerWitnessOccupation,
    this.buyerWitnessAddress,
  });
}

class SaleAgreementPdf {
  static final _money = NumberFormat('#,##0', 'en_NG');
  static final _date = DateFormat('d MMMM, yyyy');
  /// Builds the final fully-signed PDF: same content, all signatures
  /// embedded, plus an audit page at the end.
  static Future<Uint8List> buildSignedWithAudit({
    required SaleAgreementInput input,
    required List<SignerAuditInfo> auditEntries,
  }) async {
    final doc = pw.Document(
      title: 'Sale Agreement (signed) - ${input.contractNo}',
      author: input.agencyName,
    );

    pw.MemoryImage? agencySig;
    if (input.agencySignatureImage != null) {
      agencySig = pw.MemoryImage(input.agencySignatureImage!);
    }

    // Main agreement pages (same as unsigned, but signatures now embedded)
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        header: (_) => _header(input),
        footer: (ctx) => _footer(ctx, input),
        build: (_) => [
          _title(input),
          pw.SizedBox(height: 18),
          _parties(input),
          pw.SizedBox(height: 14),
          _recitals(input),
          pw.SizedBox(height: 14),
          _heading('1. Property'),
          _propertyBlock(input),
          pw.SizedBox(height: 10),
          _heading('2. Purchase Price'),
          _priceBlock(input),
          pw.SizedBox(height: 10),
          _heading('3. Payment Plan'),
          _planBlock(input),
          pw.SizedBox(height: 10),
          _heading('4. Title & Transfer'),
          _paragraph(
              'Upon full payment of the Purchase Price stated in Clause 2 above, '
                  'the Vendor shall execute and deliver to the Purchaser all '
                  'documents required to vest legal title to the Property in the '
                  'Purchaser, including but not limited to a Deed of Assignment '
                  'and any registrable instrument required under the Land Use '
                  'Act of Nigeria.'),
          pw.SizedBox(height: 10),
          _heading('5. Default'),
          _paragraph(
              'In the event that the Purchaser defaults on any scheduled '
                  'installment and fails to remedy such default within thirty '
                  '(30) days of written notice from the Vendor, the Vendor may '
                  'at its sole discretion terminate this Agreement and refund '
                  'the Purchaser any amounts already paid less an administrative '
                  'charge not exceeding ten percent (10%) of the total amounts '
                  'received.'),
          pw.SizedBox(height: 10),
          _heading('6. Force Majeure'),
          _paragraph(
              'Neither party shall be liable for any failure or delay in '
                  'performance under this Agreement due to events outside the '
                  'reasonable control of the party, including but not limited '
                  'to acts of God, governmental orders, civil unrest, '
                  'pandemics, or natural disasters.'),
          pw.SizedBox(height: 10),
          _heading('7. Governing Law'),
          _paragraph(
              'This Agreement shall be governed by and construed in '
                  'accordance with the laws of the Federal Republic of Nigeria. '
                  'Any dispute arising out of or in connection with this '
                  'Agreement shall be referred to the courts of ${input.propertyState} State.'),
          pw.SizedBox(height: 22),
          _signatureBlocks(input, agencySig),
          pw.SizedBox(height: 16),
          _witnessBlocks(input),
        ],
      ),
    );

    // Audit page
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        header: (_) => _header(input),
        footer: (ctx) => _footer(ctx, input),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.Text('SIGNATURE AUDIT TRAIL',
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 4),
          pw.Text(
            'The following parties electronically signed this document. Each '
                'signature is associated with an audit record below.',
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          for (final entry in auditEntries) _auditEntry(entry),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('About this audit trail',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800)),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Each signatory verified their identity via a one-time code '
                      'sent to their email address before signing. Signatures were '
                      'recorded with timestamps and the IP address used to access '
                      'the signing portal. This document was prepared and '
                      'distributed via Lintel, an electronic signature platform.',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return await doc.save();
  }

  static pw.Widget _auditEntry(SignerAuditInfo e) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1A5C38'),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(e.role.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
              pw.SizedBox(width: 8),
              pw.Text(e.name,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 4),
          if (e.email != null) _auditKv('Email', e.email!),
          _auditKv('Signature method', e.method),
          _auditKv(
              'Signed at',
              DateFormat('d MMMM yyyy, HH:mm:ss').format(e.signedAt.toLocal())),
          if (e.otpVerifiedAt != null)
            _auditKv(
                'OTP verified at',
                DateFormat('d MMMM yyyy, HH:mm:ss')
                    .format(e.otpVerifiedAt!.toLocal())),
          if (e.ip != null && e.ip!.isNotEmpty)
            _auditKv('IP address', e.ip!),
        ],
      ),
    );
  }

  static pw.Widget _auditKv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(k,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(v,
                style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  /// Builds the unsigned-but-agency-signed PDF. Returns the bytes.
  static Future<Uint8List> build(SaleAgreementInput i) async {
    final doc = pw.Document(
      title: 'Sale Agreement - ${i.contractNo}',
      author: i.agencyName,
    );

    pw.MemoryImage? agencySig;
    if (i.agencySignatureImage != null) {
      agencySig = pw.MemoryImage(i.agencySignatureImage!);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
        header: (_) => _header(i),
        footer: (ctx) => _footer(ctx, i),
        build: (_) => [
          _title(i),
          pw.SizedBox(height: 18),
          _parties(i),
          pw.SizedBox(height: 14),
          _recitals(i),
          pw.SizedBox(height: 14),
          _heading('1. Property'),
          _propertyBlock(i),
          pw.SizedBox(height: 10),
          _heading('2. Purchase Price'),
          _priceBlock(i),
          pw.SizedBox(height: 10),
          _heading('3. Payment Plan'),
          _planBlock(i),
          pw.SizedBox(height: 10),
          _heading('4. Title & Transfer'),
          _paragraph(
              'Upon full payment of the Purchase Price stated in Clause 2 above, '
                  'the Vendor shall execute and deliver to the Purchaser all '
                  'documents required to vest legal title to the Property in the '
                  'Purchaser, including but not limited to a Deed of Assignment '
                  'and any registrable instrument required under the Land Use '
                  'Act of Nigeria.'),
          pw.SizedBox(height: 10),
          _heading('5. Default'),
          _paragraph(
              'In the event that the Purchaser defaults on any scheduled '
                  'installment and fails to remedy such default within thirty '
                  '(30) days of written notice from the Vendor, the Vendor may '
                  'at its sole discretion terminate this Agreement and refund '
                  'the Purchaser any amounts already paid less an administrative '
                  'charge not exceeding ten percent (10%) of the total amounts '
                  'received.'),
          pw.SizedBox(height: 10),
          _heading('6. Force Majeure'),
          _paragraph(
              'Neither party shall be liable for any failure or delay in '
                  'performance under this Agreement due to events outside the '
                  'reasonable control of the party, including but not limited '
                  'to acts of God, governmental orders, civil unrest, '
                  'pandemics, or natural disasters.'),
          pw.SizedBox(height: 10),
          _heading('7. Governing Law'),
          _paragraph(
              'This Agreement shall be governed by and construed in '
                  'accordance with the laws of the Federal Republic of Nigeria. '
                  'Any dispute arising out of or in connection with this '
                  'Agreement shall be referred to the courts of ${i.propertyState} State.'),
          pw.SizedBox(height: 22),
          _signatureBlocks(i, agencySig),
          pw.SizedBox(height: 16),
          _witnessBlocks(i),
        ],
      ),
    );

    return await doc.save();
  }

  // ------------ Layout helpers ------------

  static pw.Widget _header(SaleAgreementInput i) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(i.agencyName,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              if (i.agencyRcNumber != null && i.agencyRcNumber!.isNotEmpty)
                pw.Text('RC ${i.agencyRcNumber}',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('CONTRACT REF',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
              pw.Text(i.contractNo,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx, SaleAgreementInput i) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Lintel · ${_date.format(i.agreementDate)}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _title(SaleAgreementInput i) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text('SALE AGREEMENT',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5,
              )),
          pw.SizedBox(height: 4),
          pw.Text(
            'Made on this ${_dayOrdinal(i.agreementDate.day)} day of '
                '${DateFormat('MMMM').format(i.agreementDate)}, ${i.agreementDate.year}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _parties(SaleAgreementInput i) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _partyLine('VENDOR', i.agencyName,
              line2: i.agencyAddress,
              line3: i.agencyRcNumber != null
                  ? 'RC ${i.agencyRcNumber}'
                  : null),
          pw.SizedBox(height: 8),
          _partyLine('PURCHASER', i.clientFullName,
              line2: i.clientAddress,
              line3: 'Phone: ${i.clientPhone}'),
        ],
      ),
    );
  }

  static pw.Widget _partyLine(String label, String name,
      {String? line2, String? line3}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(name,
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold)),
        if (line2 != null && line2.isNotEmpty)
          pw.Text(line2, style: const pw.TextStyle(fontSize: 9)),
        if (line3 != null && line3.isNotEmpty)
          pw.Text(line3,
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _recitals(SaleAgreementInput i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _heading('WHEREAS'),
        _paragraph(
            'The Vendor is the lawful owner of the property described herein '
                'and is desirous of selling the same;'),
        _paragraph(
            'The Purchaser has agreed to buy the property under the terms '
                'and conditions set out in this Agreement;'),
        _paragraph(
            'NOW THIS AGREEMENT WITNESSETH as follows:'),
      ],
    );
  }

  static pw.Widget _propertyBlock(SaleAgreementInput i) {
    final size = i.propertySizeSqm != null
        ? '${_money.format(i.propertySizeSqm)} sqm'
        : 'Approx.';
    return _paragraph(
      'The property is described as "${i.propertyTitle}", '
          '${i.unitLabel != null ? "(${i.unitLabel}) " : ""}'
          'situate at ${i.propertyLocation}, ${i.propertyLga} LGA, '
          '${i.propertyState} State, measuring $size, '
          '(hereinafter referred to as "the Property").',
    );
  }

  static pw.Widget _priceBlock(SaleAgreementInput i) {
    final deposit = i.initialDeposit != null && i.initialDeposit! > 0
        ? '. An initial deposit of NGN ${_money.format(i.initialDeposit)} '
        'has been paid by the Purchaser, the receipt of which the Vendor '
        'hereby acknowledges.'
        : '.';
    return _paragraph(
      'The total purchase price of the Property is '
          'NGN ${_money.format(i.totalPriceNgn)} '
          '(${_inWords(i.totalPriceNgn)}) Naira only$deposit',
    );
  }

  static pw.Widget _planBlock(SaleAgreementInput i) {
    final months = i.planMonths != null
        ? ' over ${i.planMonths} installment${i.planMonths == 1 ? "" : "s"}'
        : '';
    return _paragraph(
      'The Purchaser shall pay the balance of the purchase price under a '
          '${i.paymentPlanLabel} payment plan$months, commencing on '
          '${_date.format(i.startDate)}. Time is of the essence in respect of '
          'all payments due under this Agreement.',
    );
  }

  static pw.Widget _signatureBlocks(
      SaleAgreementInput i, pw.MemoryImage? agencySig) {
    pw.MemoryImage? clientSig;
    if (i.clientSignatureImage != null) {
      clientSig = pw.MemoryImage(i.clientSignatureImage!);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // VENDOR side
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SIGNED BY THE VENDOR',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 6),
              if (agencySig != null)
                pw.Container(
                  height: 50,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(agencySig, height: 50),
                )
              else
                pw.Container(
                  height: 50,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom:
                      pw.BorderSide(color: PdfColors.grey600, width: 0.5),
                    ),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(i.agencySignerName,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              if (i.agencySignerTitle != null)
                pw.Text(i.agencySignerTitle!,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              pw.Text('For: ${i.agencyName}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Date: ${_date.format(i.agreementDate)}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        // PURCHASER side
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SIGNED BY THE PURCHASER',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 6),
              if (clientSig != null)
                pw.Container(
                  height: 50,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(clientSig, height: 50),
                )
              else
                pw.Container(
                  height: 50,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom:
                      pw.BorderSide(color: PdfColors.grey600, width: 0.5),
                    ),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(i.clientFullName,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Phone: ${i.clientPhone}',
                  style: const pw.TextStyle(fontSize: 9)),
              if (i.clientEmail != null && i.clientEmail!.isNotEmpty)
                pw.Text('Email: ${i.clientEmail}',
                    style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                'Date: ${i.clientSignedAtDisplay ?? "____________________"}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _witnessBlocks(SaleAgreementInput i) {
    pw.MemoryImage? vendorSig;
    pw.MemoryImage? buyerSig;
    if (i.vendorWitnessSignatureImage != null) {
      vendorSig = pw.MemoryImage(i.vendorWitnessSignatureImage!);
    }
    if (i.buyerWitnessSignatureImage != null) {
      buyerSig = pw.MemoryImage(i.buyerWitnessSignatureImage!);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('IN THE PRESENCE OF:',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _witnessBlock(
                  heading: "Vendor's Witness",
                  name: i.vendorWitnessName,
                  occupation: i.vendorWitnessOccupation,
                  address: i.vendorWitnessAddress,
                  signature: vendorSig,
                  signedDate: i.vendorWitnessSignedAtDisplay,
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: _witnessBlock(
                  heading: "Purchaser's Witness",
                  name: i.buyerWitnessName ?? '____________________',
                  occupation: i.buyerWitnessOccupation,
                  address: i.buyerWitnessAddress,
                  signature: buyerSig,
                  signedDate: i.buyerWitnessSignedAtDisplay,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _witnessBlock({
    required String heading,
    required String name,
    String? occupation,
    String? address,
    pw.MemoryImage? signature,
    String? signedDate,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(heading,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        if (signature != null)
          pw.Container(
            height: 40,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(signature, height: 40),
          )
        else
          pw.Container(
            height: 40,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
              ),
            ),
          ),
        pw.SizedBox(height: 4),
        _kv('Name:', name),
        _kv('Occupation:', occupation ?? '____________________'),
        _kv('Address:', address ?? '____________________'),
        _kv('Date:', signedDate ?? '____________________'),
      ],
    );
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 56,
          child: pw.Text(k,
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(v,
              style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  static pw.Widget _heading(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  static pw.Widget _paragraph(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(text,
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
    );
  }

  static String _dayOrdinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  // Simple amount-in-words for amounts up to a few billion naira.
  // Handles whole numbers only (no kobo).
  static String _inWords(num amount) {
    final n = amount.toInt();
    if (n == 0) return 'Zero';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
      'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen',
      'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
      'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String belowHundred(int x) {
      if (x < 20) return units[x];
      final t = x ~/ 10;
      final u = x % 10;
      return tens[t] + (u > 0 ? ' ${units[u]}' : '');
    }

    String belowThousand(int x) {
      final h = x ~/ 100;
      final r = x % 100;
      final hPart = h > 0 ? '${units[h]} Hundred' : '';
      final rPart = r > 0 ? belowHundred(r) : '';
      if (hPart.isNotEmpty && rPart.isNotEmpty) return '$hPart and $rPart';
      return hPart + rPart;
    }

    final parts = <String>[];
    final billion = n ~/ 1000000000;
    final million = (n % 1000000000) ~/ 1000000;
    final thousand = (n % 1000000) ~/ 1000;
    final rest = n % 1000;

    if (billion > 0) parts.add('${belowThousand(billion)} Billion');
    if (million > 0) parts.add('${belowThousand(million)} Million');
    if (thousand > 0) parts.add('${belowThousand(thousand)} Thousand');
    if (rest > 0) parts.add(belowThousand(rest));

    return parts.join(' ');
  }
}


class SignerAuditInfo {
  final String role;            // 'Agency', 'Purchaser', 'Vendor witness', 'Buyer witness'
  final String name;
  final String? email;
  final String method;          // 'drawn' | 'typed' | 'uploaded'
  final DateTime signedAt;
  final String? ip;
  final DateTime? otpVerifiedAt;

  SignerAuditInfo({
    required this.role,
    required this.name,
    this.email,
    required this.method,
    required this.signedAt,
    this.ip,
    this.otpVerifiedAt,
  });
}

