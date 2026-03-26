import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_version.dart';

void main() {
  runApp(const LetterLearningApp());
}

class LetterLearningApp extends StatelessWidget {
  const LetterLearningApp({
    super.key,
    this.speaker,
    this.progressStore,
    this.collectionStore,
  });

  final LetterSpeaker? speaker;
  final ProgressStore? progressStore;
  final CollectionStore? collectionStore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFEF8354),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Learn To Read',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF9F3E8),
        useMaterial3: true,
      ),
      home: PracticeHomePage(
        speaker: speaker ?? FlutterLetterSpeaker(),
        progressStore: progressStore ?? SharedPreferencesProgressStore(),
        collectionStore: collectionStore ?? SharedPreferencesCollectionStore(),
      ),
    );
  }
}

abstract class LetterSpeaker {
  Future<void> speakItem(String item);
  Future<void> dispose();
}

class FlutterLetterSpeaker implements LetterSpeaker {
  FlutterLetterSpeaker() : _tts = FlutterTts() {
    _configuration = _configureTts(_tts);
  }

  static const String _swedishLocale = 'sv-SE';

  static Future<void> _configureTts(FlutterTts tts) async {
    await tts.setLanguage(_swedishLocale);
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.42);
    await tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;
  late final Future<void> _configuration;

  @override
  Future<void> speakItem(String item) async {
    try {
      await _configuration;
      await _tts.stop();
      await _tts.speak(item);
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('Speech plugin unavailable on this platform.');
      }
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to speak item: $error');
      }
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _configuration;
      await _tts.stop();
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('Speech plugin unavailable during dispose.');
      }
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to stop speech: $error');
      }
    }
  }
}

enum PracticeCollection {
  uppercaseLetters(
    id: 'uppercase',
    label: 'ABC',
    title: 'Uppercase letters',
    promptNoun: 'letter',
    defaultItems: <String>[
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
      'J',
      'K',
      'L',
      'M',
      'N',
      'O',
      'P',
      'Q',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ],
  ),
  lowercaseLetters(
    id: 'lowercase',
    label: 'abc',
    title: 'Lowercase letters',
    promptNoun: 'letter',
    defaultItems: <String>[
      'a',
      'b',
      'c',
      'd',
      'e',
      'f',
      'g',
      'h',
      'i',
      'j',
      'k',
      'l',
      'm',
      'n',
      'o',
      'p',
      'q',
      'r',
      's',
      't',
      'u',
      'v',
      'w',
      'x',
      'y',
      'z',
    ],
  ),
  twoLetterWords(
    id: 'two_letter_words',
    label: '2-letter',
    title: 'Two-letter words',
    promptNoun: 'word',
    defaultItems: <String>[
      'av',
      'du',
      'ej',
      'en',
      'er',
      'et',
      'få',
      'gå',
      'ha',
      'ja',
      'ju',
      'må',
      'ni',
      'nu',
      'om',
      'på',
      'se',
      'så',
      'ta',
      'ur',
      'ut',
      'vi',
      'är',
      'åt',
    ],
  ),
  threeLetterWords(
    id: 'three_letter_words',
    label: '3-letter',
    title: 'Three-letter words',
    promptNoun: 'word',
    defaultItems: <String>[
      'apa',
      'ben',
      'bil',
      'bok',
      'bur',
      'bus',
      'dag',
      'dig',
      'eko',
      'eld',
      'fem',
      'fin',
      'fot',
      'gul',
      'hav',
      'hem',
      'hög',
      'jul',
      'kul',
      'lek',
      'mat',
      'mus',
      'sol',
      'sur',
    ],
  );

  const PracticeCollection({
    required this.id,
    required this.label,
    required this.title,
    required this.promptNoun,
    required this.defaultItems,
  });

  final String id;
  final String label;
  final String title;
  final String promptNoun;
  final List<String> defaultItems;

  bool get isEditableWordSet =>
      this == PracticeCollection.twoLetterWords ||
      this == PracticeCollection.threeLetterWords;
}

enum LetterRating { known, hard, notYet }

enum SessionPlan {
  quick(label: 'Quick 5', itemLimit: 5),
  focused(label: 'Focused 10', itemLimit: 10),
  full(label: 'Full set', itemLimit: null),
  continuous(label: 'Continuous', itemLimit: null, isContinuous: true);

  const SessionPlan({
    required this.label,
    required this.itemLimit,
    this.isContinuous = false,
  });

  final String label;
  final int? itemLimit;
  final bool isContinuous;
}

enum ReviewMode {
  balanced(label: 'Balanced'),
  reviewOnly(label: 'Review only');

  const ReviewMode({required this.label});

  final String label;
}

class LetterProgress {
  const LetterProgress({required this.item, required this.rating});

  final String item;
  final LetterRating rating;

  Map<String, String> toJson() {
    return <String, String>{'item': item, 'rating': rating.name};
  }

  static LetterProgress fromJson(Map<String, dynamic> json) {
    return LetterProgress(
      item: json['item'] as String,
      rating: LetterRating.values.byName(json['rating'] as String),
    );
  }
}

class ReviewItemState {
  const ReviewItemState({
    required this.item,
    required this.rating,
    required this.intervalSteps,
    required this.ease,
    required this.dueStep,
    required this.reviewCount,
  });

