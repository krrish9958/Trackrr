import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_scope.dart';
import '../../data/firestore_shipments_repository.dart';
import '../../domain/shipment.dart';
import '../../domain/shipment_event.dart';

class ShipmentDetailPage extends StatefulWidget {
  final String shipmentId;

  const ShipmentDetailPage({super.key, required this.shipmentId});

  @override
  State<ShipmentDetailPage> createState() => _ShipmentDetailPageState();
}

class _ShipmentDetailPageState extends State<ShipmentDetailPage> {
  bool _isArchiving = false;
  bool _isRestoring = false;
  bool _isAddingEvent = false;

  Future<void> _archiveShipment() async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive shipment?'),
          content: const Text(
            'This will hide the shipment from active views while keeping its timeline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (shouldArchive != true || !mounted) {
      return;
    }

    setState(() => _isArchiving = true);
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    try {
      await repository.archiveShipment(widget.shipmentId);

      if (!mounted) {
        return;
      }

      setState(() => _isArchiving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipment archived.')),
      );
      context.go('/shipments');
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to archive shipment: $e')),
      );
      setState(() => _isArchiving = false);
    }
  }

  Future<void> _showAddEventSheet(Shipment shipment) async {
    final result = await showModalBottomSheet<_ShipmentEventDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddShipmentEventSheet(shipment: shipment),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() => _isAddingEvent = true);
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    try {
      await repository.addShipmentEvent(
        shipment: shipment,
        status: result.status,
        title: result.title,
        description: result.description,
        location: result.location,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking event added.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add event: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingEvent = false);
      }
    }
  }

  Future<void> _restoreShipment() async {
    setState(() => _isRestoring = true);
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    try {
      await repository.restoreShipment(widget.shipmentId);

      if (!mounted) {
        return;
      }

      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipment restored.')),
      );
      context.go('/shipments');
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore shipment: $e')),
      );
      setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Track Shipment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/shipments');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isArchiving || _isRestoring
                ? null
                : () => context.push('/shipments/${widget.shipmentId}/edit'),
          ),
          (_isArchiving || _isRestoring)
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: _archiveShipment,
                ),
        ],
      ),
      body: StreamBuilder<Shipment?>(
        stream: repository.watchShipment(widget.shipmentId),
        builder: (context, shipmentSnapshot) {
          if (shipmentSnapshot.connectionState == ConnectionState.waiting) {
            return const _DetailLoadingState();
          }
          if (shipmentSnapshot.hasError) {
            return _DetailMessageState(
              message: 'Failed to load shipment.',
              child: Center(
                child: Text(
                  'Failed to load shipment.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          final shipment = shipmentSnapshot.data;
          if (shipment == null) {
            return _DetailMessageState(
              message: 'Shipment not found.',
              child: Center(
                child: Text(
                  'Shipment not found.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          return StreamBuilder<List<ShipmentEvent>>(
            stream: repository.watchShipmentEvents(widget.shipmentId),
            builder: (context, eventsSnapshot) {
              if (eventsSnapshot.connectionState == ConnectionState.waiting) {
                return _DetailLoadingState(shipment: shipment);
              }
              if (eventsSnapshot.hasError) {
                return _DetailMessageState(
                  message: 'Failed to load shipment history.',
                  child: Center(
                    child: Text(
                      'Failed to load shipment history.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }

              final events = eventsSnapshot.data ?? const <ShipmentEvent>[];
              final latestEvent = events.isNotEmpty ? events.first : null;
              final shippedAtLabel = DateFormat('dd MMM yyyy, HH:mm').format(shipment.shippedAt);
              final progressValue = _progressValueFor(shipment.normalizedStatus);

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: ListView(
                  key: ValueKey('${shipment.id}-${events.length}-${shipment.isArchived}'),
                  padding: const EdgeInsets.all(16),
                  children: [
                  if (shipment.isArchived) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.archive_outlined, color: Color(0xFF6B7280)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This shipment is archived and hidden from active views.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonal(
                            onPressed: _isRestoring ? null : _restoreShipment,
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _StatusSummaryCard(
                    trackingNumber: shipment.trackingNumber,
                    statusLabel: shipment.normalizedStatus.label,
                    statusColor: _statusColorFor(shipment.normalizedStatus),
                    progressValue: progressValue,
                    location: shipment.location,
                    shippedAtLabel: shippedAtLabel,
                  ),
                  const SizedBox(height: 16),
                  _CurrentCheckpointCard(
                    title: latestEvent?.title ?? 'Shipment created',
                    description: latestEvent?.description ??
                        'Shipment is waiting for the next status update.',
                    statusLabel: shipment.normalizedStatus.label,
                    statusColor: _statusColorFor(shipment.normalizedStatus),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tracking Timeline',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: shipment.isArchived || _isArchiving || _isRestoring || _isAddingEvent
                                    ? null
                                    : () => _showAddEventSheet(shipment),
                                icon: _isAddingEvent
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: Text(
                                  _isAddingEvent ? 'Saving...' : 'Add Event',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (events.isEmpty)
                            Text(
                              'No tracking events yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            ...List.generate(
                              events.length,
                              (index) => _TimelineTile(
                                event: events[index],
                                accentColor: _statusColorFor(events[index].status),
                                isLast: index == events.length - 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shipment Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _DetailStat(label: 'Shipment ID', value: shipment.id),
                              _DetailStat(
                                label: 'Tracking Number',
                                value: shipment.trackingNumber,
                              ),
                              _DetailStat(
                                label: 'Current Location',
                                value: shipment.location,
                              ),
                              _DetailStat(
                                label: 'Status',
                                value: shipment.normalizedStatus.label,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShipmentEventDraft {
  const _ShipmentEventDraft({
    required this.status,
    required this.title,
    required this.description,
    required this.location,
  });

  final ShipmentStatus status;
  final String title;
  final String description;
  final String location;
}

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState({this.shipment});

  final Shipment? shipment;

  @override
  Widget build(BuildContext context) {
    final status = shipment?.normalizedStatus ?? ShipmentStatus.pending;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusSummaryCard(
          trackingNumber: shipment?.trackingNumber ?? 'Loading...',
          statusLabel: status.label,
          statusColor: _statusColorFor(status),
          progressValue: shipment == null ? 0.2 : _progressValueFor(status),
          location: shipment?.location ?? 'Fetching latest shipment details',
          shippedAtLabel: shipment == null
              ? 'Syncing shipment timeline'
              : DateFormat('dd MMM yyyy, HH:mm').format(shipment!.shippedAt),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Loading shipment timeline...'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailMessageState extends StatelessWidget {
  const _DetailMessageState({
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(message),
        child: child,
      ),
    );
  }
}

class _AddShipmentEventSheet extends StatefulWidget {
  const _AddShipmentEventSheet({required this.shipment});

  final Shipment shipment;

  @override
  State<_AddShipmentEventSheet> createState() => _AddShipmentEventSheetState();
}

class _AddShipmentEventSheetState extends State<_AddShipmentEventSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late ShipmentStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.shipment.normalizedStatus.isKnown
        ? widget.shipment.normalizedStatus
        : ShipmentStatus.pending;
    _locationController = TextEditingController(text: widget.shipment.location);
    _titleController = TextEditingController(
      text: _defaultTitleFor(_status),
    );
    _descriptionController = TextEditingController(
      text: _defaultDescriptionFor(_status, widget.shipment.location),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Tracking Event',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    'This updates the shipment timeline and current status.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<ShipmentStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                    ),
                    items: ShipmentStatus.values
                        .where((status) => status != ShipmentStatus.unknown)
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                        _titleController.text = _defaultTitleFor(value);
                        _descriptionController.text = _defaultDescriptionFor(
                          value,
                          _locationController.text.trim(),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Event title'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                    onChanged: (value) {
                      if (_descriptionController.text.isEmpty) {
                        return;
                      }
                    },
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Save Event'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _ShipmentEventDraft(
        status: _status,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  final String trackingNumber;
  final String statusLabel;
  final Color statusColor;
  final double progressValue;
  final String location;
  final String shippedAtLabel;

  const _StatusSummaryCard({
    required this.trackingNumber,
    required this.statusLabel,
    required this.statusColor,
    required this.progressValue,
    required this.location,
    required this.shippedAtLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Number',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      trackingNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 8,
            color: statusColor,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _SummaryMeta(
                icon: Icons.pin_drop_outlined,
                label: 'Current checkpoint',
                value: location,
              ),
              _SummaryMeta(
                icon: Icons.schedule_outlined,
                label: 'Shipped at',
                value: shippedAtLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white60,
              ),
            ),
            SizedBox(
              width: 160,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrentCheckpointCard extends StatelessWidget {
  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;

  const _CurrentCheckpointCard({
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.route_outlined, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ShipmentEvent event;
  final Color accentColor;
  final bool isLast;

  const _TimelineTile({
    required this.event,
    required this.accentColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('dd MMM, HH:mm').format(event.occurredAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                   color: accentColor.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

double _progressValueFor(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.pending => 0.25,
    ShipmentStatus.inDelivery => 0.7,
    ShipmentStatus.complete => 1.0,
    ShipmentStatus.failed => 1.0,
    ShipmentStatus.unknown => 0.15,
  };
}

Color _statusColorFor(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.complete => const Color(0xFF16A34A),
    ShipmentStatus.inDelivery => const Color(0xFFF59E0B),
    ShipmentStatus.pending => const Color(0xFF6B7280),
    ShipmentStatus.failed => const Color(0xFFDC2626),
    ShipmentStatus.unknown => const Color(0xFF2563EB),
  };
}

String _defaultTitleFor(ShipmentStatus status) {
  return switch (status) {
    ShipmentStatus.pending => 'Awaiting next checkpoint',
    ShipmentStatus.inDelivery => 'Package is in transit',
    ShipmentStatus.complete => 'Package delivered',
    ShipmentStatus.failed => 'Delivery issue reported',
    ShipmentStatus.unknown => 'Shipment updated',
  };
}

String _defaultDescriptionFor(ShipmentStatus status, String location) {
  final normalizedLocation = location.trim().isEmpty ? 'the current facility' : location.trim();

  return switch (status) {
    ShipmentStatus.pending =>
      'Shipment is registered and awaiting the next scan at $normalizedLocation.',
    ShipmentStatus.inDelivery =>
      'Shipment is moving through the network near $normalizedLocation.',
    ShipmentStatus.complete =>
      'Shipment was delivered successfully in $normalizedLocation.',
    ShipmentStatus.failed =>
      'A delivery problem was reported near $normalizedLocation.',
    ShipmentStatus.unknown => 'Shipment details were updated.',
  };
}
