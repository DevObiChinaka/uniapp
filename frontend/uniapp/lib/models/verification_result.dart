class VerificationResult {
  final bool isSuccessful;
  final String message;
  final double? confidence;

  VerificationResult({
    required this.isSuccessful,
    required this.message,
    this.confidence,
  });
}
