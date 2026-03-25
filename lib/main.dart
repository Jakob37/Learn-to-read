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
  final ratings = _latestRatings(responses);
  return collection.items.every((item) => ratings[item] == LetterRating.known);
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

String _chooseNextItem(
  PracticeCollection collection,
  List<LetterProgress> responses,
) {
  final latest = _latestRatings(responses);
  final notYetItems = <String>[];
  final hardItems = <String>[];
  final unseenItems = <String>[];

  for (final item in collection.items) {
    final rating = latest[item];

    if (rating == null) {
      unseenItems.add(item);
    } else if (rating == LetterRating.notYet) {
      notYetItems.add(item);
    } else if (rating == LetterRating.hard) {
      hardItems.add(item);
    }
  }

  if (notYetItems.isNotEmpty) {
    return _leastRecentlyReviewedItem(notYetItems, responses);
  }

  if (hardItems.isNotEmpty) {
    return _leastRecentlyReviewedItem(hardItems, responses);
  }

  if (unseenItems.isNotEmpty) {
    return unseenItems.first;
  }

  return collection.items.first;
}

String _leastRecentlyReviewedItem(
  List<String> candidates,
  List<LetterProgress> responses,
) {
  String bestItem = candidates.first;
  var bestIndex = responses.length;

  for (final candidate in candidates) {
    final reviewIndex = responses.lastIndexWhere(
      (response) => response.item == candidate,
    );

    if (reviewIndex < bestIndex) {
      bestItem = candidate;
      bestIndex = reviewIndex;
    }
  }

  return bestItem;
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
  bool _choicesVisible = false;
  bool _isLoading = true;

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

  String get _currentItem => _chooseNextItem(_selectedCollection, _responses);

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
    if (_isComplete) {
      return;
    }

    await widget.speaker.speakItem(_currentItem);

    if (!mounted || _choicesVisible) {
      return;
    }

    setState(() {
      _choicesVisible = true;
    });
  }

  Future<void> _rateCurrentItem(LetterRating rating) async {
    if (_isComplete) {
      return;
    }

    final currentItem = _currentItem;

    setState(() {
      _progress[_selectedCollection] = <LetterProgress>[
        ..._responses,
        LetterProgress(item: currentItem, rating: rating),
      ];
      _choicesVisible = false;
    });

    await _saveProgress();
  }

  Future<void> _restartCollection() async {
    setState(() {
      _progress[_selectedCollection] = <LetterProgress>[];
      _choicesVisible = false;
    });

    await _saveProgress();
  }

  void _selectCollection(PracticeCollection collection) {
    if (!_isCollectionUnlocked(collection, _progress)) {
      return;
    }

    setState(() {
      _selectedCollection = collection;
      _choicesVisible = false;
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
                    _RecommendationBanner(
                      collection: _recommendedCollection(_progress),
                    ),
                    const SizedBox(height: 16),
                    _CollectionPicker(
                      selectedCollection: _selectedCollection,
                      progress: _progress,
                      onSelected: _selectCollection,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _isComplete
                          ? _SessionSummary(
                              theme: theme,
                              collection: _selectedCollection,
                              responses: _responses,
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
                              onRestart: _restartCollection,
                            )
                          : _PracticeView(
                              theme: theme,
                              collection: _selectedCollection,
                              currentItem: _currentItem,
                              progressText:
                                  'Known ${_countByRating(LetterRating.known)} of ${_items.length}',
                              knownCount: _countByRating(LetterRating.known),
                              hardCount: _countByRating(LetterRating.hard),
                              notYetCount: _countByRating(LetterRating.notYet),
                              choicesVisible: _choicesVisible,
                              onReveal: _playCurrentItem,
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
    required this.onReveal,
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
  final Future<void> Function() onReveal;
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
    required this.nextCollection,
    required this.nextCollectionUnlocked,
    required this.onContinue,
    required this.onRestart,
  });

  final ThemeData theme;
  final PracticeCollection collection;
  final List<LetterProgress> responses;
  final PracticeCollection? nextCollection;
  final bool nextCollectionUnlocked;
  final VoidCallback onContinue;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${collection.title} complete',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use this summary to decide what to repeat next. Progress stays saved on this device.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: <Widget>[
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (nextCollection != null && nextCollectionUnlocked) ...<Widget>[
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF12343B),
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
