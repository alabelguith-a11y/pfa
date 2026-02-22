class LogEntry {
  final DateTime timestamp;
  final String command;
  final String status;
  final String? detail;

  const LogEntry({
    required this.timestamp,
    required this.command,
    required this.status,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'command': command,
        'status': status,
        'detail': detail,
      };

  String toCsvRow() =>
      '${timestamp.toIso8601String()},$command,$status,${detail ?? ""}';

  static LogEntry fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      command: json['command'] as String,
      status: json['status'] as String,
      detail: json['detail'] as String?,
    );
  }
}
