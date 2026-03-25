import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const LetterLearningApp());
}

class LetterLearningApp extends StatelessWidget {
  const LetterLearningApp({super.key, this.speaker, this.progressStore});

  final LetterSpeaker? speaker;
  final ProgressStore? progressStore;

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
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.42);
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;

  @override
  Future<void> speakItem(String item) async {
    try {
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
    items: <String>[
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
    items: <String>[
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
    items: <String>[
      'am',
      'an',
      'at',
      'be',
      'by',
      'do',
      'go',
      'he',
      'if',
      'in',
      'is',
      'it',
      'me',
      'my',
      'no',
      'of',
      'on',
      'or',
      'to',
      'up',
      'us',
      'we',
    ],
  ),
  threeLetterWords(
    id: 'three_letter_words',
    label: '3-letter',
    title: 'Three-letter words',
    promptNoun: 'word',
    items: <String>[
      'bag',
      'bed',
      'big',
      'box',
      'bug',
      'bus',
      'cat',
      'cup',
      'dad',
      'dig',
      'dog',
      'fox',
      'hat',
      'hen',
      'jam',
      'leg',
      'man',
      'mud',
      'pen',
      'pig',
      'red',
      'sun',
      'top',
      'van',
    ],
  );

  const PracticeCollection({
    required this.id,
    required this.label,
    required this.title,
    required this.promptNoun,
    required this.items,
  });

  final String id;
  final String label;
  final String title;
  final String promptNoun;
  final List<String> items;
}

enum LetterRating { known, hard, notYet }

enum SessionPlan {
  quick(label: 'Quick 5', itemLimit: 5),
  focused(label: 'Focused 10', itemLimit: 10),
  full(label: 'Full set', itemLimit: null);

  const SessionPlan({required this.label, required this.itemLimit});

  final String label;
  final int? itemLimit;
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
    List<LetterProgress> responses,
  ) {
    final states = <String, ReviewItemState>{
      for (final item in collection.items)
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
    List<LetterProgress> responses,
  ) {
    final states = buildStates(collection, responses);
    return collection.items.every((item) {
      final state = states[item]!;
      return state.isSeen && state.isKnownNow && !state.isDue;
    });
  }

  static String? chooseNextItem(
    PracticeCollection collection,
    List<LetterProgress> responses, {
    bool includeUnseen = true,
    Set<String> excludedItems = const <String>{},
  }) {
    final states = buildStates(collection, responses);
    final dueItems = <ReviewItemState>[];
    final unseenItems = <String>[];

    for (final item in collection.items) {
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

        return collection.items
            .indexOf(left.item)
            .compareTo(collection.items.indexOf(right.item));
      });

      return dueItems.first.item;
    }

    if (unseenItems.isNotEmpty) {
      return unseenItems.first;
    }

    if (!includeUnseen) {
      return null;
    }

    final knownStates = collection.items.map((item) => states[item]!).toList()
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

Map<PracticeCollection, List<LetterProgress>> _emptyProgressMap() {
  return <PracticeCollection, List<LetterProgress>>{
    for (final collection in PracticeCollection.values)
      collection: <LetterProgress>[],
  };
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
) {
  return ReviewScheduler.isCollectionMastered(collection, responses);
}

bool _isCollectionUnlocked(
  PracticeCollection collection,
  Map<PracticeCollection, List<LetterProgress>> progress,
) {
  switch (collection) {
    case PracticeCollection.uppercaseLetters:
      return true;
    case PracticeCollection.lowercaseLetters:
      return _isCollectionMastered(
        PracticeCollection.uppercaseLetters,
        progress[PracticeCollection.uppercaseLetters]!,
      );
    case PracticeCollection.twoLetterWords:
      return _isCollectionMastered(
        PracticeCollection.lowercaseLetters,
        progress[PracticeCollection.lowercaseLetters]!,
      );
    case PracticeCollection.threeLetterWords:
      return _isCollectionMastered(
        PracticeCollection.twoLetterWords,
        progress[PracticeCollection.twoLetterWords]!,
      );
  }
}

PracticeCollection _recommendedCollection(
  Map<PracticeCollection, List<LetterProgress>> progress,
) {
  for (final collection in PracticeCollection.values) {
    if (!_isCollectionUnlocked(collection, progress)) {
      continue;
    }

    if (!_isCollectionMastered(collection, progress[collection]!)) {
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
}) {
  return ReviewScheduler.chooseNextItem(
    collection,
    responses,
    includeUnseen: reviewMode == ReviewMode.balanced,
    excludedItems: excludedItems,
  );
}

class CollectionSnapshot {
  const CollectionSnapshot({
    required this.collection,
    required this.knownCount,
    required this.dueCount,
    required this.weakCount,
    required this.seenCount,
    required this.isUnlocked,
    required this.isMastered,
  });

  final PracticeCollection collection;
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
) {
  final responses = progress[collection]!;
  final states = ReviewScheduler.buildStates(collection, responses);
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
    knownCount: knownCount,
    dueCount: dueCount,
    weakCount: weakCount,
    seenCount: seenCount,
    isUnlocked: _isCollectionUnlocked(collection, progress),
    isMastered: _isCollectionMastered(collection, responses),
  );
}

class PracticeHomePage extends StatefulWidget {
  const PracticeHomePage({
    super.key,
    required this.speaker,
    required this.progressStore,
  });

  final LetterSpeaker speaker;
  final ProgressStore progressStore;

  @override
  State<PracticeHomePage> createState() => _PracticeHomePageState();
}

class _PracticeHomePageState extends State<PracticeHomePage> {
  Map<PracticeCollection, List<LetterProgress>> _progress = _emptyProgressMap();
  PracticeCollection _selectedCollection = PracticeCollection.uppercaseLetters;
  SessionPlan _sessionPlan = SessionPlan.quick;
  ReviewMode _reviewMode = ReviewMode.balanced;
  bool _choicesVisible = false;
  bool _isLoading = true;
  int _sessionReviewedCount = 0;
  final Set<String> _skippedItems = <String>{};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  List<LetterProgress> get _responses => _progress[_selectedCollection]!;

  List<String> get _items => _selectedCollection.items;

  Map<String, LetterRating> get _currentRatings => _latestRatings(_responses);

  bool get _isComplete =>
      _isCollectionMastered(_selectedCollection, _responses);

  String? get _currentItem => _chooseNextItem(
    _selectedCollection,
    _responses,
    reviewMode: _reviewMode,
    excludedItems: _skippedItems,
  );

  bool get _isReviewQueueEmpty => !_isComplete && _currentItem == null;

  bool get _isSessionComplete =>
      !_isComplete &&
      !_isReviewQueueEmpty &&
      _sessionPlan.itemLimit != null &&
      _sessionReviewedCount >= _sessionPlan.itemLimit!;

  Future<void> _loadProgress() async {
    final loaded = await widget.progressStore.loadProgress();
    if (!mounted) {
      return;
    }

    setState(() {
      _progress = loaded;
      _selectedCollection = _recommendedCollection(loaded);
      _isLoading = false;
    });
  }

  int _countByRating(LetterRating rating) {
    return _currentRatings.values.where((value) => value == rating).length;
  }

  Future<void> _saveProgress() {
    return widget.progressStore.saveProgress(_progress);
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

    await _saveProgress();
  }

  Future<void> _restartCollection() async {
    setState(() {
      _progress[_selectedCollection] = <LetterProgress>[];
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
    });

    await _saveProgress();
  }

  void _updateSessionPlan(SessionPlan sessionPlan) {
    setState(() {
      _sessionPlan = sessionPlan;
      _sessionReviewedCount = 0;
      _choicesVisible = false;
      _skippedItems.clear();
    });
  }

  void _updateReviewMode(ReviewMode reviewMode) {
    setState(() {
      _reviewMode = reviewMode;
      _sessionReviewedCount = 0;
      _choicesVisible = false;
      _skippedItems.clear();
    });
  }

  void _selectCollection(PracticeCollection collection) {
    if (!_isCollectionUnlocked(collection, _progress)) {
      return;
    }

    setState(() {
      _selectedCollection = collection;
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
    });
  }

  void _continueToNextCollection() {
    final next = _nextCollection(_selectedCollection);
    if (next == null || !_isCollectionUnlocked(next, _progress)) {
      return;
    }

    setState(() {
      _selectedCollection = next;
      _choicesVisible = false;
      _sessionReviewedCount = 0;
      _skippedItems.clear();
    });
  }

  void _continueSession() {
    setState(() {
      _sessionReviewedCount = 0;
      _choicesVisible = false;
      _skippedItems.clear();
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
    });
  }

  @override
  void dispose() {
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
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SessionPlanPicker(
                      sessionPlan: _sessionPlan,
                      onSelected: _updateSessionPlan,
                    ),
                    const SizedBox(height: 16),
                    _ReviewModePicker(
                      reviewMode: _reviewMode,
                      onSelected: _updateReviewMode,
                    ),
                    const SizedBox(height: 16),
                    _RecommendationBanner(
                      collection: _recommendedCollection(_progress),
                    ),
                    const SizedBox(height: 16),
                    _ParentDashboard(
                      progress: _progress,
                      recommendedCollection: _recommendedCollection(_progress),
                    ),
                    const SizedBox(height: 16),
                    _CollectionPicker(
                      selectedCollection: _selectedCollection,
                      progress: _progress,
                      onSelected: _selectCollection,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child:
                          _isComplete ||
                              _isSessionComplete ||
                              _isReviewQueueEmpty
                          ? _SessionSummary(
                              theme: theme,
                              collection: _selectedCollection,
                              responses: _responses,
                              sessionPlan: _sessionPlan,
                              sessionReviewedCount: _sessionReviewedCount,
                              isCollectionMastered: _isComplete,
                              reviewMode: _reviewMode,
                              isReviewQueueEmpty: _isReviewQueueEmpty,
                              nextCollection: _nextCollection(
                                _selectedCollection,
                              ),
                              nextCollectionUnlocked:
                                  _nextCollection(_selectedCollection) !=
                                      null &&
                                  _isCollectionUnlocked(
                                    _nextCollection(_selectedCollection)!,
                                    _progress,
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
                                  ? 'Known ${_countByRating(LetterRating.known)} of ${_items.length}'
                                  : 'Today ${_sessionReviewedCount} of ${_sessionPlan.itemLimit}',
                              knownCount: _countByRating(LetterRating.known),
                              hardCount: _countByRating(LetterRating.hard),
                              notYetCount: _countByRating(LetterRating.notYet),
                              choicesVisible: _choicesVisible,
                              reviewMode: _reviewMode,
                              onReveal: _playCurrentItem,
                              onSkip: _skipCurrentItem,
                              onKnown: () =>
                                  _rateCurrentItem(LetterRating.known),
                              onHard: () => _rateCurrentItem(LetterRating.hard),
                              onNotYet: () =>
                                  _rateCurrentItem(LetterRating.notYet),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CollectionPicker extends StatelessWidget {
  const _CollectionPicker({
    required this.selectedCollection,
    required this.progress,
    required this.onSelected,
  });

  final PracticeCollection selectedCollection;
  final Map<PracticeCollection, List<LetterProgress>> progress;
  final ValueChanged<PracticeCollection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PracticeCollection.values.map((collection) {
        final isSelected = collection == selectedCollection;
        final isUnlocked = _isCollectionUnlocked(collection, progress);
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isUnlocked) ...<Widget>[
                const Icon(Icons.lock_outline, size: 16),
                const SizedBox(width: 6),
              ],
              Text(collection.label),
            ],
          ),
          selected: isSelected,
          onSelected: isUnlocked ? (_) => onSelected(collection) : null,
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

class _ParentDashboard extends StatelessWidget {
  const _ParentDashboard({
    required this.progress,
    required this.recommendedCollection,
  });

  final Map<PracticeCollection, List<LetterProgress>> progress;
  final PracticeCollection recommendedCollection;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          'Parent overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Check progress, weak spots, and what is ready next.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFFF9F3E8),
            builder: (context) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      Text(
                        'Parent overview',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use this to see weak spots, due reviews, and which set should come next.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      for (final collection in PracticeCollection.values)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _CollectionOverviewCard(
                            snapshot: _buildSnapshot(collection, progress),
                            isRecommended: collection == recommendedCollection,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
    final total = snapshot.collection.items.length;
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
    required this.reviewMode,
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
  final ReviewMode reviewMode;
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
            const SizedBox(height: 8),
            Text(
              choicesVisible
                  ? 'Did your child know this ${collection.promptNoun}? Hard and not-yet items will come back more often.'
                  : reviewMode == ReviewMode.reviewOnly
                  ? 'Review-only mode is on, so only due items will appear.'
                  : 'Show the ${collection.promptNoun} first, then tap to hear it.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF4E5D52),
              ),
            ),
            const SizedBox(height: 24),
            _ProgressStrip(
              progressText: progressText,
              knownCount: knownCount,
              hardCount: hardCount,
              notYetCount: notYetCount,
            ),
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
    return collection.items.where((item) => latest[item] == rating).toList();
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
