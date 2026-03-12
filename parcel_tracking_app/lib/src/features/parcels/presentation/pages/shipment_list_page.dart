import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_scope.dart';
import '../../data/firestore_shipments_repository.dart';
import '../../domain/shipment.dart';

class ShipmentListPage extends StatefulWidget {
  const ShipmentListPage({super.key});

  @override
  State<ShipmentListPage> createState() => _ShipmentListPageState();
}

class _ShipmentListPageState extends State<ShipmentListPage> {
  final TextEditingController _searchController = TextEditingController();

  ShipmentFilter _selectedFilter = ShipmentFilter.all;
  ShipmentSort _selectedSort = ShipmentSort.newestFirst;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final ShipmentsRepository repository = AppScope.of(context).shipmentsRepository;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/shipments/add'),
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shipping Record',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/shipments/archived'),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archived'),
                  ),
                ],
              ),
            ),
            _SearchAndSortBar(
              controller: _searchController,
              selectedSort: _selectedSort,
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              onClearSearch: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              onSortChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedSort = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ShipmentFilter.values
                    .map(
                      (filter) => _FilterChip(
                        label: filter.label,
                        selected: _selectedFilter == filter,
                        onSelected: () {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 560 : double.infinity,
                  ),
                  child: StreamBuilder<List<Shipment>>(
                    stream: repository.watchCurrentUserShipments(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _ShipmentLoadingFallback();
                      }

                      if (snapshot.hasError) {
                        debugPrint(
                          'ShipmentListPage: StreamBuilder error: ${snapshot.error}',
                        );
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Failed to load shipments. Please try again later.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final shipments = snapshot.data ?? const <Shipment>[];
                      final visibleShipments = _applyFilters(shipments);

                      return Column(
                        children: [
                          _ResultsSummary(
                            totalCount: shipments.length,
                            visibleCount: visibleShipments.length,
                            selectedFilter: _selectedFilter,
                            selectedSort: _selectedSort,
                            searchQuery: _searchQuery,
                          ),
                          Expanded(
                            child: visibleShipments.isEmpty
                                ? _EmptyResultsState(
                                    hasAnyShipments: shipments.isNotEmpty,
                                    selectedFilter: _selectedFilter,
                                    searchQuery: _searchQuery,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    itemCount: visibleShipments.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final shipment = visibleShipments[index];
                                      final statusStyle = _statusStyleFor(
                                        shipment.normalizedStatus,
                                        context,
                                      );
                                      final dateLabel = DateFormat(
                                        'dd MMM yyyy',
                                      ).format(shipment.shippedAt);

                                      return _ShipmentCard(
                                        id: shipment.id,
                                        idNumber: shipment.id,
                                        trackingNumber: shipment.trackingNumber,
                                        dateShipped: dateLabel,
                                        location: shipment.location,
                                        statusLabel: statusStyle.label,
                                        statusColor: statusStyle.color,
                                        dark: index == 0,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (!isWide)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BottomNavIcon(
                      icon: Icons.home,
                      label: 'Home',
                      active: false,
                      onTap: () => context.go('/dashboard'),
                    ),
                    _BottomNavIcon(
                      icon: Icons.local_shipping_outlined,
                      label: 'Parcels',
                      active: true,
                      onTap: () {},
                    ),
                    _BottomNavIcon(
                      icon: Icons.notifications_none,
                      label: 'Alerts',
                      active: false,
                      onTap: () => context.go('/alerts'),
                    ),
                    _BottomNavIcon(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      active: false,
                      onTap: () => context.push('/profile'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Shipment> _applyFilters(List<Shipment> shipments) {
    final normalizedQuery = _searchQuery.toLowerCase();

    final filteredShipments = shipments.where((shipment) {
      final matchesStatus = _selectedFilter.matches(shipment.normalizedStatus);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          shipment.trackingNumber.toLowerCase().contains(normalizedQuery) ||
          shipment.location.toLowerCase().contains(normalizedQuery) ||
          shipment.id.toLowerCase().contains(normalizedQuery);

      return matchesStatus && matchesQuery;
    }).toList();

    filteredShipments.sort(_selectedSort.compare);
    return filteredShipments;
  }
}

enum ShipmentFilter {
  all('All'),
  complete('Complete'),
  inDelivery('In Delivery'),
  pending('Pending'),
  failed('Failed');

  const ShipmentFilter(this.label);

  final String label;

  bool matches(ShipmentStatus status) {
    if (this == ShipmentFilter.all) {
      return true;
    }

    return switch (this) {
      ShipmentFilter.all => true,
      ShipmentFilter.complete => status == ShipmentStatus.complete,
      ShipmentFilter.inDelivery => status == ShipmentStatus.inDelivery,
      ShipmentFilter.pending => status == ShipmentStatus.pending,
      ShipmentFilter.failed => status == ShipmentStatus.failed,
    };
  }
}

enum ShipmentSort {
  newestFirst('Newest'),
  oldestFirst('Oldest'),
  trackingNumber('Tracking #'),
  location('Location'),
  status('Status');

  const ShipmentSort(this.label);

  final String label;

  int compare(Shipment a, Shipment b) {
    return switch (this) {
      ShipmentSort.newestFirst => b.shippedAt.compareTo(a.shippedAt),
      ShipmentSort.oldestFirst => a.shippedAt.compareTo(b.shippedAt),
      ShipmentSort.trackingNumber => a.trackingNumber.toLowerCase().compareTo(
        b.trackingNumber.toLowerCase(),
      ),
      ShipmentSort.location =>
        a.location.toLowerCase().compareTo(b.location.toLowerCase()),
      ShipmentSort.status => a.normalizedStatus.label.compareTo(
        b.normalizedStatus.label,
      ),
    };
  }
}

class _SearchAndSortBar extends StatelessWidget {
  const _SearchAndSortBar({
    required this.controller,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final ShipmentSort selectedSort;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<ShipmentSort?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Search by tracking number, location, or ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Sort by',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                DropdownButton<ShipmentSort>(
                  value: selectedSort,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(16),
                  items: ShipmentSort.values
                      .map(
                        (sort) => DropdownMenuItem(
                          value: sort,
                          child: Text(sort.label),
                        ),
                      )
                      .toList(),
                  onChanged: onSortChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({
    required this.totalCount,
    required this.visibleCount,
    required this.selectedFilter,
    required this.selectedSort,
    required this.searchQuery,
  });

  final int totalCount;
  final int visibleCount;
  final ShipmentFilter selectedFilter;
  final ShipmentSort selectedSort;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final summaryParts = <String>[
      '$visibleCount result${visibleCount == 1 ? '' : 's'}',
      if (selectedFilter != ShipmentFilter.all) selectedFilter.label,
      'sorted by ${selectedSort.label.toLowerCase()}',
      if (searchQuery.isNotEmpty) 'for "$searchQuery"',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summaryParts.join(' • '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (totalCount > 0)
            Text(
              '$totalCount total',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.black45,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyResultsState extends StatelessWidget {
  const _EmptyResultsState({
    required this.hasAnyShipments,
    required this.selectedFilter,
    required this.searchQuery,
  });

  final bool hasAnyShipments;
  final ShipmentFilter selectedFilter;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final title = hasAnyShipments ? 'No matching shipments' : 'No shipments yet';
    final message = hasAnyShipments
        ? _buildFilteredMessage()
        : 'Add your first shipment to start tracking parcels.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _buildFilteredMessage() {
    final fragments = <String>[];

    if (selectedFilter != ShipmentFilter.all) {
      fragments.add(selectedFilter.label.toLowerCase());
    }

    if (searchQuery.isNotEmpty) {
      fragments.add('matching "$searchQuery"');
    }

    if (fragments.isEmpty) {
      return 'Try updating your search or sort settings.';
    }

    return 'No shipments found ${fragments.join(' ')}. Try adjusting your filters.';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Colors.black,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final String id;
  final String idNumber;
  final String trackingNumber;
  final String dateShipped;
  final String location;
  final String statusLabel;
  final Color statusColor;
  final bool dark;

  const _ShipmentCard({
    required this.id,
    required this.idNumber,
    required this.trackingNumber,
    required this.dateShipped,
    required this.location,
    required this.statusLabel,
    required this.statusColor,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = dark ? const Color(0xFF111827) : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: isCompact
                        ? constraints.maxWidth
                        : constraints.maxWidth - 110,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.local_shipping,
                            size: 18,
                            color: dark ? Colors.white : const Color(0xFFFF9800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID Number',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                              ),
                              Text(
                                idNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _InfoColumn(
                    label: 'Tracking Number',
                    value: trackingNumber,
                    color: textColor,
                  ),
                  _InfoColumn(
                    label: 'Date Shipped',
                    value: dateShipped,
                    color: textColor,
                  ),
                  _InfoColumn(
                    label: 'Location',
                    value: location,
                    color: textColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => context.push('/shipments/$id'),
                    icon: Icon(
                      Icons.navigation_outlined,
                      color: dark ? Colors.orangeAccent : const Color(0xFFFF9800),
                      size: 18,
                    ),
                    label: Text(
                      'Track',
                      style: TextStyle(
                        color: dark ? Colors.orangeAccent : const Color(0xFFFF9800),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/shipments/$id'),
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({required this.label, required this.color});

  final String label;
  final Color color;
}

_StatusStyle _statusStyleFor(ShipmentStatus status, BuildContext context) {
  switch (status) {
    case ShipmentStatus.complete:
      return const _StatusStyle(label: 'Complete', color: Color(0xFF4CAF50));
    case ShipmentStatus.inDelivery:
      return const _StatusStyle(label: 'In Delivery', color: Color(0xFFFFA726));
    case ShipmentStatus.pending:
      return const _StatusStyle(label: 'Pending', color: Color(0xFF9E9E9E));
    case ShipmentStatus.failed:
      return const _StatusStyle(label: 'Failed', color: Color(0xFFDC2626));
    default:
      return _StatusStyle(
        label: status.label,
        color: Theme.of(context).colorScheme.primary,
      );
  }
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.black : Colors.black45;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipmentLoadingFallback extends StatefulWidget {
  const _ShipmentLoadingFallback();

  @override
  State<_ShipmentLoadingFallback> createState() =>
      _ShipmentLoadingFallbackState();
}

class _ShipmentLoadingFallbackState extends State<_ShipmentLoadingFallback> {
  bool _showOfflineHint = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _showOfflineHint = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOfflineHint) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            Text(
              'Still loading shipments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This phone may be offline or still waiting for its first sync. Connect to the internet once and reopen Parcels.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
