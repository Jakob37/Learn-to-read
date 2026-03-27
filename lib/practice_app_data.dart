part of 'main.dart';

abstract class ProgressStore {
  Future<Map<PracticeCollection, List<LetterProgress>>> loadProgress();
  Future<void> saveProgress(
    Map<PracticeCollection, List<LetterProgress>> progress,
  );
}

abstract class CollectionStore {
  Future<Map<PracticeCollection, List<String>>> loadCollections();
  Future<void> saveCollection(
    PracticeCollection collection,
    List<String> items,
  );
}

class PracticeAppSnapshot {
  const PracticeAppSnapshot({
    required this.progress,
    required this.collectionItems,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final Map<PracticeCollection, List<LetterProgress>> progress;
  final Map<PracticeCollection, List<String>> collectionItems;

  PracticeAppSnapshot copyWith({
    Map<PracticeCollection, List<LetterProgress>>? progress,
    Map<PracticeCollection, List<String>>? collectionItems,
  }) {
    return PracticeAppSnapshot(
      progress: progress ?? this.progress,
      collectionItems: collectionItems ?? this.collectionItems,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'progress': <String, dynamic>{
        for (final MapEntry<PracticeCollection, List<LetterProgress>> entry
            in progress.entries)
          entry.key.id: entry.value
              .map((LetterProgress item) => item.toJson())
              .toList(),
      },
      'collections': <String, dynamic>{
        for (final MapEntry<PracticeCollection, List<String>> entry
            in collectionItems.entries)
          if (entry.key.isEditableWordSet) entry.key.id: entry.value,
      },
    };
  }

  static PracticeAppSnapshot fromJson(Map<String, dynamic> json) {
    final Map<PracticeCollection, List<LetterProgress>> progress =
        _emptyProgressMap();
    final Map<PracticeCollection, List<String>> collectionItems =
        _defaultCollectionItems();

    final dynamic rawProgress = json['progress'];
    if (rawProgress is Map) {
      for (final PracticeCollection collection in PracticeCollection.values) {
        final dynamic items = rawProgress[collection.id];
        if (items is! List<dynamic>) {
          continue;
        }
        progress[collection] = items
            .map(
              (dynamic entry) => LetterProgress.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ),
            )
            .toList();
      }
    }

    final dynamic rawCollections = json['collections'];
    if (rawCollections is Map) {
      for (final PracticeCollection collection in PracticeCollection.values) {
        if (!collection.isEditableWordSet) {
          continue;
        }
        final dynamic items = rawCollections[collection.id];
        if (items is! List<dynamic>) {
          continue;
        }
        collectionItems[collection] = items
            .map((dynamic item) => item as String)
            .toList();
      }
    }

    return PracticeAppSnapshot(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ??
          PracticeAppSnapshot.currentSchemaVersion,
      progress: progress,
      collectionItems: collectionItems,
    );
  }
}

class SharedPreferencesAppDataStore {
  const SharedPreferencesAppDataStore({
    LearnToReadBackupService? backupService,
    LearnToReadBackupPreferences? backupPreferences,
  }) : _backupService = backupService ?? const LearnToReadBackupService(),
       _backupPreferences =
           backupPreferences ?? const LearnToReadBackupPreferences();

  static const String _snapshotKey = 'learn_to_read.snapshot_v1';
  static const String _legacyProgressKey = 'practice_progress_v1';
  static const String _legacyCollectionsKey = 'practice_collections_v1';

  final LearnToReadBackupService _backupService;
  final LearnToReadBackupPreferences _backupPreferences;

  Future<PracticeAppSnapshot> loadSnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawSnapshot = prefs.getString(_snapshotKey);
    if (rawSnapshot != null && rawSnapshot.isNotEmpty) {
      final dynamic decoded = _tryDecodeJson(rawSnapshot);
      if (decoded is Map<String, dynamic>) {
        return PracticeAppSnapshot.fromJson(decoded);
      }
      if (decoded is Map) {
        return PracticeAppSnapshot.fromJson(Map<String, dynamic>.from(decoded));
      }
    }

    return _loadLegacySnapshot(prefs);
  }

  Future<void> saveSnapshot(
    PracticeAppSnapshot snapshot, {
    bool forceBackup = false,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, exportAsJsonString(snapshot));
    await prefs.remove(_legacyProgressKey);
    await prefs.remove(_legacyCollectionsKey);

    if (await _backupPreferences.loadAutomaticBackupsEnabled()) {
      await _backupService.saveAutomaticBackup(
        exportAsJsonString(snapshot),
        force: forceBackup,
      );
    }
  }

  String exportAsJsonString(PracticeAppSnapshot snapshot) {
    return const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
  }

  Future<PracticeAppSnapshot> importFromJsonString(
    String rawPayload, {
    bool forceBackup = true,
  }) async {
    final dynamic decoded = _tryDecodeJson(rawPayload);
    if (decoded is! Map) {
      throw const FormatException('Invalid JSON payload.');
    }

    final PracticeAppSnapshot snapshot = PracticeAppSnapshot.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    await saveSnapshot(snapshot, forceBackup: forceBackup);
    return snapshot;
  }

