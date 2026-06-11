// lib/features/documents/services/sale_agreement_pdf.dart
//
// Hearthhaven-style Nigerian Contract of Sale of Land generator.
// Renders clauses from the agency's configurable template
// (lib/data/services/contract_template_renderer.dart) and produces
// a 10-page formal legal document.
//
// Public API kept identical to the previous version so existing call
// sites continue to compile:
//   SaleAgreementPdf.build(SaleAgreementInput)
//   SaleAgreementPdf.buildSignedWithAudit({input, auditEntries})

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/models/models.dart';
import '../../../data/repositories/contract_templates_repository.dart';
import '../../../data/services/contract_template_renderer.dart';


class SaleAgreementInput {
  // NEW — needed by the template-driven generator
  final String contractId;

  // Agency
  final String agencyName;
  final String? agencyRcNumber;
  final String agencyAddress;
  final String? agencyLogoBytesOrNull;
  final Uint8List? agencySignatureImage;
  final String agencySignerName;
  final String? agencySignerTitle;

  // Client signature (filled in after they sign)
  final Uint8List? clientSignatureImage;
  final String? clientSignedAtDisplay;

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
  final String? unitLabel;

  // Contract
  final String contractNo;
  final num totalPriceNgn;
  final num? initialDeposit;
  final String paymentPlanLabel;
  final int? planMonths;
  final DateTime startDate;
  final DateTime agreementDate;

  // Witnesses
  final String? buyerWitnessName;
  final String? buyerWitnessOccupation;
  final String? buyerWitnessAddress;

  // Vendor block (Phase 3 — pre-embedded director signatures + common seal)
  final DirectorSignature? primaryDirector;
  final DirectorSignature? secondaryDirector;
  final Uint8List? commonSealImage;
  final String vendorBlockStyle; // 'directors_only' | 'seal_only' | 'directors_and_seal'

  SaleAgreementInput({
    required this.contractId,
    required this.agencyName,
    this.agencyRcNumber,
    required this.agencyAddress,
    this.agencyLogoBytesOrNull,
    this.agencySignatureImage,
    required this.agencySignerName,
    this.agencySignerTitle,
    this.clientSignatureImage,
    this.clientSignedAtDisplay,
    this.buyerWitnessSignatureImage,
    this.buyerWitnessSignedAtDisplay,
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
    this.buyerWitnessName,
    this.buyerWitnessOccupation,
    this.buyerWitnessAddress,
    this.primaryDirector,
    this.secondaryDirector,
    this.commonSealImage,
    this.vendorBlockStyle = 'directors_only',
  });
}

/// A director's signature for embedding in the contract vendor block.
class DirectorSignature {
  final String name;
  final Uint8List imageBytes;
  const DirectorSignature({required this.name, required this.imageBytes});
}

/// One signer's audit metadata for the final signed PDF.
class SignerAuditInfo {
  final String role;
  final String name;
  final String? email;
  final String method;
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

class SaleAgreementPdf {
  static final _money = NumberFormat('#,##0', 'en_NG');
  static final _date = DateFormat('d MMMM yyyy');