  final String item;
  final LetterRating? rating;
  final int intervalSteps;
  final double ease;
  final int dueStep;
  final int reviewCount;

  bool get isSeen => rating != null;
  bool get isDue => isSeen && dueStep <= reviewCount;
  bool get isKnownNow => rating == LetterRating.known;
}

class ReviewScheduler {
  static const double _startingEase = 2.3;
  static const double _minimumEase = 1.3;
  static const double _maximumEase = 3.0;

  static Map<String, ReviewItemState> buildStates(
    PracticeCollection collection,
    List<LetterProgress> responses, {
    List<String>? items,
  }) {
    final collectionItems = items ?? collection.defaultItems;
    final states = <String, ReviewItemState>{
      for (final item in collectionItems)
        item: ReviewItemState(
          item: item,
          rating: null,
          intervalSteps: 0,
          ease: _startingEase,
          dueStep: 0,
          reviewCount: responses.length,
        ),
    };

    for (var index = 0; index < responses.length; index++) {
      final response = responses[index];
      final current = states[response.item];
      if (current == null) {
        continue;
      }

      final nextReviewCount = index + 1;
      states[response.item] = _applyRating(
        current,
        response.rating,
        nextReviewCount,
      );
    }

    return <String, ReviewItemState>{
      for (final entry in states.entries)
        entry.key: ReviewItemState(
          item: entry.value.item,
          rating: entry.value.rating,
          intervalSteps: entry.value.intervalSteps,
          ease: entry.value.ease,
          dueStep: entry.value.dueStep,
          reviewCount: responses.length,
        ),
    };
  }

  static ReviewItemState _applyRating(
    ReviewItemState current,
    LetterRating rating,
    int reviewCount,
  ) {
    switch (rating) {
      case LetterRating.notYet:
        return ReviewItemState(
          item: current.item,
          rating: rating,
          intervalSteps: 0,
          ease: (current.ease - 0.2).clamp(_minimumEase, _maximumEase),
          dueStep: reviewCount,
          reviewCount: reviewCount,
        );
      case LetterRating.hard:
        final nextInterval = current.intervalSteps <= 1
            ? 1
            : (current.intervalSteps * 1.2).round().clamp(1, 9999);
        return ReviewItemState(
          item: current.item,
          rating: rating,
          intervalSteps: nextInterval,
          ease: (current.ease - 0.15).clamp(_minimumEase, _maximumEase),
          dueStep: reviewCount + nextInterval,
          reviewCount: reviewCount,
        );
      case LetterRating.known:
        final nextInterval = switch (current.intervalSteps) {
          <= 1 => 4,
          _ => (current.intervalSteps * current.ease).round().clamp(
            current.intervalSteps + 1,
            9999,
          ),
        };
        return ReviewItemState(
          item: current.item,
          rating: rating,
          intervalSteps: nextInterval,
          ease: (current.ease + 0.05).clamp(_minimumEase, _maximumEase),
          dueStep: reviewCount + nextInterval,
          reviewCount: reviewCount,
        );
    }
  }

  static bool isCollectionMastered(
    PracticeCollection collection,
    List<LetterProgress> responses, {
    List<String>? items,
  }) {
    final collectionItems = items ?? collection.defaultItems;
    final states = buildStates(collection, responses, items: collectionItems);
    return collectionItems.every((item) {
      final state = states[item]!;
      return state.isSeen && state.isKnownNow && !state.isDue;
    });
  }

  static String? chooseNextItem(
    PracticeCollection collection,
    List<LetterProgress> responses, {
    bool includeUnseen = true,
    Set<String> excludedItems = const <String>{},
    List<String>? items,
  }) {
    final collectionItems = items ?? collection.defaultItems;
    final states = buildStates(collection, responses, items: collectionItems);
    final dueItems = <ReviewItemState>[];
    final unseenItems = <String>[];

    for (final item in collectionItems) {
      if (excludedItems.contains(item)) {
        continue;
      }

      final state = states[item]!;
      if (!state.isSeen) {
        if (includeUnseen) {
          unseenItems.add(item);
        }
      } else if (state.isDue) {
        dueItems.add(state);
      }
    }

    if (dueItems.isNotEmpty) {
      dueItems.sort((left, right) {
        final ratingOrder = _ratingPriority(
          left.rating,
        ).compareTo(_ratingPriority(right.rating));
        if (ratingOrder != 0) {
          return ratingOrder;
        }

        final dueOrder = left.dueStep.compareTo(right.dueStep);
        if (dueOrder != 0) {
          return dueOrder;
        }

        return collectionItems
            .indexOf(left.item)
            .compareTo(collectionItems.indexOf(right.item));
      });

      return dueItems.first.item;
    }

    if (unseenItems.isNotEmpty) {
      return unseenItems.first;
    }

    if (!includeUnseen) {
      return null;
    }

    final knownStates = collectionItems.map((item) => states[item]!).toList()
      ..retainWhere((state) => !excludedItems.contains(state.item))
      ..sort((left, right) => left.dueStep.compareTo(right.dueStep));
    if (knownStates.isEmpty) {
      return null;
    }

    return knownStates.first.item;
  }

  static int _ratingPriority(LetterRating? rating) {
    return switch (rating) {
      LetterRating.notYet => 0,
      LetterRating.hard => 1,
      LetterRating.known => 2,
      null => 3,
    };
  }
}

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

