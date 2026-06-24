// lib/features/email/presentation/screens/email_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/single_file_picker.dart';
import '../../../../data/repositories/email_repository.dart';
import '../../../../data/services/supabase_service.dart';
import '../builder/email_block.dart';
import '../widgets/new_campaign_dialog.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

class EmailBuilderScreen extends ConsumerStatefulWidget {
  const EmailBuilderScreen({super.key});

  @override
  ConsumerState<EmailBuilderScreen> createState() => _EmailBuilderScreenState();
}

class _EmailBuilderScreenState extends ConsumerState<EmailBuilderScreen> {
  final List<EmailBlock> _blocks = [];
  int _counter = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Seed with a friendly starting layout.
    _blocks.addAll([
      EmailBlock(id: _newId(), type: EmailBlockType.heading, text: 'Hello {{first_name}},'),
      EmailBlock(
          id: _newId(),
          type: EmailBlockType.text,
          text: 'Write your message here. Drag blocks by the handle to reorder them.'),
    ]);
  }

  String _newId() => 'b${_counter++}';

  String _html() => blocksToHtml(_blocks);

  EmailBlock _defaultFor(EmailBlockType t) {
    switch (t) {
      case EmailBlockType.heading:
        return EmailBlock(id: _newId(), type: t, text: 'New heading');
      case EmailBlockType.text:
        return EmailBlock(id: _newId(), type: t, text: 'New paragraph of text.');
      case EmailBlockType.image:
        return EmailBlock(id: _newId(), type: t, align: 'center');
      case EmailBlockType.button:
        return EmailBlock(
            id: _newId(),
            type: t,
            text: 'Click here',
            url: 'https://',
            align: 'center');
      case EmailBlockType.divider:
        return EmailBlock(id: _newId(), type: t);
      case EmailBlockType.spacer:
        return EmailBlock(id: _newId(), type: t, height: 24);
    }
  }

  void _add(EmailBlockType t) =>
      setState(() => _blocks.add(_defaultFor(t)));

  void _remove(String id) =>
      setState(() => _blocks.removeWhere((b) => b.id == id));

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final b = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, b);
    });
  }

  Future<void> _uploadImage(EmailBlock b, PickedFile f) async {
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(_emailRepoProvider)
          .uploadEmailImage(bytes: f.bytes, filename: f.filename);
      setState(() => b.url = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyHtml() {
    Clipboard.setData(ClipboardData(text: _html()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('HTML copied to clipboard'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _useInCampaign() async {
    await showDialog(
      context: context,
      builder: (_) => NewCampaignDialog(
        initialHtml: _html(),
        initialHtmlMode: true,
      ),
    );
  }

  Future<void> _sendTest() async {
    final toCtrl = TextEditingController(
        text: SupabaseService.client.auth.currentUser?.email ?? '');
    final subjCtrl = TextEditingController(text: 'Email preview');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send a test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sends this design to one address so you can preview it. '
              'No campaign is created.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjCtrl,
              decoration: const InputDecoration(
                  labelText: 'Subject', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: toCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Send test to', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send test')),
        ],
      ),
    );
    final to = toCtrl.text.trim();
    final subject = subjCtrl.text.trim();
    toCtrl.dispose();
    subjCtrl.dispose();
    if (ok != true || to.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(_emailRepoProvider).sendTestEmail(
            toEmail: to,
            subject: subject.isEmpty ? 'Email preview' : subject,
            html: _html(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Test sent to $to'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/email/campaigns'),
        ),
        title: const Text('Email builder'),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _copyHtml,
            icon: const Icon(Icons.code, size: 18),
            label: const Text('Copy HTML'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _sendTest,
            icon: const Icon(Icons.forward_to_inbox, size: 18),
            label: const Text('Send test'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton.icon(
              onPressed: _busy ? null : _useInCampaign,
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Use in campaign'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _palette(),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _blocks.isEmpty
                ? _emptyState()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        buildDefaultDragHandles: false,
                        itemCount: _blocks.length,
                        onReorder: _reorder,
                        itemBuilder: (context, i) {
                          final b = _blocks[i];
                          return _BlockCard(
                            key: ValueKey(b.id),
                            block: b,
                            index: i,
                            busy: _busy,
                            onChanged: () => setState(() {}),
                            onDelete: () => _remove(b.id),
                            onUpload: (f) => _uploadImage(b, f),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _palette() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Add block:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          for (final t in EmailBlockType.values)
            OutlinedButton.icon(
              onPressed: () => _add(t),
              icon: Icon(_iconFor(t), size: 16),
              label: Text(t.label),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.brand,
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dashboard_customize_outlined,
              size: 40, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('Start building',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Add blocks above, then drag to arrange them.',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  IconData _iconFor(EmailBlockType t) {
    switch (t) {
      case EmailBlockType.heading:
        return Icons.title;
      case EmailBlockType.text:
        return Icons.notes;
      case EmailBlockType.image:
        return Icons.image_outlined;
      case EmailBlockType.button:
        return Icons.smart_button_outlined;
      case EmailBlockType.divider:
        return Icons.horizontal_rule;
      case EmailBlockType.spacer:
        return Icons.height;
    }
  }
}

class _BlockCard extends StatelessWidget {
  final EmailBlock block;
  final int index;
  final bool busy;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final ValueChanged<PickedFile> onUpload;

  const _BlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.busy,
    required this.onChanged,
    required this.onDelete,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            decoration: const BoxDecoration(
              color: AppColors.bg3,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator,
                        size: 18, color: AppColors.muted),
                  ),
                ),
                Text(block.type.label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete block',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _editor(context),
          ),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    switch (block.type) {
      case EmailBlockType.heading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: block.text,
              onChanged: (v) {
                block.text = v;
                onChanged();
              },
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                  hintText: 'Heading text', isDense: true),
            ),
            _alignRow(),
          ],
        );
      case EmailBlockType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: block.text,
              onChanged: (v) {
                block.text = v;
                onChanged();
              },
              maxLines: null,
              minLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Paragraph text. {{first_name}} works here.',
                  isDense: true),
            ),
            _alignRow(),
          ],
        );
      case EmailBlockType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.url.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  block.url,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: AppColors.bg2,
                    child: const Text('Could not load image',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SingleFilePicker(
              label: 'Upload image or GIF',
              allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
              onChanged: (f) {
                if (f != null) onUpload(f);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: block.url,
              onChanged: (v) {
                block.url = v;
                onChanged();
              },
              decoration: const InputDecoration(
                  labelText: 'or paste image/GIF URL', isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: block.link,
              onChanged: (v) {
                block.link = v;
                onChanged();
              },
              decoration: const InputDecoration(
                  labelText: 'Link when clicked (optional)', isDense: true),
            ),
            _alignRow(),
          ],
        );
      case EmailBlockType.button:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: block.align == 'center'
                  ? Alignment.center
                  : (block.align == 'right'
                      ? Alignment.centerRight
                      : Alignment.centerLeft),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  block.text.isEmpty ? 'Button' : block.text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            TextFormField(
              initialValue: block.text,
              onChanged: (v) {
                block.text = v;
                onChanged();
              },
              decoration: const InputDecoration(
                  labelText: 'Button label', isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: block.url,
              onChanged: (v) {
                block.url = v;
                onChanged();
              },
              decoration: const InputDecoration(
                  labelText: 'Link URL', isDense: true),
            ),
            _alignRow(),
          ],
        );
      case EmailBlockType.divider:
        return const Divider(height: 1, color: AppColors.border);
      case EmailBlockType.spacer:
        return Row(
          children: [
            const Text('Height', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Slider(
                value: block.height.toDouble().clamp(4, 120),
                min: 4,
                max: 120,
                divisions: 29,
                label: '${block.height}px',
                activeColor: AppColors.brand,
                onChanged: (v) {
                  block.height = v.round();
                  onChanged();
                },
              ),
            ),
            Text('${block.height}px',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted)),
          ],
        );
    }
  }

  Widget _alignRow() {
    Widget btn(String value, IconData icon) {
      final selected = block.align == value;
      return IconButton(
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
        color: selected ? AppColors.brand : AppColors.muted,
        onPressed: () {
          block.align = value;
          onChanged();
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Text('Align',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          btn('left', Icons.format_align_left),
          btn('center', Icons.format_align_center),
          btn('right', Icons.format_align_right),
        ],
      ),
    );
  }
}
