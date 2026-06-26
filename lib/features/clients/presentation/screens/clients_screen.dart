// lib/features/clients/presentation/screens/clients_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/models/models.dart';
import '../../providers/clients_providers.dart';
import '../../../../data/repositories/clients_repository.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final current = ref.read(clientsFilterProvider);
      ref.read(clientsFilterProvider.notifier).state =
          current.copyWith(search: value, page: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(clientsFilterProvider);
    final pageAsync = ref.watch(clientsPageProvider);
    final agentsAsync = ref.watch(agentsListProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clients',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Everyone you\'re onboarding, billing, or following up with.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/clients/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Onboard client'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
                    hintText: 'Search by name, phone, or email',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: agentsAsync.when(
                  loading: () => const _AgentDropdownPlaceholder(),
                  error: (_, __) => const _AgentDropdownPlaceholder(),
                  data: (agents) => _AgentDropdown(
                    agents: agents,
                    selectedId: filter.agentId,
                    onChanged: (id) {
                      ref.read(clientsFilterProvider.notifier).state =
                          filter.copyWith(
                            agentId: id,
                            clearAgent: id == null,
                            page: 0,
                          );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Results
          Expanded(
            child: pageAsync.when(
              loading: () => const Center(
                child: LintelLoader(),
              ),
              error: (e, _) => Center(
                child: Text('Failed to load clients: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: filter.search.isEmpty && filter.agentId == null
                        ? 'No clients yet'
                        : 'No clients match your filters',
                    message: filter.search.isEmpty && filter.agentId == null
                        ? 'Onboard your first client to get started.'
                        : 'Try clearing the search or changing the agent filter.',
                    action: (filter.search.isEmpty && filter.agentId == null)
                        ? FilledButton.icon(
                            onPressed: () => context.go('/clients/new'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Onboard your first client'),
                          )
                        : null,
                  );
                }
                return _ClientsTable(page: page);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentDropdownPlaceholder extends StatelessWidget {
  const _AgentDropdownPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _AgentDropdown extends StatelessWidget {
  final List<Profile> agents;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _AgentDropdown({
    required this.agents,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      value: selectedId,
      isDense: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.person_outline, size: 18, color: AppColors.muted),
        isDense: true,
      ),
      hint: const Text('Filter by agent',
          style: TextStyle(fontSize: 13, color: AppColors.muted)),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All agents', style: TextStyle(fontSize: 13)),
        ),
        for (final a in agents)
          DropdownMenuItem<String?>(
            value: a.id,
            child: Text(a.fullName, style: const TextStyle(fontSize: 13)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ClientsTable extends ConsumerWidget {
  final ClientsPage page;
  const _ClientsTable({required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: [
          // Header row (only on wide screens — the cards below are responsive)
          if (MediaQuery.of(context).size.width >= 800)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 40),
                  Expanded(flex: 3, child: _ColHeader('Name')),
                  Expanded(flex: 3, child: _ColHeader('Phone')),
                  Expanded(flex: 3, child: _ColHeader('Email')),
                  Expanded(flex: 2, child: _ColHeader('State')),
                  Expanded(flex: 2, child: _ColHeader('Agent')),
                  Expanded(flex: 2, child: _ColHeader('Onboarded')),
                  SizedBox(width: 32),
                ],
              ),
            ),
          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const Divider(
                height: 0.5, thickness: 0.5, color: AppColors.border),
              itemBuilder: (_, i) => _ClientRow(item: page.items[i]),
            ),
          ),
          // Pagination footer
          _PaginationBar(page: page),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  const _ColHeader(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        color: AppColors.muted,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final ClientListItem item;
  const _ClientRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return InkWell(
      onTap: () => context.go('/clients/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isWide
            ? _wideRow()
            : _narrowRow(),
      ),
    );
  }

  Widget _avatar() => CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.brandLight,
        child: Text(
          item.initials,
          style: const TextStyle(
              color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _wideRow() => Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(flex: 3,
            child: Text(item.fullName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(flex: 3,
            child: Text(item.phone,
                style: const TextStyle(fontSize: 13, color: AppColors.text)),
          ),
          Expanded(flex: 3,
            child: Text(item.email ?? '—',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(flex: 2,
            child: Text(item.state ?? '—',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
          Expanded(flex: 2,
            child: Text(item.agentName ?? 'Unassigned',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
          Expanded(flex: 2,
            child: Text(Formatters.date(item.createdAt),
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ],
      );

  Widget _narrowRow() => Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.fullName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(item.phone,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
        ],
      );
}

class _PaginationBar extends ConsumerWidget {
  final ClientsPage page;
  const _PaginationBar({required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = page.total == 0 ? 0 : (page.page * page.pageSize) + 1;
    final to = (from + page.items.length - 1).clamp(0, page.total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            page.total == 0
                ? '0 results'
                : '$from–$to of ${page.total}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const Spacer(),
          IconButton(
            onPressed: page.hasPrev
                ? () {
                    final f = ref.read(clientsFilterProvider);
                    ref.read(clientsFilterProvider.notifier).state =
                        f.copyWith(page: f.page - 1);
                  }
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'Previous page',
          ),
          Text(
            'Page ${page.page + 1}${page.totalPages > 0 ? ' / ${page.totalPages}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            onPressed: page.hasNext
                ? () {
                    final f = ref.read(clientsFilterProvider);
                    ref.read(clientsFilterProvider.notifier).state =
                        f.copyWith(page: f.page + 1);
                  }
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}
