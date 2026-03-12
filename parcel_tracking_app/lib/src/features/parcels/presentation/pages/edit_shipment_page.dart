import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_scope.dart';
import '../../data/firestore_shipments_repository.dart';
import '../../domain/shipment.dart';

class EditShipmentPage extends StatefulWidget {
  final String shipmentId;

  const EditShipmentPage({super.key, required this.shipmentId});

  @override
  State<EditShipmentPage> createState() => _EditShipmentPageState();
}

class _EditShipmentPageState extends State<EditShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _trackingNumberController = TextEditingController();
  final _locationController = TextEditingController();

  Shipment? _shipment;
  ShipmentStatus _status = ShipmentStatus.pending;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _trackingNumberController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _hydrateFromShipment(Shipment shipment) {
    if (_initialized) return;

    _shipment = shipment;
    _trackingNumberController.text = shipment.trackingNumber;
    _locationController.text = shipment.location;
    _status = shipment.normalizedStatus.isKnown
        ? shipment.normalizedStatus
        : ShipmentStatus.pending;
    _initialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _shipment == null) return;

    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    setState(() => _loading = true);

    try {
      final updatedShipment = Shipment(
        id: _shipment!.id,
        trackingNumber: _trackingNumberController.text.trim(),
        shippedAt: _shipment!.shippedAt,
        location: _locationController.text.trim(),
        status: _status.value,
      );

      await repository.updateShipment(
        previous: _shipment!,
        updated: updatedShipment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment updated successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating shipment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Shipment')),
      body: StreamBuilder<Shipment?>(
        stream: repository.watchShipment(widget.shipmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load shipment.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          final shipment = snapshot.data;
          if (shipment == null && !_initialized) {
            return Center(
              child: Text(
                'Shipment not found.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          if (shipment != null) {
            _hydrateFromShipment(shipment);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _trackingNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Tracking Number',
                      hintText: 'e.g. TRK123456789',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g. London, UK',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<ShipmentStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
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
                      setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