class SharedPreferencesProgressStore implements ProgressStore {
  static const String _storageKey = 'practice_progress_v1';

  @override
  Future<Map<PracticeCollection, List<LetterProgress>>> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_storageKey);
    final progress = _emptyProgressMap();

    if (rawJson == null || rawJson.isEmpty) {
      return progress;
    }

    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    for (final collection in PracticeCollection.values) {
      final items = decoded[collection.id];
      if (items is! List<dynamic>) {
        continue;
      }

      progress[collection] = items
          .map(
            (entry) => LetterProgress.fromJson(entry as Map<String, dynamic>),
          )
          .toList();
    }

    return progress;
  }

  @override
  Future<void> saveProgress(
    Map<PracticeCollection, List<LetterProgress>> progress,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{
      for (final entry in progress.entries)
        entry.key.id: entry.value.map((item) => item.toJson()).toList(),
    };
    await prefs.setString(_storageKey, jsonEncode(encoded));
  }
}

class SharedPreferencesCollectionStore implements CollectionStore {
  static const String _storageKey = 'practice_collections_v1';

  @override
  Future<Map<PracticeCollection, List<String>>> loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_storageKey);
    final collections = _defaultCollectionItems();

    if (rawJson == null || rawJson.isEmpty) {
      return collections;
    }

    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    for (final collection in PracticeCollection.values) {
      if (!collection.isEditableWordSet) {
        continue;
      }

      final items = decoded[collection.id];
      if (items is! List<dynamic>) {
        continue;
      }

      collections[collection] = items.map((item) => item as String).toList();
    }

    return collections;
  }

  @override
  Future<void> saveCollection(
    PracticeCollection collection,
    List<String> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadCollections();
    current[collection] = List<String>.from(items);
    final encoded = <String, dynamic>{
      for (final entry in current.entries)
        if (entry.key.isEditableWordSet) entry.key.id: entry.value,
    };
    await prefs.setString(_storageKey, jsonEncode(encoded));
  }
}

Map<PracticeCollection, List<LetterProgress>> _emptyProgressMap() {
  return <PracticeCollection, List<LetterProgress>>{
    for (final collection in PracticeCollection.values)
      collection: <LetterProgress>[],
  };
}

Map<PracticeCollection, List<String>> _defaultCollectionItems() {
  return <PracticeCollection, List<String>>{
    for (final collection in PracticeCollection.values)
      collection: List<String>.from(collection.defaultItems),
  };
}

Map<PracticeCollection, List<String>> _shuffledCollectionItems(
  Map<PracticeCollection, List<String>> source,
) {
  return <PracticeCollection, List<String>>{
    for (final entry in source.entries)
      entry.key: _shuffledItemsFor(entry.key, entry.value),
  };
}

List<String> _shuffledItemsFor(
  PracticeCollection collection,
  List<String> items,
) {
  final shuffled = List<String>.from(items);
  shuffled.shuffle(Random(Object.hash(collection.id, items.length)));
  return shuffled;
}

List<String> _sanitizeCollectionItems(
  PracticeCollection collection,
  Iterable<String> items,
) {
  final targetLength = switch (collection) {
    PracticeCollection.twoLetterWords => 2,
    PracticeCollection.threeLetterWords => 3,
    _ => null,
  };

  final sanitized = <String>[];
  final seen = <String>{};

  for (final item in items) {
    final normalized = item.trim().toLowerCase();
    if (normalized.isEmpty) {
      continue;
    }
    if (targetLength != null && normalized.runes.length != targetLength) {
      continue;
    }
    if (seen.add(normalized)) {
      sanitized.add(normalized);
    }
  }

  return sanitized;
}

Map<String, LetterRating> _latestRatings(List<LetterProgress> responses) {
  final ratings = <String, LetterRating>{};

  for (final response in responses) {
    ratings[response.item] = response.rating;
  }

  return ratings;
}

bool _isCollectionMastered(
  PracticeCollection collection,
  List<LetterProgress> responses,
  Map<PracticeCollection, List<String>> collectionItems,
) {
  return ReviewScheduler.isCollectionMastered(
    collection,
    responses,
    items: collectionItems[collection],
  );
}

bool _isCollectionUnlocked(
  PracticeCollection collection,
  Map<PracticeCollection, List<LetterProgress>> progress,
  Map<PracticeCollection, List<String>> collectionItems,
) {
  return true;
}

PracticeCollection _recommendedCollection(
  Map<PracticeCollection, List<LetterProgress>> progress,
  Map<PracticeCollection, List<String>> collectionItems,
) {
  for (final collection in PracticeCollection.values) {
    if (!_isCollectionUnlocked(collection, progress, collectionItems)) {
      continue;
    }

    if (!_isCollectionMastered(
      collection,
      progress[collection]!,
      collectionItems,
    )) {
      return collection;
    }
  }

  return PracticeCollection.values.last;
}

PracticeCollection? _nextCollection(PracticeCollection collection) {
  final nextIndex = collection.index + 1;
  if (nextIndex >= PracticeCollection.values.length) {
    return null;
  }

  return PracticeCollection.values[nextIndex];
}

