class SyncStatus {
  final int totalRecords;
  final int syncedRecords;
  final DateTime? lastSyncAttempt;
  final bool isCurrentlySyncing;
  final String? lastError;

  SyncStatus({
    required this.totalRecords,
    required this.syncedRecords,
    this.lastSyncAttempt,
    this.isCurrentlySyncing = false,
    this.lastError,
  });

  double get syncProgress =>
      totalRecords > 0 ? syncedRecords / totalRecords : 0.0;

  bool get isSynced => syncedRecords == totalRecords;

  SyncStatus copyWith({
    int? totalRecords,
    int? syncedRecords,
    DateTime? lastSyncAttempt,
    bool? isCurrentlySyncing,
    String? lastError,
  }) {
    return SyncStatus(
      totalRecords: totalRecords ?? this.totalRecords,
      syncedRecords: syncedRecords ?? this.syncedRecords,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      isCurrentlySyncing: isCurrentlySyncing ?? this.isCurrentlySyncing,
      lastError: lastError,
    );
  }

  factory SyncStatus.initial() => SyncStatus(totalRecords: 0, syncedRecords: 0);
}
