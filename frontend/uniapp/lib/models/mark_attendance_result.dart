class MarkAttendanceResult {
  final bool isSuccessful;
  final String message;
  final bool isOffline;

  MarkAttendanceResult({
    required this.isSuccessful,
    required this.message,
    this.isOffline = false,
  });
}