String? _chooseNextItem(
  PracticeCollection collection,
  List<LetterProgress> responses, {
  required ReviewMode reviewMode,
  Set<String> excludedItems = const <String>{},
  required Map<PracticeCollection, List<String>> collectionItems,
}) {
  return ReviewScheduler.chooseNextItem(
    collection,
    responses,
    includeUnseen: reviewMode == ReviewMode.balanced,
    excludedItems: excludedItems,
    items: collectionItems[collection],
  );
}

class CollectionSnapshot {
  const CollectionSnapshot({
    required this.collection,
    required this.totalCount,
    required this.knownCount,
    required this.dueCount,
    required this.weakCount,
    required this.seenCount,
    required this.isUnlocked,
    required this.isMastered,
  });

  final PracticeCollection collection;
  final int totalCount;
  final int knownCount;
  final int dueCount;
  final int weakCount;
  final int seenCount;
  final bool isUnlocked;
  final bool isMastered;
}

CollectionSnapshot _buildSnapshot(
  PracticeCollection collection,
  Map<PracticeCollection, List<LetterProgress>> progress,
  Map<PracticeCollection, List<String>> collectionItems,
) {
  final responses = progress[collection]!;
  final items = collectionItems[collection]!;
  final states = ReviewScheduler.buildStates(
    collection,
    responses,
    items: items,
  );
  final knownCount = states.values.where((state) => state.isKnownNow).length;
  final dueCount = states.values.where((state) => state.isDue).length;
  final weakCount = states.values
      .where(
        (state) =>
            state.rating == LetterRating.hard ||
            state.rating == LetterRating.notYet,
      )
      .length;
  final seenCount = states.values.where((state) => state.isSeen).length;

  return CollectionSnapshot(
    collection: collection,
    totalCount: items.length,
    knownCount: knownCount,
    dueCount: dueCount,
    weakCount: weakCount,
    seenCount: seenCount,
    isUnlocked: _isCollectionUnlocked(collection, progress, collectionItems),
    isMastered: _isCollectionMastered(collection, responses, collectionItems),
  );
}

class PracticeHomePage extends StatefulWidget {
  const PracticeHomePage({
    super.key,
    required this.speaker,
    required this.progressStore,
    required this.collectionStore,
  });

  final LetterSpeaker speaker;
  final ProgressStore progressStore;
  final CollectionStore collectionStore;

  @override
  State<PracticeHomePage> createState() => _PracticeHomePageState();
}

class _PracticeHomePageState extends State<PracticeHomePage> {
  Map<PracticeCollection, List<LetterProgress>> _progress = _emptyProgressMap();
  Map<PracticeCollection, List<String>> _collectionItems =
      _defaultCollectionItems();
  Map<PracticeCollection, List<String>> _practiceOrder =
      _shuffledCollectionItems(_defaultCollectionItems());
  PracticeCollection _selectedCollection = PracticeCollection.uppercaseLetters;
  SessionPlan _sessionPlan = SessionPlan.quick;
  ReviewMode _reviewMode = ReviewMode.balanced;
  bool _choicesVisible = false;
  bool _isLoading = true;
  int _sessionReviewedCount = 0;
  final Set<String> _skippedItems = <String>{};
  int _correctStreak = 0;
  int _celebrationToken = 0;
  String? _celebrationMessage;
  Timer? _celebrationTimer;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  List<LetterProgress> get _responses => _progress[_selectedCollection]!;

  List<String> get _items => _collectionItems[_selectedCollection]!;

  Map<String, LetterRating> get _currentRatings => _latestRatings(_responses);

  bool get _isComplete =>
      _isCollectionMastered(_selectedCollection, _responses, _collectionItems);

  String? get _currentItem => _chooseNextItem(
    _selectedCollection,
    _responses,
    reviewMode: _reviewMode,
    excludedItems: _skippedItems,
    collectionItems: _practiceOrder,
  );

  bool get _isReviewQueueEmpty => !_isComplete && _currentItem == null;

  bool get _isSessionComplete =>
      !_isComplete &&
      !_isReviewQueueEmpty &&
      !_sessionPlan.isContinuous &&
      _sessionPlan.itemLimit != null &&
      _sessionReviewedCount >= _sessionPlan.itemLimit!;

  Future<void> _loadProgress() async {
    final loaded = await widget.progressStore.loadProgress();
    final loadedCollections = await widget.collectionStore.loadCollections();
    if (!mounted) {
      return;
    }

    setState(() {
      _progress = loaded;
      _collectionItems = loadedCollections;
      _practiceOrder = _shuffledCollectionItems(loadedCollections);
      _selectedCollection = _recommendedCollection(loaded, loadedCollections);
      _isLoading = false;
    });
  }

  int _countByRating(LetterRating rating) {
    return _currentRatings.values.where((value) => value == rating).length;
  }

  Future<void> _saveProgress() {
    return widget.progressStore.saveProgress(_progress);
  }

  Future<void> _saveCollectionItems(
    PracticeCollection collection,
    List<String> items,
  ) {
    return widget.collectionStore.saveCollection(collection, items);
  }

