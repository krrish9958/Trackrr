class AlertItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? shipmentId;
  final AlertKind kind;
  final bool isRead;

  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.shipmentId,
    required this.kind,
    required this.isRead,
  });
}

enum AlertKind {
  info,
  warning,
  success,
  error,
}
