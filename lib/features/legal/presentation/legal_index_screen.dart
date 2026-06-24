// lib/features/legal/presentation/legal_index_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../legal_docs.dart';

class LegalIndexScreen extends StatelessWidget {
  const LegalIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Legal & policies'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Lintel legal documents',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'The policies governing your use of Lintel and how we handle data.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              for (final d in legalDocs)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined,
                        color: AppColors.brand),
                    title: Text(d.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${d.summary}\nv${d.version} · Effective ${d.effectiveDate}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.muted),
                    onTap: () => context.go('/legal/${d.slug}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
