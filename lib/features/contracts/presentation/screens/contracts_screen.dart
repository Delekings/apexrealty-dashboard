// lib/features/contracts/presentation/screens/contracts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/contracts_repository.dart';
import '../../providers/contracts_providers.dart';

class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  ContractStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractsListProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contracts',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Every deal in motion — from sign-up to fully paid.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter
          Row(
            children: [
              const Text('Filter:',
                  style:
                  TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  _filterChip(null, 'All'),
                  _filterChip(ContractStatus.active, 'Active'),
                  _filterChip(ContractStatus.completed, 'Completed'),
                  _filterChip(ContractStatus.pendingSignature, 'Pending sig.'),
                  _filterChip(ContractStatus.defaulted, 'Defaulted'),
                  _filterChip(ContractStatus.cancelled, 'Cancelled'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              ),
              error: (e, _) => Center(
                child: Text('Failed to load: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (contracts) {
                final filtered = _statusFilter == null
                    ? contracts
                    : contracts
                    .where((c) => c.status == _statusFilter)
                    .toList();

                if (contracts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No contracts yet',
                    message:
                    'Contracts appear here when you sell a property to a client.',
                  );
                }

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.filter_alt_outlined,
                    title: 'No contracts match this filter',
                    message:
                    'Try selecting a different status or "All".',
                  );
                }

                return _ContractsTable(items: filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ContractStatus? status, String label) {
    final selected = _statusFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandLight : AppColors.bg,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? AppColors.brand : AppColors.text)),
      ),
    );
  }
}

class _ContractsTable extends StatelessWidget {
  final List<ContractListItem> items;
  const _ContractsTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;

    return Card(
      child: Column(
        children: [
          if (wide)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.border, width: 0.5)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: _ColHeader('Contract')),
                  Expanded(flex: 3, child: _ColHeader('Client')),
                  Expanded(flex: 3, child: _ColHeader('Property')),
                  Expanded(flex: 2, child: _ColHeader('Total')),
                  Expanded(flex: 2, child: _ColHeader('Status')),
                  Expanded(flex: 2, child: _ColHeader('Created')),
                  SizedBox(width: 24),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: AppColors.border),
              itemBuilder: (_, i) => _ContractRow(item: items[i]),
            ),
          ),
          // Footer with count
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Text('${items.length} contract${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
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

class _ContractRow extends StatelessWidget {
  final ContractListItem item;
  const _ContractRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    return InkWell(
      onTap: () => context.go('/contracts/${item.id}'),
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: wide ? _wide() : _narrow(),
      ),
    );
  }

  Widget _wide() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(item.contractNo,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          flex: 3,
          child: Text(item.clientName ?? '—',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 3,
          child: Text(item.propertyTitle ?? '—',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.muted),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Text(Formatters.naira(item.totalPrice),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Expanded(flex: 2, child: _StatusChip(status: item.status)),
        Expanded(
          flex: 2,
          child: Text(Formatters.date(item.createdAt),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted)),
        ),
        const Icon(Icons.chevron_right,
            size: 18, color: AppColors.muted),
      ],
    );
  }

  Widget _narrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(item.contractNo,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            _StatusChip(status: item.status),
          ],
        ),
        const SizedBox(height: 4),
        Text('${item.clientName ?? '—'} · ${item.propertyTitle ?? '—'}',
            style:
            const TextStyle(fontSize: 12, color: AppColors.muted),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(Formatters.naira(item.totalPrice),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ContractStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ContractStatus.draft => ('Draft', AppColors.bg2, AppColors.muted),
      ContractStatus.pendingSignature =>
      ('Pending sig.', AppColors.warnLight, AppColors.warn),
      ContractStatus.active =>
      ('Active', AppColors.brandLight, AppColors.brand),
      ContractStatus.completed =>
      ('Completed', AppColors.brandLight, AppColors.brand),
      ContractStatus.cancelled =>
      ('Cancelled', AppColors.bg2, AppColors.muted),
      ContractStatus.defaulted =>
      ('Defaulted', AppColors.dangerLight, AppColors.danger),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: fg)),
      ),
    );
  }
}