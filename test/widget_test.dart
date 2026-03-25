import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learntoread/main.dart';

void main() {
  test('scheduler brings back not-yet items before unseen items', () {
    const responses = <LetterProgress>[
      LetterProgress(item: 'A', rating: LetterRating.notYet),
    ];

    final next = ReviewScheduler.chooseNextItem(
      PracticeCollection.uppercaseLetters,
      responses,
    );

    expect(next, 'A');
  });

  test('scheduler gives known items a longer interval than hard items', () {
    const responses = <LetterProgress>[
      LetterProgress(item: 'A', rating: LetterRating.known),
      LetterProgress(item: 'B', rating: LetterRating.hard),
    ];

    final states = ReviewScheduler.buildStates(
      PracticeCollection.uppercaseLetters,
      responses,
    );

    expect(states['A']!.dueStep, greaterThan(states['B']!.dueStep));
  });

  test('collection is only mastered when every item is known and not due', () {
    final inProgress = <LetterProgress>[
      for (final item in PracticeCollection.uppercaseLetters.defaultItems)
        LetterProgress(item: item, rating: LetterRating.known),
    ];

    expect(
      ReviewScheduler.isCollectionMastered(
        PracticeCollection.uppercaseLetters,
        inProgress,
      ),
      isFalse,
    );

    final stabilized = _stabilizedResponses(
      PracticeCollection.uppercaseLetters,
    );

    expect(
      ReviewScheduler.isCollectionMastered(
        PracticeCollection.uppercaseLetters,
        stabilized,
      ),
      isTrue,
    );
  });

  testWidgets('app recommends lowercase after uppercase is stabilized', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
        PracticeCollection.uppercaseLetters: _stabilizedResponses(
          PracticeCollection.uppercaseLetters,
        ),
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Recommended next: Lowercase letters'), findsOneWidget);
    expect(find.text('Lowercase letters'), findsAtLeastNWidgets(1));
    expect(find.textContaining(RegExp(r'^[a-z]$')), findsOneWidget);
  });

  testWidgets('quick session mode stops after five reviews', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Quick 5'), findsOneWidget);
    await tester.tap(find.text('Quick 5'));
    await tester.pumpAndSettle();

    expect(find.text('Today 0 of 5'), findsOneWidget);

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(const Key('practice-card')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Known'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Known'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Session complete'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Keep going'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Keep going'), findsOneWidget);
  });

  testWidgets('parent overview shows per-set progress and due counts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
        PracticeCollection.uppercaseLetters: const <LetterProgress>[
          LetterProgress(item: 'A', rating: LetterRating.known),
          LetterProgress(item: 'B', rating: LetterRating.notYet),
          LetterProgress(item: 'B', rating: LetterRating.notYet),
        ],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Parent overview'), findsAtLeastNWidgets(1));
    expect(find.text('Uppercase letters'), findsAtLeastNWidgets(1));
    expect(find.text('Known 1/26'), findsOneWidget);
    expect(find.text('Seen 2/26'), findsOneWidget);
    expect(find.text('Due 1'), findsOneWidget);
    expect(find.text('Weak 1'), findsOneWidget);
  });

  testWidgets('review-only mode stops when no reviews are due', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review only'));
    await tester.pumpAndSettle();

    expect(find.text('Review caught up'), findsOneWidget);
  });

  testWidgets('skip for now moves to another item without saving a rating', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    final firstItem = find.textContaining(RegExp(r'^[A-Z]$'));
    expect(firstItem, findsOneWidget);
    final firstLabel = tester.widget<Text>(firstItem).data!;
    await tester.scrollUntilVisible(find.text('Skip for now'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    final secondItem = find.textContaining(RegExp(r'^[A-Z]$'));
    expect(secondItem, findsOneWidget);
    expect(tester.widget<Text>(secondItem).data, isNot(firstLabel));
  });

  testWidgets('known answers show a celebration banner', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('practice-card')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Known'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Known'));
    await tester.pump();

    expect(find.text('Nice job!'), findsOneWidget);
  });

  testWidgets('settings show editable word lists and allow adding words', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
        PracticeCollection.uppercaseLetters: _stabilizedResponses(
          PracticeCollection.uppercaseLetters,
        ),
        PracticeCollection.lowercaseLetters: _stabilizedResponses(
          PracticeCollection.lowercaseLetters,
        ),
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Two-letter words'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('two_letter_words-av')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-word-two_letter_words')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'ax');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('two_letter_words-ax')), findsOneWidget);
  });

  testWidgets('continuous mode keeps reviewing without session summary', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuous'));
    await tester.pumpAndSettle();

    expect(find.text('Continuous'), findsOneWidget);

    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byKey(const Key('practice-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Known'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Session complete'), findsNothing);
    expect(find.byKey(const Key('practice-card')), findsOneWidget);
  });

  testWidgets('all sets are selectable from the start', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
      },
    );

    await tester.pumpWidget(_buildTestApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3-letter'));
    await tester.pumpAndSettle();

    expect(find.text('Three-letter words'), findsOneWidget);
    expect(find.byKey(const Key('practice-card')), findsOneWidget);
  });
}

