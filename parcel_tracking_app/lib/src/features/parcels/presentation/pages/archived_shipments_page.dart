import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_scope.dart';
import '../../data/firestore_shipments_repository.dart';
import '../../domain/shipment.dart';

class ArchivedShipmentsPage extends StatelessWidget {
  const ArchivedShipmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ShipmentsRepository repository =
        AppScope.of(context).shipmentsRepository;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Archived Shipments'),
      ),
      body: StreamBuilder<List<Shipment>>(
        stream: repository.watchArchivedShipments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load archived shipments.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final shipments = snapshot.data ?? const <Shipment>[];
          if (shipments.isEmpty) {
            return Center(
              child: Text(
                'No archived shipments yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shipments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final shipment = shipments[index];
              return _ArchivedShipmentCard(shipment: shipment);
            },
          );
        },
      ),
    );
  }
}

class _ArchivedShipmentCard extends StatelessWidget {
  const _ArchivedShipmentCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final ShipmentsRepository repository =
        AppScope.of(context).shipmentsRepository;
    final shippedLabel = DateFormat('dd MMM yyyy').format(shipment.shippedAt);

    final viewButton = TextButton(
      onPressed: () => context.push('/shipments/${shipment.id}'),
      child: const Text('View Details'),
    );
    final restoreButton = FilledButton.tonal(
      onPressed: () async {
        await repository.restoreShipment(shipment.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shipment restored.')),
          );
        }
      },
      child: const Text('Restore'),
    );
    final deleteButton = TextButton(
      onPressed: () => _confirmPermanentDelete(context, repository),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFDC2626),
      ),
      child: const Text('Delete Permanently'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shipment.trackingNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B7280).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Archived',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              shipment.location,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              shippedLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                  ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      viewButton,
                      const SizedBox(height: 8),
                      restoreButton,
                      const SizedBox(height: 8),
                      deleteButton,
                    ],
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    viewButton,
                    restoreButton,
                    deleteButton,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    ShipmentsRepository repository,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete permanently?'),
          content: const Text(
            'This will permanently remove the shipment, timeline, and alerts. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    await repository.deleteShipment(shipment.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipment deleted permanently.')),
      );
    }
  }
}
