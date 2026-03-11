class AlertItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? shipmentId;
  final AlertKind kind;

  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.shipmentId,
    required this.kind,
  });
}

enum AlertKind {
  info,
  warning,
  success,
  error,
}