LetterLearningApp _buildTestApp(
  _FakeProgressStore store, {
  _FakeCollectionStore? collectionStore,
}) {
  return LetterLearningApp(
    speaker: _FakeLetterSpeaker(),
    progressStore: store,
    collectionStore: collectionStore ?? _FakeCollectionStore(),
  );
}

List<LetterProgress> _stabilizedResponses(PracticeCollection collection) {
  final responses = <LetterProgress>[];

  for (var step = 0; step < 400; step++) {
    if (ReviewScheduler.isCollectionMastered(collection, responses)) {
      return responses;
    }

    responses.add(
      LetterProgress(
        item: ReviewScheduler.chooseNextItem(collection, responses)!,
        rating: LetterRating.known,
      ),
    );
  }

  throw StateError('Failed to stabilize ${collection.title} in 400 reviews.');
}

class _FakeLetterSpeaker implements LetterSpeaker {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> speakItem(String item) async {}
}

class _FakeProgressStore implements ProgressStore {
  _FakeProgressStore({
    required Map<PracticeCollection, List<LetterProgress>> initialProgress,
  }) : _stored = <PracticeCollection, List<LetterProgress>>{
         for (final entry in initialProgress.entries)
           entry.key: List<LetterProgress>.from(entry.value),
       };

  Map<PracticeCollection, List<LetterProgress>> _stored;

  @override
  Future<Map<PracticeCollection, List<LetterProgress>>> loadProgress() async {
    return <PracticeCollection, List<LetterProgress>>{
      for (final entry in _stored.entries)
        entry.key: List<LetterProgress>.from(entry.value),
    };
  }

  @override
  Future<void> saveProgress(
    Map<PracticeCollection, List<LetterProgress>> progress,
  ) async {
    _stored = <PracticeCollection, List<LetterProgress>>{
      for (final entry in progress.entries)
        entry.key: List<LetterProgress>.from(entry.value),
    };
  }
}

class _FakeCollectionStore implements CollectionStore {
  _FakeCollectionStore({
    Map<PracticeCollection, List<String>>? initialCollections,
  }) : _stored = <PracticeCollection, List<String>>{
         for (final collection in PracticeCollection.values)
           collection: List<String>.from(
             initialCollections?[collection] ?? collection.defaultItems,
           ),
       };

  Map<PracticeCollection, List<String>> _stored;

  @override
  Future<Map<PracticeCollection, List<String>>> loadCollections() async {
    return <PracticeCollection, List<String>>{
      for (final entry in _stored.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  @override
  Future<void> saveCollection(
    PracticeCollection collection,
    List<String> items,
  ) async {
    _stored = <PracticeCollection, List<String>>{
      for (final entry in _stored.entries)
        entry.key: entry.key == collection
            ? List<String>.from(items)
            : List<String>.from(entry.value),
    };
  }
}
