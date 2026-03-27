import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'automatic_backup_preferences.dart';
import 'automatic_backup_service.dart';
import 'app_version.dart';
import 'supabase_bootstrap.dart';
part 'practice_app_data.dart';
part 'settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initializeIfConfigured();
  runApp(const LetterLearningApp());
}

class LetterLearningApp extends StatelessWidget {
  const LetterLearningApp({
    super.key,
    this.speaker,
    this.progressStore,
    this.collectionStore,
    this.appDataStore,
  });

  final LetterSpeaker? speaker;
  final ProgressStore? progressStore;
  final CollectionStore? collectionStore;
  final SharedPreferencesAppDataStore? appDataStore;

  @override
  Widget build(BuildContext context) {
    final SharedPreferencesAppDataStore resolvedAppDataStore =
        appDataStore ?? const SharedPreferencesAppDataStore();

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
        progressStore:
            progressStore ??
            SharedPreferencesProgressStore(appDataStore: resolvedAppDataStore),
        collectionStore:
            collectionStore ??
            SharedPreferencesCollectionStore(
              appDataStore: resolvedAppDataStore,
            ),
        appDataStore: resolvedAppDataStore,
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
    required this.appDataStore,
  });

  final LetterSpeaker speaker;
  final ProgressStore progressStore;
  final CollectionStore collectionStore;
  final SharedPreferencesAppDataStore appDataStore;

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

  PracticeAppSnapshot _currentSnapshot() {
    return PracticeAppSnapshot(
      progress: <PracticeCollection, List<LetterProgress>>{
        for (final MapEntry<PracticeCollection, List<LetterProgress>> entry
            in _progress.entries)
          entry.key: List<LetterProgress>.from(entry.value),
      },
      collectionItems: <PracticeCollection, List<String>>{
        for (final MapEntry<PracticeCollection, List<String>> entry
            in _collectionItems.entries)
          entry.key: List<String>.from(entry.value),
      },
    );
  }

  void _applyLoadedSnapshot(PracticeAppSnapshot snapshot) {
    final Map<PracticeCollection, List<LetterProgress>> progress =
        <PracticeCollection, List<LetterProgress>>{
          for (final MapEntry<PracticeCollection, List<LetterProgress>> entry
              in snapshot.progress.entries)
            entry.key: List<LetterProgress>.from(entry.value),
        };
    final Map<PracticeCollection, List<String>> collectionItems =
        <PracticeCollection, List<String>>{
          for (final MapEntry<PracticeCollection, List<String>> entry
              in snapshot.collectionItems.entries)
            entry.key: List<String>.from(entry.value),
        };

    setState(() {
      _progress = progress;
      _collectionItems = collectionItems;
      _practiceOrder = _shuffledCollectionItems(collectionItems);
      _selectedCollection = _recommendedCollection(progress, collectionItems);
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
      _correctStreak = 0;
      _celebrationMessage = null;
      _isLoading = false;
    });
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

    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _SettingsPage(
            sessionPlan: _sessionPlan,
            reviewMode: _reviewMode,
            selectedCollection: _selectedCollection,
            progress: _progress,
            collectionItems: _collectionItems,
            recommendedCollection: recommendedCollection,
            onSessionPlanSelected: _updateSessionPlan,
            onReviewModeSelected: _updateReviewMode,
            onCollectionSelected: _selectCollection,
            onCollectionItemsChanged: _updateCollectionItems,
            onExportJsonData: _exportJsonDataForSettings,
            onImportJsonData: _importJsonDataForSettings,
            loadAutomaticBackupsEnabled: _loadAutomaticBackupsEnabled,
            onAutomaticBackupsEnabledChanged:
                _setAutomaticBackupsEnabledForSettings,
            onListAutomaticBackups: _listAutomaticBackupsForSettings,
            onRestoreAutomaticBackup: _restoreAutomaticBackupForSettings,
          );
        },
      ),
    );
  }

  Future<String?> _exportJsonDataForSettings() async {
    return widget.appDataStore.exportAsJsonString(_currentSnapshot());
  }

  Future<String?> _importJsonDataForSettings(String rawJson) async {
    try {
      final PracticeAppSnapshot snapshot = await widget.appDataStore
          .importFromJsonString(rawJson);
      if (!mounted) {
        return 'JSON imported successfully.';
      }
      _applyLoadedSnapshot(snapshot);
      return 'JSON imported successfully.';
    } on FormatException {
      return 'Could not import JSON. Check that the pasted data is valid.';
    } catch (_) {
      return 'Could not import JSON.';
    }
  }

  Future<bool> _loadAutomaticBackupsEnabled() {
    return widget.appDataStore.loadAutomaticBackupsEnabled();
  }

  Future<String?> _setAutomaticBackupsEnabledForSettings(bool enabled) async {
    await widget.appDataStore.saveAutomaticBackupsEnabled(enabled);
    if (enabled) {
      await widget.appDataStore.saveAutomaticBackupNow(_currentSnapshot());
      return 'Automatic backups enabled. A fresh local snapshot was saved.';
    }
    return 'Automatic backups disabled.';
  }

  Future<List<LearnToReadBackupEntry>> _listAutomaticBackupsForSettings() {
    return widget.appDataStore.listAutomaticBackups();
  }

  Future<String?> _restoreAutomaticBackupForSettings(String backupId) async {
    try {
      final PracticeAppSnapshot snapshot = await widget.appDataStore
          .restoreAutomaticBackup(backupId);
      if (mounted) {
        _applyLoadedSnapshot(snapshot);
      }
      return 'Automatic backup restored. Current data was replaced.';
    } on FormatException {
      return 'Could not restore that backup.';
    } catch (_) {
      return 'Could not restore the selected backup.';
    }
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
            icon: const Icon(Icons.settings_outlined),
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