  /// Unsigned (agency-only) PDF. The new template-driven version.
  static Future<Uint8List> build(SaleAgreementInput i) async {
    final loaded = await _loadTemplateAndContext(i);
    final clauses = loaded.clauses;
    final customAppendix = loaded.customAppendix;
    final ctx = loaded.ctx;
    final doc = pw.Document(
      title: 'Contract of Sale of Land — ${i.contractNo}',
      author: i.agencyName,
    );

    pw.MemoryImage? agencySig;
    if (i.agencySignatureImage != null) {
      agencySig = pw.MemoryImage(i.agencySignatureImage!);
    }
    pw.MemoryImage? primarySig;
    pw.MemoryImage? secondarySig;
    pw.MemoryImage? sealImg;
    if (i.primaryDirector != null) {
      primarySig = pw.MemoryImage(i.primaryDirector!.imageBytes);
    }
    if (i.secondaryDirector != null) {
      secondarySig = pw.MemoryImage(i.secondaryDirector!.imageBytes);
    }
    if (i.commonSealImage != null) {
      sealImg = pw.MemoryImage(i.commonSealImage!);
    }

    // ---- Cover page ----
    doc.addPage(_coverPage(i, ctx));

    // ---- Main body: parties, recitals, clauses, schedules ----
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 56),
        footer: (c) => _footer(c, i),
        build: (_) => [
          ..._renderClauses(clauses, ctx),
          if (customAppendix != null && customAppendix.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionHeader(null, 'ADDITIONAL TERMS'),
            _justified(
                ContractTemplateRenderer.render(customAppendix, ctx)),
          ],
          pw.SizedBox(height: 18),
          _firstSchedule(i, ctx),
          pw.SizedBox(height: 18),
          _secondSchedule(i, ctx),
          pw.SizedBox(height: 24),
          _signatureBlocks(
            i, agencySig, null, null,
            primaryDirectorSig: primarySig,
            secondaryDirectorSig: secondarySig,
            sealImage: sealImg,
          ),
        ],
      ),
    );

    return await doc.save();
  }

  /// Fully-signed PDF with embedded signatures + audit page.
  static Future<Uint8List> buildSignedWithAudit({
    required SaleAgreementInput input,
    required List<SignerAuditInfo> auditEntries,
  }) async {
    final loaded = await _loadTemplateAndContext(input);
    final clauses = loaded.clauses;
    final customAppendix = loaded.customAppendix;
    final ctx = loaded.ctx;

    final doc = pw.Document(
      title: 'Contract of Sale of Land (signed) — ${input.contractNo}',
      author: input.agencyName,
    );

    pw.MemoryImage? agencySig;
    pw.MemoryImage? clientSig;
    pw.MemoryImage? buyerWitSig;

    if (input.agencySignatureImage != null) {
      agencySig = pw.MemoryImage(input.agencySignatureImage!);
    }
    if (input.clientSignatureImage != null) {
      clientSig = pw.MemoryImage(input.clientSignatureImage!);
    }
    if (input.buyerWitnessSignatureImage != null) {
      buyerWitSig = pw.MemoryImage(input.buyerWitnessSignatureImage!);
    }
    pw.MemoryImage? primarySig;
    pw.MemoryImage? secondarySig;
    pw.MemoryImage? sealImg;
    if (input.primaryDirector != null) {
      primarySig = pw.MemoryImage(input.primaryDirector!.imageBytes);
    }
    if (input.secondaryDirector != null) {
      secondarySig = pw.MemoryImage(input.secondaryDirector!.imageBytes);
    }
    if (input.commonSealImage != null) {
      sealImg = pw.MemoryImage(input.commonSealImage!);
    }

    // Cover
    doc.addPage(_coverPage(input, ctx));

    // Body
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 56),
        footer: (c) => _footer(c, input),
        build: (_) => [
          ..._renderClauses(clauses, ctx),
          if (customAppendix != null && customAppendix.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _sectionHeader(null, 'ADDITIONAL TERMS'),
            _justified(
                ContractTemplateRenderer.render(customAppendix, ctx)),
          ],
          pw.SizedBox(height: 18),
          _firstSchedule(input, ctx),
          pw.SizedBox(height: 18),
          _secondSchedule(input, ctx),
          pw.SizedBox(height: 24),
          _signatureBlocks(
            input, agencySig, clientSig, buyerWitSig,
            primaryDirectorSig: primarySig,
            secondaryDirectorSig: secondarySig,
            sealImage: sealImg,
          ),
          pw.SizedBox(height: 18),
          _preparedBy(ctx),
        ],
      ),
    );

    // Audit page
    doc.addPage(_auditPage(input, auditEntries));

    return await doc.save();
  }

  // ============================================================
  // Template loading
  // ============================================================

  static Future<_LoadedTemplate> _loadTemplateAndContext(
      SaleAgreementInput i) async {
    final repo = ContractTemplatesRepository();
    final ctx = await repo.buildRenderContext(i.contractId);

    // Prefer snapshot if available (frozen clauses for a contract sent for signature)
    final snapshot = await repo.getSnapshot(i.contractId);

    List<ContractClause> sourceClauses;
    String? appendix;

    if (snapshot != null) {
      sourceClauses = snapshot.clauses;
      appendix = snapshot.appendix;
    } else {
      final tpl = await repo.getDefault();
      sourceClauses = tpl.clauses.where((c) => !c.isHidden).toList();
      appendix = tpl.template.customAppendixText;
    }

    final clauses = sourceClauses
        .map((c) => _RenderableClause(
      number: c.sectionNumber,
      title: c.sectionTitle,
      body: ContractTemplateRenderer.render(c.bodyMarkdown, ctx),
      sectionKey: c.sectionKey,
    ))
        .toList();

    return _LoadedTemplate(
      clauses: clauses,
      customAppendix: appendix,
      ctx: ctx,
    );
  }

  // ============================================================
  // Cover page (Hearthhaven-style)
  // ============================================================

  static pw.Page _coverPage(SaleAgreementInput i, ContractRenderContext ctx) {
    final vendor = (ctx.agency['name'] as String?) ?? i.agencyName;
    final purchaser = i.clientFullName.toUpperCase();
    final fullDesc =
    ContractTemplateRenderer.render('{{property_full_legal_description}}', ctx);
    final dateLine =
        'DATED THIS ${_ordinal(i.agreementDate.day).toUpperCase()} DAY OF '
        '${DateFormat('MMMM yyyy').format(i.agreementDate).toUpperCase()}.';

    final lawyerName = ctx.agency['lawyer_name'] as String?;
    final lawyerFirm = ctx.agency['lawyer_firm'] as String?;
    final lawyerAddress = ctx.agency['lawyer_address'] as String?;
    final lawyerEmail = ctx.agency['lawyer_email'] as String?;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(64, 80, 64, 56),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 40),
          pw.Text('CONTRACT OF SALE OF LAND',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 30),
          pw.Text('BETWEEN',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          pw.Text(vendor.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('(VENDOR)',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          pw.Text('AND',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          pw.Text(purchaser,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('(PURCHASER)',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 18),
          pw.Text('IN RESPECT OF:',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Container(
              width: 380,
              child: pw.Divider(
                  color: PdfColors.grey800, thickness: 0.6)),
          pw.SizedBox(height: 12),
          pw.Container(
            constraints: const pw.BoxConstraints(maxWidth: 440),
            child: pw.Text(
              fullDesc,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.3),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
              width: 380,
              child: pw.Divider(
                  color: PdfColors.grey800, thickness: 0.6)),
          pw.SizedBox(height: 30),
          pw.Text(dateLine,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
          // Prepared by section pinned-ish to bottom
          pw.SizedBox(height: 60),
          if (lawyerName != null && lawyerName.isNotEmpty)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('PREPARED BY',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text(lawyerName,
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                  if (lawyerFirm != null && lawyerFirm.isNotEmpty)
                    pw.Text(lawyerFirm,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold)),
                  pw.Text('(Attorneys-at-Law)',
                      style: const pw.TextStyle(fontSize: 10)),
                  if (lawyerAddress != null && lawyerAddress.isNotEmpty)
                    pw.Container(
                      width: 180,
                      child: pw.Text(lawyerAddress,
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey800)),
                    ),
                  if (lawyerEmail != null && lawyerEmail.isNotEmpty)
                    pw.Text(lawyerEmail,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Clause rendering
  // ============================================================

  static List<pw.Widget> _renderClauses(
      List<_RenderableClause> clauses,
      ContractRenderContext ctx,
      ) {
    final widgets = <pw.Widget>[];
    for (final c in clauses) {
      widgets.add(_sectionHeader(c.number, c.title));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(_justified(c.body));
      widgets.add(pw.SizedBox(height: 10));
    }
    return widgets;
  }

  static pw.Widget _sectionHeader(String? number, String title) {
    final prefix = number == null ? '' : '$number. ';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
      child: pw.Text(
        '$prefix$title',
        style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.3),
      ),
    );
  }

  static pw.Widget _justified(String text) {
    // Split on double newlines to preserve paragraph breaks
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final p in paragraphs) ...[
          pw.Text(
            p.trim(),
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
          if (p != paragraphs.last) pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  // ============================================================
  // First Schedule (property description)
  // ============================================================

  static pw.Widget _firstSchedule(
      SaleAgreementInput i, ContractRenderContext ctx) {
    final fullDesc = ContractTemplateRenderer.render(
        '{{property_full_legal_description}}', ctx);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text('FIRST SCHEDULE',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0)),
        ),
        pw.SizedBox(height: 10),
        _justified(fullDesc),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            '[Survey plan image to be attached separately by the surveyor.]',
            style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Second Schedule (payment plan table)
  // ============================================================

  static pw.Widget _secondSchedule(
      SaleAgreementInput i, ContractRenderContext ctx) {
    final installments = ctx.installments;
    final clientName = i.clientFullName;
    final freqWord = ContractTemplateRenderer.render(
        '{{installment_frequency}}', ctx);
    final amount = ContractTemplateRenderer.render(
        '{{installment_amount_ngn}}', ctx);
    final count = ContractTemplateRenderer.render(
        '{{installment_count}}', ctx);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text('SECOND SCHEDULE',
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0)),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text('PAYMENT PLAN',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.5)),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Client Name: $clientName',
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          'Payment Plan: $count Months $freqWord Installment — $amount',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColors.grey700, width: 0.4),
          columnWidths: const {
            0: pw.FixedColumnWidth(60),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Payment No.', isHeader: true),
                _tableCell('Due Date', isHeader: true),
                _tableCell('Amount Due (NGN)', isHeader: true),
              ],
            ),
            for (final inst in installments)
              pw.TableRow(
                children: [
                  _tableCell(inst.sequence.toString()),
                  _tableCell(_date.format(inst.dueDate)),
                  _tableCell(
                    _statusAmount(inst),
                  ),
                ],
              ),
            // Total row
            pw.TableRow(
              decoration:
              pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _tableCell('TOTAL', isHeader: true),
                _tableCell(''),
                _tableCell(
                    'NGN ${_money.format(installments.fold<num>(0, (s, x) => s + x.amount))}',
                    isHeader: true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _statusAmount(Installment inst) {
    final base = 'NGN ${_money.format(inst.amount)}';
    if (inst.status == InstallmentStatus.paid) return '$base — PAID';
    if (inst.status == InstallmentStatus.partial) {
      return '$base — PART PAID (NGN ${_money.format(inst.amountPaid)})';
    }
    return base;
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ============================================================
  // Signature block (Vendor + Purchaser + Witnesses)
  // ============================================================

  static pw.Widget _signatureBlocks(
      SaleAgreementInput i,
      pw.MemoryImage? agencySig,
      pw.MemoryImage? clientSig,
      pw.MemoryImage? buyerWitSig, {
        pw.MemoryImage? primaryDirectorSig,
        pw.MemoryImage? secondaryDirectorSig,
        pw.MemoryImage? sealImage,
      }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'IN WITNESS WHEREOF the Parties hereto have executed this Contract of Sale of Land, the date and year first above written.',
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
        ),
        pw.SizedBox(height: 14),
        // ---- Vendor ----
        pw.Text('SIGNED, SEALED and DELIVERED:',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('By the within-named VENDOR:',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 6),
        ..._vendorExecutionBlock(
          i, agencySig, primaryDirectorSig, secondaryDirectorSig, sealImage,
        ),
        pw.SizedBox(height: 24),
        // ---- Purchaser ----
        pw.Text('SIGNED, SEALED and DELIVERED',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('By the within-named PURCHASER:',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 14),
        if (clientSig != null)
          pw.Container(
            height: 40,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(clientSig, height: 40),
          )
        else
          pw.Container(
            width: 220,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom:
                pw.BorderSide(color: PdfColors.grey700, width: 0.5),
              ),
            ),
            height: 30,
          ),
        pw.SizedBox(height: 4),
        pw.Text(i.clientFullName.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        // ---- Witness blocks ----
        pw.Text('IN THE PRESENCE OF:',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _witnessSlot(
                heading: "Purchaser's Witness",
                name: i.buyerWitnessName,
                occupation: i.buyerWitnessOccupation,
                address: i.buyerWitnessAddress,
                signature: buyerWitSig,
                signedDate: i.buyerWitnessSignedAtDisplay,
              ),
            ),
            pw.Expanded(child: pw.SizedBox()),
          ],
        ),
      ],
    );
  }

  /// Vendor execution block: conditionally renders the seal text/image,
  /// directors, or both — based on the agency's `vendor_block_style` setting.
  ///
  /// Returns a list of widgets so the caller can spread it into a Column.
  static List<pw.Widget> _vendorExecutionBlock(
      SaleAgreementInput i,
      pw.MemoryImage? agencySig,
      pw.MemoryImage? primaryDirectorSig,
      pw.MemoryImage? secondaryDirectorSig,
      pw.MemoryImage? sealImage,
      ) {
    final style = i.vendorBlockStyle;
    final showSeal =
        style == 'seal_only' || style == 'directors_and_seal';
    final showDirectors =
        style == 'directors_only' || style == 'directors_and_seal';

    // Primary slot prefers the pre-uploaded director's signature image, but
    // falls back to the live agency signature when the contract requires
    // vendor signing (the old flow where a director signs via signing link).
    final primarySigToShow = primaryDirectorSig ?? agencySig;

    return [
      // Seal text + image (when style includes seal)
      if (showSeal) ...[
        pw.Text(
          'THE COMMON SEAL OF ${i.agencyName.toUpperCase()} IS ATTACHED TO THIS CONTRACT OF SALE OF LAND',
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (sealImage != null)
          pw.Container(
            height: 60,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(sealImage, height: 60),
          ),
        pw.SizedBox(height: 8),
      ],
      // Directors row (when style includes directors)
      if (showDirectors) ...[
        pw.Text('IN THE PRESENCE OF:',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            pw.Expanded(
              child: _directorSlot(i.primaryDirector, primarySigToShow),
            ),
            pw.SizedBox(width: 32),
            pw.Expanded(
              child: _directorSlot(i.secondaryDirector, secondaryDirectorSig),
            ),
          ],
        ),
      ],
    ];
  }

  /// Renders one director's slot in the vendor signature block.
  ///
  /// If a [DirectorSignature] is provided, embeds the signature image and
  /// name. Otherwise renders a blank signature line and underscores for
  /// the name — used when no director is configured or when the contract
  /// requires live signing.
  static pw.Widget _directorSlot(DirectorSignature? director,
      pw.MemoryImage? signatureImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (signatureImage != null)
          pw.Container(
            height: 36,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(signatureImage, height: 36),
          )
        else
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom:
                pw.BorderSide(color: PdfColors.grey700, width: 0.5),
              ),
            ),
            height: 26,
          ),
        pw.SizedBox(height: 4),
        pw.Text(
            director?.name.toUpperCase() ?? '____________________________',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text('DIRECTOR',
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _witnessSlot({
    required String heading,
    required String? name,
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
        pw.SizedBox(height: 6),
        _kvFill('Name', name ?? ''),
        _kvFill('Address', address ?? ''),
        _kvFill('Occupation', occupation ?? ''),
        pw.SizedBox(height: 4),
        if (signature != null)
          pw.Container(
            height: 32,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(signature, height: 32),
          )
        else
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom:
                pw.BorderSide(color: PdfColors.grey700, width: 0.5),
              ),
            ),
            height: 22,
          ),
        pw.SizedBox(height: 2),
        pw.Text('Signature',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        _kvFill('Date', signedDate ?? ''),
      ],
    );
  }

  static pw.Widget _kvFill(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
                text: '$k: ',
                style: const pw.TextStyle(fontSize: 9)),
            pw.TextSpan(
              text: v.isEmpty ? '_________________________' : v,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Prepared by (footer of document body)
  // ============================================================

  static pw.Widget _preparedBy(ContractRenderContext ctx) {
    final lawyerName = ctx.agency['lawyer_name'] as String?;
    if (lawyerName == null || lawyerName.isEmpty) return pw.SizedBox.shrink();

    final firm = ctx.agency['lawyer_firm'] as String?;
    final address = ctx.agency['lawyer_address'] as String?;
    final phone = ctx.agency['lawyer_phone'] as String?;

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 18),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('PREPARED BY:',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey700, width: 0.5),
                ),
              ),
              width: 200,
              height: 18,
            ),
            pw.SizedBox(height: 2),
            pw.Text(lawyerName,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
            if (firm != null && firm.isNotEmpty)
              pw.Text(firm,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey800)),
            pw.Text('Barrister & Solicitor, Supreme Court of Nigeria',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey800)),
            if (address != null && address.isNotEmpty)
              pw.Container(
                width: 200,
                child: pw.Text(address,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              ),
            if (phone != null && phone.isNotEmpty)
              pw.Text('Tel: $phone',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Audit page
  // ============================================================

  static pw.Page _auditPage(
      SaleAgreementInput i, List<SignerAuditInfo> auditEntries) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 56),
      footer: (c) => _footer(c, i),
      build: (_) => [
        pw.Text('SIGNATURE AUDIT TRAIL',
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2)),
        pw.SizedBox(height: 4),
        pw.Text(
          'The following parties electronically signed this document. Each signature is associated with the audit record below.',
          style:
          const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
                'Each signatory verified their identity via a one-time code sent to their email address before signing. Signatures were recorded with timestamps and the IP address used to access the signing portal. This document was prepared and distributed via Lintel.',
                style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
      ],
    );
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
              DateFormat('d MMMM yyyy, HH:mm:ss')
                  .format(e.signedAt.toLocal())),
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

  // ============================================================
  // Footer
  // ============================================================

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
            'Contract ${i.contractNo}',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

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
}

class _RenderableClause {
  final String? number;
  final String title;
  final String body;
  final String sectionKey;
  _RenderableClause({
    required this.title,
    required this.body,
    required this.sectionKey,
    this.number,
  });
}

class _LoadedTemplate {
  final List<_RenderableClause> clauses;
  final String? customAppendix;
  final ContractRenderContext ctx;
  _LoadedTemplate({
    required this.clauses,
    required this.customAppendix,
    required this.ctx,
  });
}