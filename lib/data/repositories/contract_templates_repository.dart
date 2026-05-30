// lib/data/repositories/contract_templates_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/contract_template_renderer.dart';
import '../services/supabase_service.dart';

class TemplateWithClauses {
  final ContractTemplate template;
  final List<ContractClause> clauses;
  TemplateWithClauses({required this.template, required this.clauses});
}

class ContractTemplatesRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Get the agency's default template + all clauses ordered.
  Future<TemplateWithClauses> getDefault() async {
    final tplRow = await _c
        .from('contract_templates')
        .select()
        .eq('is_default', true)
        .maybeSingle();

    if (tplRow == null) {
      throw Exception('No default contract template found for this agency');
    }

    final template = ContractTemplate.fromMap(tplRow);

    final clauseRows = await _c
        .from('contract_template_clauses')
        .select()
        .eq('template_id', template.id)
        .order('sort_order', ascending: true);

    final clauses = (clauseRows as List)
        .map((r) => ContractClause.fromMap(r as Map<String, dynamic>))
        .toList();

    return TemplateWithClauses(template: template, clauses: clauses);
  }

  /// Update a clause's body text.
  Future<void> updateClauseBody({
    required String clauseId,
    required String newBody,
  }) async {
    await _c.from('contract_template_clauses').update({
      'body_markdown': newBody,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clauseId);
  }

  /// Toggle whether a clause is rendered in the PDF.
  Future<void> setClauseHidden({
    required String clauseId,
    required bool hidden,
  }) async {
    await _c.from('contract_template_clauses').update({
      'is_hidden': hidden,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clauseId);
  }

  /// Update the template's custom appendix.
  Future<void> updateAppendix({
    required String templateId,
    required String? text,
  }) async {
    await _c.from('contract_templates').update({
      'custom_appendix_text': text,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', templateId);
  }

  /// Reset one clause back to the system default body.
  Future<void> resetClauseToDefault({
    required String clauseId,
    required String sectionKey,
  }) async {
    final defaultBody = await _c.rpc(
      'get_default_clause_body',
      params: {'p_section_key': sectionKey},
    );
    if (defaultBody == null) {
      throw Exception('No system default available for $sectionKey');
    }
    await updateClauseBody(clauseId: clauseId, newBody: defaultBody as String);
  }

  /// Fetch the variable catalog for the UI picker.
  Future<List<TemplateVariable>> getVariableCatalog() async {
    final rows = await _c
        .from('contract_template_variables')
        .select()
        .order('sort_order');
    return (rows as List)
        .map((r) => TemplateVariable.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Build a full render context for a contract, ready to feed
  /// [ContractTemplateRenderer.render].
  Future<ContractRenderContext> buildRenderContext(String contractId) async {
    final rpc = await _c.rpc('get_contract_render_context', params: {
      'p_contract_id': contractId,
    });

    if (rpc == null) {
      throw Exception('Could not load render context for contract $contractId');
    }

    final installmentRows = await _c
        .from('installments')
        .select()
        .eq('contract_id', contractId)
        .order('sequence', ascending: true);

    final installments = (installmentRows as List)
        .map((r) => Installment.fromMap(r as Map<String, dynamic>))
        .toList();

    return ContractRenderContext.fromRpcResponse(
      rpc: rpc as Map<String, dynamic>,
      installments: installments,
    );
  }
  /// Freeze the current template state for a contract. Call this when
  /// sending for signature so subsequent template edits don't change
  /// the contract.
  Future<void> createSnapshot(String contractId) async {
    await _c.rpc('create_contract_snapshot', params: {
      'p_contract_id': contractId,
    });
  }

  /// Returns the frozen clauses for a contract, or null if no snapshot
  /// has been taken yet.
  Future<({List<ContractClause> clauses, String? appendix})?>
  getSnapshot(String contractId) async {
    final res = await _c.rpc('get_contract_snapshot', params: {
      'p_contract_id': contractId,
    });
    if (res == null) return null;
    final map = res as Map<String, dynamic>;
    final rawList = (map['rendered_clauses'] as List?) ?? [];

    // Build ContractClause objects from the snapshot JSON.
    // Snapshot rows don't have id/template_id/agency_id so we synthesize
    // placeholders — the PDF generator only uses the body + section info.
    final clauses = rawList.map((r) {
      final m = r as Map<String, dynamic>;
      return ContractClause(
        id: 'snapshot-${m['section_key']}',
        templateId: 'snapshot',
        agencyId: 'snapshot',
        sectionKey: m['section_key'] as String,
        sectionNumber: m['section_number'] as String?,
        sectionTitle: m['section_title'] as String,
        sortOrder: (m['sort_order'] as num).toInt(),
        bodyMarkdown: m['body_markdown'] as String,
        isLocked: (m['is_locked'] as bool?) ?? false,
        isHidden: false,
        updatedAt: DateTime.now(),
      );
    }).toList();

    return (clauses: clauses, appendix: map['custom_appendix_text'] as String?);
  }
}