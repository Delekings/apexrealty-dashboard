// lib/features/legal/presentation/legal_doc_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../legal_docs.dart';
import '../markdown_view.dart';

class LegalDocScreen extends StatefulWidget {
  final String slug;
  const LegalDocScreen({super.key, required this.slug});

  @override
  State<LegalDocScreen> createState() => _LegalDocScreenState();
}

class _LegalDocScreenState extends State<LegalDocScreen> {
  LegalDoc? _doc;
  late Future<List<Widget>> _future;

  @override
  void initState() {
    super.initState();
    _doc = legalDocBySlug(widget.slug);
    _future = _load();
  }

  Future<List<Widget>> _load() async {
    final d = _doc;
    if (d == null) return <Widget>[];
    final raw = await rootBundle.loadString(d.asset);
    return markdownToWidgets(raw);
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/legal'),
        ),
        title: Text(doc?.title ?? 'Document'),
      ),
      body: doc == null
          ? const Center(child: Text('Document not found.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: FutureBuilder<List<Widget>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('Could not load this document.'),
                        ),
                      );
                    }
                    final blocks = snap.data ?? const <Widget>[];
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 56),
                      itemCount: blocks.length,
                      itemBuilder: (_, i) => blocks[i],
                    );
                  },
                ),
              ),
            ),
    );
  }
}
