import 'package:flutter/widgets.dart';
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
      for (final item in PracticeCollection.uppercaseLetters.items)
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

    await tester.pumpWidget(
      LetterLearningApp(speaker: _FakeLetterSpeaker(), progressStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended next: Lowercase letters'), findsOneWidget);
    expect(find.text('Lowercase letters'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
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

    await tester.pumpWidget(
      LetterLearningApp(speaker: _FakeLetterSpeaker(), progressStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick 5'), findsOneWidget);
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

    await tester.pumpWidget(
      LetterLearningApp(speaker: _FakeLetterSpeaker(), progressStore: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parent overview'));
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

    await tester.pumpWidget(
      LetterLearningApp(speaker: _FakeLetterSpeaker(), progressStore: store),
    );
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

    await tester.pumpWidget(
      LetterLearningApp(speaker: _FakeLetterSpeaker(), progressStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Skip for now'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
  });
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
