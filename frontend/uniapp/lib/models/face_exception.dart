class FaceException implements Exception {
  final String message;

  FaceException(this.message);

  @override
  String toString() => 'FaceException: $message';
}