  Future<void> _updateCollectionItems(
    PracticeCollection collection,
    List<String> items,
  ) async {
    final sanitized = _sanitizeCollectionItems(collection, items);
    if (!collection.isEditableWordSet || sanitized.isEmpty) {
      return;
    }

    setState(() {
      _collectionItems[collection] = sanitized;
      _practiceOrder[collection] = _shuffledItemsFor(collection, sanitized);
      _choicesVisible = false;
      _skippedItems.clear();
      _celebrationMessage = null;
      if (_selectedCollection == collection) {
        _sessionReviewedCount = 0;
        _correctStreak = 0;
      }
    });

    await _saveCollectionItems(collection, sanitized);
  }

  Future<void> _playCurrentItem() async {
    final currentItem = _currentItem;
    if (_isComplete || currentItem == null) {
      return;
    }

    await widget.speaker.speakItem(currentItem);

    if (!mounted || _choicesVisible) {
      return;
    }

    setState(() {
      _choicesVisible = true;
    });
  }

  Future<void> _rateCurrentItem(LetterRating rating) async {
    final currentItem = _currentItem;
    if (_isComplete || currentItem == null) {
      return;
    }

    setState(() {
      _progress[_selectedCollection] = <LetterProgress>[
        ..._responses,
        LetterProgress(item: currentItem, rating: rating),
      ];
      _choicesVisible = false;
      _sessionReviewedCount++;
      _skippedItems.remove(currentItem);
    });

    if (rating == LetterRating.known) {
      _correctStreak++;
      _showCelebration(
        _correctStreak >= 3 ? '$_correctStreak in a row!' : 'Nice job!',
      );
    } else {
      _clearCelebration();
      _correctStreak = 0;
    }

    await _saveProgress();
  }

  Future<void> _restartCollection() async {
    setState(() {
      _progress[_selectedCollection] = <LetterProgress>[];
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
    });

    await _saveProgress();
  }

  void _updateSessionPlan(SessionPlan sessionPlan) {
    setState(() {
      _sessionPlan = sessionPlan;
      _sessionReviewedCount = 0;
      _choicesVisible = false;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
    });
  }

  void _updateReviewMode(ReviewMode reviewMode) {
    setState(() {
      _reviewMode = reviewMode;
      _sessionReviewedCount = 0;
      _choicesVisible = false;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
    });
  }

  void _selectCollection(PracticeCollection collection) {
    setState(() {
      _selectedCollection = collection;
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
    });
  }

  void _continueToNextCollection() {
    final next = _nextCollection(_selectedCollection);
    if (next == null) {
      return;
    }

    setState(() {
      _selectedCollection = next;
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
    });
  }

  void _continueSession() {
    setState(() {
      _sessionReviewedCount = 0;
      _choicesVisible = false;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
    });
  }

  void _skipCurrentItem() {
    final currentItem = _currentItem;
    if (currentItem == null) {
      return;
    }

    setState(() {
      _skippedItems.add(currentItem);
      _choicesVisible = false;
      _celebrationMessage = null;
    });
  }

  void _showCelebration(String message) {
    final token = ++_celebrationToken;
    _celebrationTimer?.cancel();
    setState(() {
      _celebrationMessage = message;
    });

    _celebrationTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || token != _celebrationToken) {
        return;
      }

