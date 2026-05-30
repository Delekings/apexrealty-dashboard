// lib/data/repositories/email_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

// ============================================================
// Models
// ============================================================

class EmailAutomation {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final String triggerType;
  final int triggerOffsetDays;
  final String triggerTime;
  final String subjectTemplate;
  final String bodyHtmlTemplate;
  final DateTime? lastRunAt;
  final int totalSentCount;
  final DateTime createdAt;

  EmailAutomation({
    required this.id,
    required this.name,
    required this.isActive,
    required this.triggerType,
    required this.triggerOffsetDays,
    required this.triggerTime,
    required this.subjectTemplate,
    required this.bodyHtmlTemplate,
    required this.totalSentCount,
    required this.createdAt,
    this.description,
    this.lastRunAt,
  });

  factory EmailAutomation.fromMap(Map<String, dynamic> m) => EmailAutomation(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String?,
    isActive: (m['is_active'] as bool?) ?? false,
    triggerType: m['trigger_type'] as String,
    triggerOffsetDays: (m['trigger_offset_days'] as num?)?.toInt() ?? 0,
    triggerTime: m['trigger_time'] as String,
    subjectTemplate: m['subject_template'] as String,
    bodyHtmlTemplate: m['body_html_template'] as String,
    lastRunAt: m['last_run_at'] != null
        ? DateTime.parse(m['last_run_at'] as String)
        : null,
    totalSentCount: (m['total_sent_count'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  String describeTrigger() {
    return switch (triggerType) {
      'client_birthday' => 'On client birthday',
      'days_before_installment_due' =>
      '$triggerOffsetDays day${triggerOffsetDays == 1 ? "" : "s"} before installment due',
      'days_after_installment_overdue' =>
      '$triggerOffsetDays day${triggerOffsetDays == 1 ? "" : "s"} after installment overdue',
      'contract_anniversary' => 'On contract anniversary',
      'days_after_client_onboarded' =>
      '$triggerOffsetDays day${triggerOffsetDays == 1 ? "" : "s"} after client onboarded',
      'on_contract_signed' => 'When contract is signed',
      _ => triggerType,
    };
  }
}

class EmailMessage {
  final String id;
  final String campaignId;
  final String? clientId;
  final String toEmail;
  final String? toName;
  final String status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? failedAt;
  final String? errorMessage;
  final DateTime createdAt;

  EmailMessage({
    required this.id,
    required this.campaignId,
    required this.toEmail,
    required this.status,
    required this.createdAt,
    this.clientId,
    this.toName,
    this.sentAt,
    this.deliveredAt,
    this.openedAt,
    this.failedAt,
    this.errorMessage,
  });

  factory EmailMessage.fromMap(Map<String, dynamic> m) => EmailMessage(
    id: m['id'] as String,
    campaignId: m['campaign_id'] as String,
    clientId: m['client_id'] as String?,
    toEmail: m['to_email'] as String,
    toName: m['to_name'] as String?,
    status: m['status'] as String,
    sentAt: m['sent_at'] != null
        ? DateTime.parse(m['sent_at'] as String)
        : null,
    deliveredAt: m['delivered_at'] != null
        ? DateTime.parse(m['delivered_at'] as String)
        : null,
    openedAt: m['opened_at'] != null
        ? DateTime.parse(m['opened_at'] as String)
        : null,
    failedAt: m['failed_at'] != null
        ? DateTime.parse(m['failed_at'] as String)
        : null,
    errorMessage: m['error_message'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class EmailProviderConfig {
  final String agencyId;
  final String? fromName;
  final String? replyToEmail;
  final String? customFromEmail;
  final bool customDomainVerified;
  final String? unsubscribeFooterText;
  final DateTime updatedAt;

  EmailProviderConfig({
    required this.agencyId,
    required this.customDomainVerified,
    required this.updatedAt,
    this.fromName,
    this.replyToEmail,
    this.customFromEmail,
    this.unsubscribeFooterText,
  });

  factory EmailProviderConfig.fromMap(Map<String, dynamic> m) =>
      EmailProviderConfig(
        agencyId: m['agency_id'] as String,
        fromName: m['from_name'] as String?,
        replyToEmail: m['reply_to_email'] as String?,
        customFromEmail: m['custom_from_email'] as String?,
        customDomainVerified:
        (m['custom_domain_verified'] as bool?) ?? false,
        unsubscribeFooterText: m['unsubscribe_footer_text'] as String?,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

class EmailCampaign {
  final String id;
  final String name;
  final String subject;
  final String status;
  final int totalRecipients;
  final int sentCount;
  final int deliveredCount;
  final int openedCount;
  final int bouncedCount;
  final int failedCount;
  final DateTime? scheduledFor;
  final DateTime? sendCompletedAt;
  final DateTime createdAt;

  EmailCampaign({
    required this.id,
    required this.name,
    required this.subject,
    required this.status,
    required this.totalRecipients,
    required this.sentCount,
    required this.deliveredCount,
    required this.openedCount,
    required this.bouncedCount,
    required this.failedCount,
    required this.createdAt,
    this.scheduledFor,
    this.sendCompletedAt,
  });

  factory EmailCampaign.fromMap(Map<String, dynamic> m) => EmailCampaign(
    id: m['id'] as String,
    name: m['name'] as String,
    subject: m['subject'] as String,
    status: m['status'] as String,
    totalRecipients: (m['total_recipients'] as num?)?.toInt() ?? 0,
    sentCount: (m['sent_count'] as num?)?.toInt() ?? 0,
    deliveredCount: (m['delivered_count'] as num?)?.toInt() ?? 0,
    openedCount: (m['opened_count'] as num?)?.toInt() ?? 0,
    bouncedCount: (m['bounced_count'] as num?)?.toInt() ?? 0,
    failedCount: (m['failed_count'] as num?)?.toInt() ?? 0,
    scheduledFor: m['scheduled_for'] != null
        ? DateTime.parse(m['scheduled_for'] as String)
        : null,
    sendCompletedAt: m['send_completed_at'] != null
        ? DateTime.parse(m['send_completed_at'] as String)
        : null,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

// ============================================================
// Repository
// ============================================================

class EmailRepository {
  final SupabaseClient _c = SupabaseService.client;

  // ----------------------------------------------------------
  // Single send
  // ----------------------------------------------------------

  /// Send a single email to a client. Returns the campaign ID + message ID.
  Future<({String campaignId, String messageId})> sendToClient({
    required String clientId,
    required String subject,
    required String html,
    String? campaignName,
  }) async {
    try {
      final res = await _c.functions.invoke(
        'email-send-test',
        body: {
          'clientId': clientId,
          'subject': subject,
          'html': html,
          if (campaignName != null) 'campaignName': campaignName,
        },
      );

      if (res.status != 200) {
        throw Exception(_extractError(res.data, res.status));
      }

      final data = res.data as Map<String, dynamic>;
      return (
      campaignId: data['campaignId'] as String,
      messageId: data['messageId'] as String,
      );
    } on FunctionException catch (e) {
      throw Exception(_extractError(e.details, e.status));
    }
  }

  /// Get all emails sent to a specific client.
  Future<List<EmailMessage>> messagesForClient(String clientId) async {
    final rows = await _c
        .from('email_messages')
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => EmailMessage.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // Agency config
  // ----------------------------------------------------------

  Future<EmailProviderConfig?> getMyAgencyConfig() async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return null;

    final row = await _c
        .from('email_provider_config')
        .select()
        .eq('agency_id', agencyId)
        .maybeSingle();

    if (row == null) return null;
    return EmailProviderConfig.fromMap(row);
  }

  Future<void> saveMyAgencyConfig({
    required String? fromName,
    required String? replyToEmail,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');

    await _c.from('email_provider_config').upsert({
      'agency_id': agencyId,
      'from_name': fromName?.trim().isEmpty == true ? null : fromName?.trim(),
      'reply_to_email':
      replyToEmail?.trim().isEmpty == true ? null : replyToEmail?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'agency_id');
  }

  // ----------------------------------------------------------
  // Campaigns
  // ----------------------------------------------------------

  Future<List<EmailCampaign>> listCampaigns({int limit = 50}) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];

    final rows = await _c
        .from('email_campaigns')
        .select()
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) => EmailCampaign.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Send a campaign to multiple recipients defined by [filter].
  Future<({String campaignId, int totalRecipients, int sentCount, int failedCount})>
  sendBulk({
    required String campaignName,
    required String subject,
    required String html,
    required Map<String, dynamic> filter,
  }) async {
    try {
      final res = await _c.functions.invoke(
        'email-send-bulk',
        body: {
          'campaignName': campaignName,
          'subject': subject,
          'html': html,
          'filter': filter,
        },
      );

      if (res.status != 200) {
        throw Exception(_extractError(res.data, res.status));
      }

      final data = res.data as Map<String, dynamic>;
      return (
      campaignId: data['campaignId'] as String,
      totalRecipients: (data['totalRecipients'] as num).toInt(),
      sentCount: (data['sentCount'] as num).toInt(),
      failedCount: (data['failedCount'] as num).toInt(),
      );
    } on FunctionException catch (e) {
      throw Exception(_extractError(e.details, e.status));
    }
  }

  /// Schedule a campaign to send at a future time. Does NOT dispatch
  /// immediately. The scheduler Edge Function will pick it up at the
  /// scheduled_for time and dispatch via Resend.
  Future<({String campaignId, int recipientCount})> scheduleCampaign({
    required String campaignName,
    required String subject,
    required String html,
    required Map<String, dynamic> filter,
    required DateTime scheduledFor,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');

    final recipientCount = await previewRecipientCount(filter);
    if (recipientCount == 0) {
      throw Exception('No eligible recipients for this filter');
    }
    if (scheduledFor.isBefore(DateTime.now())) {
      throw Exception('Scheduled time must be in the future');
    }

    final cfg = await getMyAgencyConfig();
    final fromName = cfg?.fromName;
    final replyTo = cfg?.replyToEmail;

    final userId = _c.auth.currentUser?.id;

    final row = await _c.from('email_campaigns').insert({
      'agency_id': agencyId,
      'created_by': userId,
      'name': campaignName,
      'subject': subject,
      'body_html': html,
      'from_name': fromName,
      'reply_to_email': replyTo,
      'recipient_filter': filter,
      'recipient_count': recipientCount,
      'total_recipients': recipientCount,
      'status': 'scheduled',
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
    }).select('id').single();

    return (
    campaignId: row['id'] as String,
    recipientCount: recipientCount,
    );
  }

  /// Cancel a scheduled campaign. Only works if status is still 'scheduled'.
  Future<void> cancelScheduledCampaign(String campaignId) async {
    await _c
        .from('email_campaigns')
        .update({'status': 'cancelled'})
        .eq('id', campaignId)
        .eq('status', 'scheduled');
  }

  /// Manually trigger the scheduler (for testing).
  Future<Map<String, dynamic>> runSchedulerNow() async {
    try {
      final res = await _c.functions.invoke('email-scheduler', body: {});
      if (res.status != 200) {
        throw Exception(_extractError(res.data, res.status));
      }
      return res.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      throw Exception(_extractError(e.details, e.status));
    }
  }

  // ----------------------------------------------------------
  // Recipient resolution
  // ----------------------------------------------------------

  Future<int> previewRecipientCount(Map<String, dynamic> filter) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return 0;

    final type = filter['type'] as String;

    if (type == 'all') {
      final r = await _c
          .from('clients')
          .select('id')
          .eq('agency_id', agencyId)
          .not('email', 'is', null)
          .eq('email_subscribed', true)
          .count(CountOption.exact);
      return r.count;
    }

    if (type == 'by_state') {
      final states = (filter['states'] as List?)?.cast<String>() ?? [];
      if (states.isEmpty) return 0;
      final r = await _c
          .from('clients')
          .select('id')
          .eq('agency_id', agencyId)
          .inFilter('state', states)
          .not('email', 'is', null)
          .eq('email_subscribed', true)
          .count(CountOption.exact);
      return r.count;
    }

    if (type == 'has_active_contract') {
      final rows = await _c
          .from('contracts')
          .select('client_id, client:clients!inner(email, email_subscribed)')
          .eq('agency_id', agencyId)
          .eq('status', 'active');
      final ids = <String>{};
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final client = m['client'] as Map<String, dynamic>?;
        if (client == null) continue;
        if (client['email'] == null) continue;
        if (client['email_subscribed'] == false) continue;
        ids.add(m['client_id'] as String);
      }
      return ids.length;
    }

    if (type == 'has_overdue') {
      final rows = await _c
          .from('installments')
          .select(
          'contract:contracts!inner(client_id, client:clients!inner(email, email_subscribed, agency_id))')
          .eq('status', 'overdue');
      final ids = <String>{};
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final c = m['contract'] as Map<String, dynamic>?;
        if (c == null) continue;
        final client = c['client'] as Map<String, dynamic>?;
        if (client == null) continue;
        if (client['agency_id'] != agencyId) continue;
        if (client['email'] == null) continue;
        if (client['email_subscribed'] == false) continue;
        ids.add(c['client_id'] as String);
      }
      return ids.length;
    }

    return 0;
  }

  Future<List<String>> getClientStates() async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];

    final rows = await _c
        .from('clients')
        .select('state')
        .eq('agency_id', agencyId)
        .not('state', 'is', null);

    final states = <String>{};
    for (final r in rows as List) {
      final m = r as Map<String, dynamic>;
      final s = m['state'] as String?;
      if (s != null && s.isNotEmpty) states.add(s);
    }
    return states.toList()..sort();
  }

  // ----------------------------------------------------------
  // Automations
  // ----------------------------------------------------------

  Future<List<EmailAutomation>> listAutomations() async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];
    final rows = await _c
        .from('email_automations')
        .select()
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => EmailAutomation.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<String> createAutomation({
    required String name,
    String? description,
    required String triggerType,
    required int triggerOffsetDays,
    required String triggerTime,
    required String subjectTemplate,
    required String bodyHtmlTemplate,
    bool isActive = true,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');
    final userId = _c.auth.currentUser?.id;

    final res = await _c.from('email_automations').insert({
      'agency_id': agencyId,
      'created_by': userId,
      'name': name,
      'description': description,
      'is_active': isActive,
      'trigger_type': triggerType,
      'trigger_offset_days': triggerOffsetDays,
      'trigger_time': triggerTime,
      'subject_template': subjectTemplate,
      'body_html_template': bodyHtmlTemplate,
    }).select('id').single();

    return res['id'] as String;
  }

  Future<void> setAutomationActive({
    required String automationId,
    required bool isActive,
  }) async {
    await _c.from('email_automations').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', automationId);
  }

  Future<void> deleteAutomation(String automationId) async {
    await _c.from('email_automations').delete().eq('id', automationId);
  }

  Future<Map<String, dynamic>> runAutomationsNow() async {
    try {
      final res =
      await _c.functions.invoke('email-automation-runner', body: {});
      if (res.status != 200) {
        throw Exception(_extractError(res.data, res.status));
      }
      return res.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      throw Exception(_extractError(e.details, e.status));
    }
  }

  // ----------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------

  String _extractError(dynamic body, int status) {
    String msg = 'Status $status';
    if (body is Map) {
      msg = body['error']?.toString() ?? msg;
      if (body['details'] != null) {
        msg += ' — ${body['details']}';
      }
    } else if (body != null) {
      msg = body.toString();
    }
    return msg;
  }

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
}