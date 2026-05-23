// lib/features/properties/presentation/screens/property_detail_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/photo_picker.dart';
import '../../../../data/models/models.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/properties_providers.dart';
import '../widgets/unit_inventory_card.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  int _activePhotoIndex = 0;
  bool _uploadingMore = false;

  Future<void> _addMorePhotos() async {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add more photos',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _AddMorePhotosFlow(propertyId: widget.propertyId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyDetailProvider(widget.propertyId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => Center(
          child: Text("Couldn't load property: $e",
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (property) => _Body(
          property: property,
          activePhotoIndex: _activePhotoIndex,
          onPhotoTap: (i) => setState(() => _activePhotoIndex = i),
          onAddPhotos: _uploadingMore ? null : _addMorePhotos,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Property property;
  final int activePhotoIndex;
  final ValueChanged<int> onPhotoTap;
  final VoidCallback? onAddPhotos;

  const _Body({
    required this.property,
    required this.activePhotoIndex,
    required this.onPhotoTap,
    required this.onAddPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => context.go('/properties'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${property.location}, ${property.state}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAddPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
              label: const Text('Add photos'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: wide
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _Gallery(property: property),
                      const SizedBox(height: 16),
                      UnitInventoryCard(propertyId: property.id),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: _InfoColumn(property: property),
                ),
              ),
            ],
          )
              : SingleChildScrollView(
            child: Column(
              children: [
                _Gallery(property: property),
                const SizedBox(height: 12),
                UnitInventoryCard(propertyId: property.id),
                const SizedBox(height: 12),
                _InfoColumn(property: property),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  final Property property;
  const _Gallery({required this.property});

  @override
  Widget build(BuildContext context) {
    final allPhotos = [
      if (property.coverImageUrl != null) property.coverImageUrl!,
      ...property.gallery,
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: allPhotos.isEmpty
            ? Container(
          color: AppColors.brandLight,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work_outlined,
                    size: 48, color: AppColors.brand),
                SizedBox(height: 8),
                Text(
                  'No photos yet — add some from the button above',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        )
            : CachedNetworkImage(
          imageUrl: allPhotos.first,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppColors.bg2,
            child: const Center(
              child:
              CircularProgressIndicator(color: AppColors.brand),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: AppColors.bg2,
            child: const Icon(Icons.image_not_supported_outlined,
                color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final Property property;
  const _InfoColumn({required this.property});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status + type card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusBgColor(property.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(property.status),
                        style: TextStyle(
                            color: _statusColor(property.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _typeLabel(property.type),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
                if (property.description != null &&
                    property.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('About this property',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(
                    property.description!,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Location card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Location',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        property.lga != null
                            ? '${property.location}\n${property.lga}, ${property.state}'
                            : '${property.location}\n${property.state}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddMorePhotosFlow extends ConsumerStatefulWidget {
  final String propertyId;
  const _AddMorePhotosFlow({required this.propertyId});

  @override
  ConsumerState<_AddMorePhotosFlow> createState() =>
      _AddMorePhotosFlowState();
}

class _AddMorePhotosFlowState extends ConsumerState<_AddMorePhotosFlow> {
  List<PickedPhoto> _photos = [];
  bool _uploading = false;
  String? _error;

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on profile');
      }
      final repo = ref.read(propertiesRepoProvider);
      await repo.uploadPhotos(
        agencyId: profile!.agencyId!,
        propertyId: widget.propertyId,
        files: _photos
            .map((p) => (bytes: p.bytes, filename: p.filename))
            .toList(),
      );
      ref.invalidate(propertyDetailProvider(widget.propertyId));
      ref.invalidate(propertiesPageProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoPicker(onChanged: (p) => setState(() => _photos = p)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed:
              _uploading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
              (_photos.isNotEmpty && !_uploading) ? _upload : null,
              child: Text(_uploading ? 'Uploading…' : 'Upload'),
            ),
          ],
        ),
      ],
    );
  }
}

String _statusLabel(PropertyStatus s) => switch (s) {
  PropertyStatus.available => 'Available',
  PropertyStatus.reserved => 'Reserved',
  PropertyStatus.partiallySold => 'Partially sold',
  PropertyStatus.soldOut => 'Sold out',
  PropertyStatus.inactive => 'Inactive',
};

Color _statusColor(PropertyStatus s) => switch (s) {
  PropertyStatus.available => AppColors.brand,
  PropertyStatus.reserved => AppColors.warn,
  PropertyStatus.partiallySold => AppColors.info,
  PropertyStatus.soldOut => AppColors.muted,
  PropertyStatus.inactive => AppColors.muted,
};

Color _statusBgColor(PropertyStatus s) => switch (s) {
  PropertyStatus.available => AppColors.brandLight,
  PropertyStatus.reserved => AppColors.warnLight,
  PropertyStatus.partiallySold => AppColors.infoLight,
  _ => AppColors.bg2,
};

String _typeLabel(PropertyType t) => switch (t) {
  PropertyType.land => 'Land',
  PropertyType.house => 'House',
  PropertyType.duplex => 'Duplex',
  PropertyType.bungalow => 'Bungalow',
  PropertyType.apartment => 'Apartment',
  PropertyType.estate => 'Estate',
  PropertyType.commercial => 'Commercial',
  PropertyType.office => 'Office',
};