      setState(() {
        _celebrationMessage = null;
      });
    });
  }

  void _clearCelebration() {
    _celebrationToken++;
    _celebrationTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _celebrationMessage = null;
    });
  }

  Future<void> _openSettings() {
    final recommendedCollection = _recommendedCollection(
      _progress,
      _collectionItems,
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9F3E8),
      builder: (sheetContext) {
        return _SettingsSheet(
          sessionPlan: _sessionPlan,
          reviewMode: _reviewMode,
          selectedCollection: _selectedCollection,
          progress: _progress,
          collectionItems: _collectionItems,
          recommendedCollection: recommendedCollection,
          onSessionPlanSelected: (sessionPlan) {
            Navigator.of(sheetContext).pop();
            _updateSessionPlan(sessionPlan);
          },
          onReviewModeSelected: (reviewMode) {
            Navigator.of(sheetContext).pop();
            _updateReviewMode(reviewMode);
          },
          onCollectionSelected: (collection) {
            Navigator.of(sheetContext).pop();
            _selectCollection(collection);
          },
          onCollectionItemsChanged: _updateCollectionItems,
        );
      },
    );
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    widget.speaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Time'),
        backgroundColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            key: const Key('settings-button'),
            tooltip: 'Settings',
            onPressed: _isLoading ? null : _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: _isComplete || _isSessionComplete || _isReviewQueueEmpty
                    ? _SessionSummary(
                        theme: theme,
                        collection: _selectedCollection,
                        items: _items,
                        responses: _responses,
                        sessionPlan: _sessionPlan,
                        sessionReviewedCount: _sessionReviewedCount,
                        isCollectionMastered: _isComplete,
                        reviewMode: _reviewMode,
                        isReviewQueueEmpty: _isReviewQueueEmpty,
                        nextCollection: _nextCollection(_selectedCollection),
                        nextCollectionUnlocked:
                            _nextCollection(_selectedCollection) != null &&
                            _isCollectionUnlocked(
                              _nextCollection(_selectedCollection)!,
                              _progress,
                              _collectionItems,
                            ),
                        onContinue: _continueToNextCollection,
                        onContinueSession: _continueSession,
                        onRestart: _restartCollection,
                      )
                    : _PracticeView(
                        theme: theme,
                        collection: _selectedCollection,
                        currentItem: _currentItem!,
                        progressText: _sessionPlan.itemLimit == null
                            ? _sessionPlan.isContinuous
                                  ? 'Continuous'
                                  : 'Known ${_countByRating(LetterRating.known)} of ${_items.length}'
                            : 'Today $_sessionReviewedCount of ${_sessionPlan.itemLimit}',
                        knownCount: _countByRating(LetterRating.known),
                        hardCount: _countByRating(LetterRating.hard),
                        notYetCount: _countByRating(LetterRating.notYet),
                        choicesVisible: _choicesVisible,
                        celebrationMessage: _celebrationMessage,
                        onReveal: _playCurrentItem,
                        onSkip: _skipCurrentItem,
                        onKnown: () => _rateCurrentItem(LetterRating.known),
                        onHard: () => _rateCurrentItem(LetterRating.hard),
                        onNotYet: () => _rateCurrentItem(LetterRating.notYet),
                      ),
              ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.sessionPlan,
    required this.reviewMode,
    required this.selectedCollection,
    required this.progress,
    required this.collectionItems,
    required this.recommendedCollection,
    required this.onSessionPlanSelected,
    required this.onReviewModeSelected,
    required this.onCollectionSelected,
    required this.onCollectionItemsChanged,
  });

  final SessionPlan sessionPlan;
  final ReviewMode reviewMode;
  final PracticeCollection selectedCollection;
  final Map<PracticeCollection, List<LetterProgress>> progress;
  final Map<PracticeCollection, List<String>> collectionItems;
  final PracticeCollection recommendedCollection;
  final ValueChanged<SessionPlan> onSessionPlanSelected;
  final ValueChanged<ReviewMode> onReviewModeSelected;
  final ValueChanged<PracticeCollection> onCollectionSelected;
  final Future<void> Function(PracticeCollection collection, List<String> items)
  onCollectionItemsChanged;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static final Uri _changelogUri = Uri.parse(kAppChangelogUrl);
  late Map<PracticeCollection, List<String>> _localCollectionItems;

  @override
  void initState() {
    super.initState();
    _localCollectionItems = <PracticeCollection, List<String>>{
      for (final entry in widget.collectionItems.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  Future<void> _promptAddWord(PracticeCollection collection) async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final targetLength = collection == PracticeCollection.twoLetterWords
            ? 2
            : 3;

        return AlertDialog(
          title: Text('Add ${collection.title.toLowerCase()}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(labelText: '$targetLength-letter word'),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added == null) {
      return;
    }

    final currentItems = _localCollectionItems[collection]!;
    final nextItems = _sanitizeCollectionItems(collection, <String>[
      ...currentItems,
      added,
    ]);
    if (nextItems.length == currentItems.length) {
      final length = collection == PracticeCollection.twoLetterWords ? 2 : 3;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add a unique $length-letter word.')),
      );
      return;
    }

    setState(() {
      _localCollectionItems[collection] = nextItems;
    });
    await widget.onCollectionItemsChanged(collection, nextItems);
  }

  Future<void> _removeWord(PracticeCollection collection, String item) async {
    final currentItems = _localCollectionItems[collection]!;
    if (currentItems.length <= 1) {
      return;
    }

    final nextItems = List<String>.from(currentItems)..remove(item);
    setState(() {
      _localCollectionItems[collection] = nextItems;
    });
    await widget.onCollectionItemsChanged(collection, nextItems);
  }

  Future<void> _openChangelog() async {
    final bool didLaunch = await launchUrl(
      _changelogUri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open changelog.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6CCBC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Hide the extra setup here so the practice screen stays focused.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            _RecommendationBanner(collection: widget.recommendedCollection),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Session length',
              child: _SessionPlanPicker(
                sessionPlan: widget.sessionPlan,
                onSelected: widget.onSessionPlanSelected,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Practice mode',
              child: _ReviewModePicker(
                reviewMode: widget.reviewMode,
                onSelected: widget.onReviewModeSelected,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Choose set',
              child: _CollectionPicker(
                selectedCollection: widget.selectedCollection,
                onSelected: widget.onCollectionSelected,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Parent overview',
              child: Column(
                children: PracticeCollection.values.map((collection) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: collection == PracticeCollection.values.last
                          ? 0
                          : 12,
                    ),
                    child: _CollectionOverviewCard(
                      snapshot: _buildSnapshot(
                        collection,
                        widget.progress,
                        _localCollectionItems,
                      ),
                      isRecommended: collection == widget.recommendedCollection,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Word lists',
              child: Column(
                children: PracticeCollection.values
                    .where((collection) => collection.isEditableWordSet)
                    .map((collection) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              collection == PracticeCollection.threeLetterWords
                              ? 0
                              : 16,
                        ),
                        child: _EditableWordListCard(
                          collection: collection,
                          items: _localCollectionItems[collection]!,
                          onAddWord: () => _promptAddWord(collection),
                          onRemoveWord: (item) => _removeWord(collection, item),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'App version',
              child: Row(
                children: <Widget>[
                  const _VersionBadge(version: kAppVersionLabel),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _openChangelog,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open changelog'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        version,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _CollectionPicker extends StatelessWidget {
  const _CollectionPicker({
    required this.selectedCollection,
    required this.onSelected,
  });

  final PracticeCollection selectedCollection;
  final ValueChanged<PracticeCollection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PracticeCollection.values.map((collection) {
        final isSelected = collection == selectedCollection;
        return ChoiceChip(
          label: Text(collection.label),
          selected: isSelected,
          onSelected: (_) => onSelected(collection),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF12343B),
          ),
          selectedColor: const Color(0xFF12343B),
          backgroundColor: const Color(0xFFE9E0D0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _SessionPlanPicker extends StatelessWidget {
  const _SessionPlanPicker({
    required this.sessionPlan,
    required this.onSelected,
  });

  final SessionPlan sessionPlan;
  final ValueChanged<SessionPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SessionPlan.values.map((plan) {
        final isSelected = plan == sessionPlan;
        return ChoiceChip(
          label: Text(plan.label),
          selected: isSelected,
          onSelected: (_) => onSelected(plan),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF12343B),
          ),
          selectedColor: const Color(0xFF5B7C6D),
          backgroundColor: const Color(0xFFF1E6D6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewModePicker extends StatelessWidget {
  const _ReviewModePicker({required this.reviewMode, required this.onSelected});

  final ReviewMode reviewMode;
  final ValueChanged<ReviewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ReviewMode.values.map((mode) {
        final isSelected = mode == reviewMode;
        return ChoiceChip(
          label: Text(mode.label),
          selected: isSelected,
          onSelected: (_) => onSelected(mode),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF12343B),
          ),
          selectedColor: const Color(0xFF7A5C3E),
          backgroundColor: const Color(0xFFF1E6D6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({required this.collection});

  final PracticeCollection collection;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3EFE9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF12343B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recommended next: ${collection.title}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF12343B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionOverviewCard extends StatelessWidget {
  const _CollectionOverviewCard({
    required this.snapshot,
    required this.isRecommended,
  });

  final CollectionSnapshot snapshot;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.totalCount;
    final statusText = switch ((snapshot.isUnlocked, snapshot.isMastered)) {
      (false, _) => 'Locked until earlier set is stable',
      (true, true) => 'Stable and ready to keep or move on',
      (true, false) =>
        snapshot.dueCount > 0 ? '${snapshot.dueCount} due now' : 'In progress',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended
              ? const Color(0xFF5B7C6D)
              : const Color(0xFFE0D6C6),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    snapshot.collection.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isRecommended)
                  const _InfoChip(label: 'Next up', color: Color(0xFFD7F1EC)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4E5D52)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  label: 'Known ${snapshot.knownCount}/$total',
                  color: const Color(0xFFD7F1EC),
                ),
                _InfoChip(
                  label: 'Seen ${snapshot.seenCount}/$total',
                  color: const Color(0xFFE8F1E7),
                ),
                _InfoChip(
                  label: 'Due ${snapshot.dueCount}',
                  color: const Color(0xFFFFE2C7),
                ),
                _InfoChip(
                  label: 'Weak ${snapshot.weakCount}',
                  color: const Color(0xFFF8D9D9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableWordListCard extends StatelessWidget {
  const _EditableWordListCard({
    required this.collection,
    required this.items,
    required this.onAddWord,
    required this.onRemoveWord,
  });

  final PracticeCollection collection;
  final List<String> items;
  final VoidCallback onAddWord;
  final ValueChanged<String> onRemoveWord;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0D6C6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    collection.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: Key('add-word-${collection.id}'),
                  onPressed: onAddWord,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) {
                final canRemove = items.length > 1;
                return InputChip(
                  key: Key('${collection.id}-$item'),
                  label: Text(item),
                  onDeleted: canRemove ? () => onRemoveWord(item) : null,
                  deleteIcon: const Icon(Icons.close_rounded, size: 18),
                  backgroundColor: const Color(0xFFF3ECE1),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeView extends StatelessWidget {
  const _PracticeView({
    required this.theme,
    required this.collection,
    required this.currentItem,
    required this.progressText,
    required this.knownCount,
    required this.hardCount,
    required this.notYetCount,
    required this.choicesVisible,
    required this.celebrationMessage,
    required this.onReveal,
    required this.onSkip,
    required this.onKnown,
    required this.onHard,
    required this.onNotYet,
  });

  final ThemeData theme;
  final PracticeCollection collection;
  final String currentItem;
  final String progressText;
  final int knownCount;
  final int hardCount;
  final int notYetCount;
  final bool choicesVisible;
  final String? celebrationMessage;
  final Future<void> Function() onReveal;
  final VoidCallback onSkip;
  final Future<void> Function() onKnown;
  final Future<void> Function() onHard;
  final Future<void> Function() onNotYet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = collection.promptNoun == 'letter'
            ? constraints.maxHeight * 0.42
            : constraints.maxHeight * 0.34;

        return ListView(
          children: <Widget>[
            Text(
              collection.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _ProgressStrip(
              progressText: progressText,
              knownCount: knownCount,
              hardCount: hardCount,
              notYetCount: notYetCount,
            ),
            const SizedBox(height: 16),
            _CelebrationBanner(message: celebrationMessage),
            const SizedBox(height: 24),
            SizedBox(
              height: cardHeight.clamp(220.0, 360.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('practice-card'),
                  borderRadius: BorderRadius.circular(36),
                  onTap: onReveal,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFFF6D6), Color(0xFFFCCB90)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: <Widget>[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currentItem,
                                semanticsLabel:
                                    'Current ${collection.promptNoun} $currentItem',
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontSize: collection.promptNoun == 'letter'
                                      ? 164
                                      : 108,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF12343B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 18,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xCCFFFFFF),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(Icons.volume_up_rounded),
                                  const SizedBox(width: 10),
                                  Text(
                                    choicesVisible
                                        ? 'Tap to hear again'
                                        : 'Tap to hear the ${collection.promptNoun}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onSkip,
              icon: const Icon(Icons.skip_next_rounded),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              label: const Text('Skip for now'),
            ),
            const SizedBox(height: 12),
            if (choicesVisible) ...<Widget>[
              FilledButton(
                onPressed: onKnown,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2A9D8F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Known'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onHard,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF4A261),
                  foregroundColor: const Color(0xFF362100),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Hard'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onNotYet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9C2F2F),
                  side: const BorderSide(color: Color(0xFF9C2F2F), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Not yet'),
              ),
            ] else
              FilledButton.tonalIcon(
                onPressed: onReveal,
                icon: const Icon(Icons.touch_app_rounded),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                label: Text('Play ${collection.promptNoun}'),
              ),
          ],
        );
      },
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.progressText,
    required this.knownCount,
    required this.hardCount,
    required this.notYetCount,
  });

  final String progressText;
  final int knownCount;
  final int hardCount;
  final int notYetCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _InfoChip(label: progressText, color: const Color(0xFFE8F1E7)),
        _InfoChip(label: 'Known $knownCount', color: const Color(0xFFD7F1EC)),
        _InfoChip(label: 'Hard $hardCount', color: const Color(0xFFFFE2C7)),
        _InfoChip(
          label: 'Not yet $notYetCount',
          color: const Color(0xFFF8D9D9),
        ),
      ],
    );
  }
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: message == null
          ? const SizedBox.shrink()
          : DecoratedBox(
              key: ValueKey<String>(message!),
              decoration: BoxDecoration(
                color: const Color(0xFFD7F1EC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.stars_rounded, color: Color(0xFF12343B)),
                    const SizedBox(width: 10),
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF12343B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.theme,
    required this.collection,
    required this.items,
    required this.responses,
    required this.sessionPlan,
    required this.sessionReviewedCount,
    required this.isCollectionMastered,
    required this.reviewMode,
    required this.isReviewQueueEmpty,
    required this.nextCollection,
    required this.nextCollectionUnlocked,
    required this.onContinue,
    required this.onContinueSession,
    required this.onRestart,
  });

  final ThemeData theme;
  final PracticeCollection collection;
  final List<String> items;
  final List<LetterProgress> responses;
  final SessionPlan sessionPlan;
  final int sessionReviewedCount;
  final bool isCollectionMastered;
  final ReviewMode reviewMode;
  final bool isReviewQueueEmpty;
  final PracticeCollection? nextCollection;
  final bool nextCollectionUnlocked;
  final VoidCallback onContinue;
  final VoidCallback onContinueSession;
  final Future<void> Function() onRestart;

  List<String> _itemsFor(LetterRating rating) {
    final latest = _latestRatings(responses);
    return items.where((item) => latest[item] == rating).toList();
  }

  @override
  Widget build(BuildContext context) {
    final knownItems = _itemsFor(LetterRating.known);
    final hardItems = _itemsFor(LetterRating.hard);
    final notYetItems = _itemsFor(LetterRating.notYet);
    final isDailySession =
        !isCollectionMastered && sessionPlan.itemLimit != null;
    final isReviewOnlyComplete =
        isReviewQueueEmpty && reviewMode == ReviewMode.reviewOnly;

    return ListView(
      children: <Widget>[
        Text(
          isReviewOnlyComplete
              ? 'Review caught up'
              : isDailySession
              ? 'Session complete'
              : '${collection.title} complete',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isReviewOnlyComplete
              ? 'There are no due reviews left in this set right now. Switch back to balanced mode to introduce new items.'
              : isDailySession
              ? 'You finished $sessionReviewedCount ${collection.promptNoun == 'word' ? 'words' : 'items'} in this short session. Progress is saved, so you can stop here or keep going.'
              : 'Use this summary to decide what to repeat next. Progress stays saved on this device.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _SummaryCard(
          title: 'Known',
          color: const Color(0xFFD7F1EC),
          items: knownItems,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Hard',
          color: const Color(0xFFFFE2C7),
          items: hardItems,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Not yet',
          color: const Color(0xFFF8D9D9),
          items: notYetItems,
        ),
        if (isDailySession) ...<Widget>[
          FilledButton(
            onPressed: onContinueSession,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF12343B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text('Keep going'),
          ),
          const SizedBox(height: 12),
        ],
        if (nextCollection != null && nextCollectionUnlocked) ...<Widget>[
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: isDailySession
                  ? const Color(0xFF5B7C6D)
                  : const Color(0xFF12343B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Text('Continue to ${nextCollection!.title}'),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: onRestart,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          child: const Text('Start this set again'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$title (${items.length})',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              items.isEmpty ? 'None' : items.join('  '),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
