import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learntoread/main.dart';

void main() {
  testWidgets('repeats not-yet items before moving on', (
    WidgetTester tester,
  ) async {
    final speaker = _FakeLetterSpeaker();
    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
        PracticeCollection.uppercaseLetters: const <LetterProgress>[
          LetterProgress(item: 'A', rating: LetterRating.known),
        ],
      },
    );

    await tester.pumpWidget(
      LetterLearningApp(speaker: speaker, progressStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended next: Uppercase letters'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Known 1 of 26'), findsOneWidget);

    await tester.tap(find.text('abc'));
    await tester.pumpAndSettle();

    expect(find.text('Uppercase letters'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('practice-card')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Not yet'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();

    expect(speaker.playedItems.last, 'B');
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Not yet 1'), findsOneWidget);
    expect(
      store.savedSnapshots.last[PracticeCollection.uppercaseLetters]!.last.item,
      'B',
    );
    expect(
      store
          .savedSnapshots
          .last[PracticeCollection.uppercaseLetters]!
          .last
          .rating,
      LetterRating.notYet,
    );
  });

  testWidgets('unlocks sets in order as shorter foundations are mastered', (
    WidgetTester tester,
  ) async {
    final speaker = _FakeLetterSpeaker();
    final store = _FakeProgressStore(
      initialProgress: <PracticeCollection, List<LetterProgress>>{
        for (final collection in PracticeCollection.values)
          collection: <LetterProgress>[],
        PracticeCollection.uppercaseLetters: [
          for (final item in PracticeCollection.uppercaseLetters.items)
            LetterProgress(item: item, rating: LetterRating.known),
        ],
      },
    );

    await tester.pumpWidget(
      LetterLearningApp(speaker: speaker, progressStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended next: Lowercase letters'), findsOneWidget);
    expect(find.text('Lowercase letters'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);

    await tester.tap(find.text('2-letter'));
    await tester.pumpAndSettle();

    expect(find.text('Lowercase letters'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
  });
}

class _FakeLetterSpeaker implements LetterSpeaker {
  final List<String> playedItems = <String>[];

  @override
  Future<void> dispose() async {}

  @override
  Future<void> speakItem(String item) async {
    playedItems.add(item);
  }
}

class _FakeProgressStore implements ProgressStore {
  _FakeProgressStore({
    required Map<PracticeCollection, List<LetterProgress>> initialProgress,
  }) : _stored = <PracticeCollection, List<LetterProgress>>{
         for (final entry in initialProgress.entries)
           entry.key: List<LetterProgress>.from(entry.value),
       };

  final List<Map<PracticeCollection, List<LetterProgress>>> savedSnapshots =
      <Map<PracticeCollection, List<LetterProgress>>>[];
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
    savedSnapshots.add(_stored);
  }
}