  Future<Map<PracticeCollection, List<LetterProgress>>> loadProgress() async {
    return (await loadSnapshot()).progress;
  }

  Future<void> saveProgress(
    Map<PracticeCollection, List<LetterProgress>> progress,
  ) async {
    final PracticeAppSnapshot current = await loadSnapshot();
    await saveSnapshot(current.copyWith(progress: progress));
  }

  Future<Map<PracticeCollection, List<String>>> loadCollections() async {
    return (await loadSnapshot()).collectionItems;
  }

  Future<void> saveCollection(
    PracticeCollection collection,
    List<String> items,
  ) async {
    final PracticeAppSnapshot current = await loadSnapshot();
    final Map<PracticeCollection, List<String>> nextCollections =
        <PracticeCollection, List<String>>{
          for (final MapEntry<PracticeCollection, List<String>> entry
              in current.collectionItems.entries)
            entry.key: List<String>.from(entry.value),
        };
    nextCollections[collection] = List<String>.from(items);
    await saveSnapshot(current.copyWith(collectionItems: nextCollections));
  }

  Future<bool> loadAutomaticBackupsEnabled() {
    return _backupPreferences.loadAutomaticBackupsEnabled();
  }

  Future<void> saveAutomaticBackupsEnabled(bool enabled) async {
    await _backupPreferences.saveAutomaticBackupsEnabled(enabled);
  }

  Future<void> saveAutomaticBackupNow(PracticeAppSnapshot snapshot) {
    return _backupService.saveAutomaticBackup(
      exportAsJsonString(snapshot),
      force: true,
    );
  }

  Future<List<LearnToReadBackupEntry>> listAutomaticBackups() {
    return _backupService.listBackups();
  }

  Future<PracticeAppSnapshot> restoreAutomaticBackup(String backupId) async {
    final String backupJson = await _backupService.readBackup(backupId);
    final PracticeAppSnapshot snapshot = await importFromJsonString(
      backupJson,
      forceBackup: false,
    );
    if (await _backupPreferences.loadAutomaticBackupsEnabled()) {
      await saveAutomaticBackupNow(snapshot);
    }
    return snapshot;
  }

  Future<PracticeAppSnapshot> _loadLegacySnapshot(
    SharedPreferences prefs,
  ) async {
    final Map<PracticeCollection, List<LetterProgress>> progress =
        _emptyProgressMap();
    final Map<PracticeCollection, List<String>> collections =
        _defaultCollectionItems();

    final String? rawProgress = prefs.getString(_legacyProgressKey);
    if (rawProgress != null && rawProgress.isNotEmpty) {
      final dynamic decoded = _tryDecodeJson(rawProgress);
      if (decoded is Map) {
        for (final PracticeCollection collection in PracticeCollection.values) {
          final dynamic items = decoded[collection.id];
          if (items is! List<dynamic>) {
            continue;
          }
          progress[collection] = items
              .map(
                (dynamic entry) => LetterProgress.fromJson(
                  Map<String, dynamic>.from(entry as Map),
                ),
              )
              .toList();
        }
      }
    }

    final String? rawCollections = prefs.getString(_legacyCollectionsKey);
    if (rawCollections != null && rawCollections.isNotEmpty) {
      final dynamic decoded = _tryDecodeJson(rawCollections);
      if (decoded is Map) {
        for (final PracticeCollection collection in PracticeCollection.values) {
          if (!collection.isEditableWordSet) {
            continue;
          }
          final dynamic items = decoded[collection.id];
          if (items is! List<dynamic>) {
            continue;
          }
          collections[collection] = items
              .map((dynamic item) => item as String)
              .toList();
        }
      }
    }

    return PracticeAppSnapshot(
      progress: progress,
      collectionItems: collections,
    );
  }

  dynamic _tryDecodeJson(String rawPayload) {
    try {
      return jsonDecode(rawPayload);
    } on FormatException {
      return null;
    }
  }
}

class SharedPreferencesProgressStore implements ProgressStore {
  const SharedPreferencesProgressStore({
    SharedPreferencesAppDataStore? appDataStore,
  }) : _appDataStore = appDataStore ?? const SharedPreferencesAppDataStore();

  final SharedPreferencesAppDataStore _appDataStore;

  @override
  Future<Map<PracticeCollection, List<LetterProgress>>> loadProgress() async {
    return _appDataStore.loadProgress();
  }

  @override
  Future<void> saveProgress(
    Map<PracticeCollection, List<LetterProgress>> progress,
  ) async {
    await _appDataStore.saveProgress(progress);
  }
}

class SharedPreferencesCollectionStore implements CollectionStore {
  const SharedPreferencesCollectionStore({
    SharedPreferencesAppDataStore? appDataStore,
  }) : _appDataStore = appDataStore ?? const SharedPreferencesAppDataStore();

  final SharedPreferencesAppDataStore _appDataStore;

  @override
  Future<Map<PracticeCollection, List<String>>> loadCollections() async {
    return _appDataStore.loadCollections();
  }

  @override
  Future<void> saveCollection(
    PracticeCollection collection,
    List<String> items,
  ) async {
    await _appDataStore.saveCollection(collection, items);
  }
}
