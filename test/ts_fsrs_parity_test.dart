import 'package:fsrs/fsrs.dart';
import 'package:test/test.dart';

/// Server FSRS-6 defaults from ts-fsrs `generatorParameters()` (ts-fsrs 5.4.2).
const w = <double>[
  0.212,
  1.2931,
  2.3065,
  8.2956,
  6.4133,
  0.8334,
  3.0194,
  0.001,
  1.8722,
  0.1666,
  0.796,
  1.4835,
  0.0614,
  0.2629,
  1.6483,
  0.6014,
  1.8729,
  0.5425,
  0.0912,
  0.0658,
  0.1542,
];

/// ts-fsrs test clock: 2023-01-15 09:00 UTC.
final t0 = DateTime.utc(2023, 1, 15, 9);

/// A scheduler with the exact ts-fsrs defaults used by the reference probes.
Scheduler referenceScheduler({int maximumInterval = 36500}) => Scheduler(
      version: FSRSVersion.fsrs6,
      parameters: w,
      desiredRetention: 0.9,
      maximumInterval: maximumInterval,
      enableFuzzing: false,
    );

void main() {
  test('newCard + Good matches ts-fsrs FSRS-6 golden counters', () {
    final now = DateTime.utc(2025);
    final scheduler = referenceScheduler();
    final card = Card(cardId: 1, due: now, state: State.newCard);

    final next = scheduler.reviewCard(card, Rating.good, reviewDateTime: now);

    expect(next.card.stability, closeTo(2.3065, 1e-4));
    expect(next.card.difficulty, closeTo(2.11810397, 1e-6));
    expect(next.card.reps, 1);
    expect(next.card.lapses, 0);
    expect(next.card.elapsedDays, 0);
    expect(next.card.scheduledDays, 0);
    expect(next.card.state.value, 1);
    expect(next.card.due.difference(now).inSeconds, 600);
  });

  test('ts-fsrs goldens: Hard on a [1m, 10m] learning card is 6 minutes', () {
    final scheduler = referenceScheduler();
    final card = Card(cardId: 1, due: t0, state: State.newCard);

    final first = scheduler.reviewCard(card, Rating.good, reviewDateTime: t0);
    // Good on a new card schedules the *next* learning step (10 minutes).
    expect(first.card.state, State.learning);
    expect(first.card.step, 1);
    expect(first.card.due.difference(t0).inMinutes, 10);

    // Hard re-schedules at round((first + second) / 2) = 6 minutes without
    // advancing the step (ts-fsrs next_step = cur_step).
    final hard = scheduler.reviewCard(
      first.card,
      Rating.hard,
      reviewDateTime: t0,
    );
    expect(hard.card.state, State.learning);
    expect(hard.card.step, 1);
    expect(hard.card.due.difference(t0), const Duration(minutes: 6));
    expect(hard.card.scheduledDays, 0);
  });

  test('ts-fsrs goldens: graduation, counter, and relearning flow', () {
    final scheduler = referenceScheduler();
    final card = Card(cardId: 1, due: t0, state: State.newCard);

    // Rating 1: Good -> learning step 1, due in 10 minutes.
    final r1 = scheduler.reviewCard(card, Rating.good, reviewDateTime: t0);
    final t1 = r1.card.due;
    expect(r1.card.state, State.learning);
    expect(r1.card.step, 1);
    expect(r1.card.reps, 1);
    expect(r1.card.elapsedDays, 0);

    // Rating 2: Good at due -> the step schedule is exhausted, so the card
    // graduates to Review. Same UTC day (elapsed 0) so the short-term formula
    // applies: sinc < 1 for Good, floored at 1.0 -> stability unchanged.
    final r2 = scheduler.reviewCard(r1.card, Rating.good, reviewDateTime: t1);
    expect(r2.card.state, State.review);
    expect(r2.card.stability, closeTo(2.3065, 1e-6));
    expect(r2.card.difficulty, closeTo(2.11121424, 1e-6));
    expect(r2.card.scheduledDays, 2);
    expect(r2.card.elapsedDays, 0);
    expect(r2.card.reps, 2);
    expect(r2.card.due, t1.add(const Duration(days: 2)));

    // Rating 3: Again at due -> lapse; the card enters Relearning at step 0
    // and is due in 10 minutes.
    final r3 = scheduler.reviewCard(r2.card, Rating.again,
        reviewDateTime: t1.add(const Duration(days: 2)));
    expect(r3.card.state, State.relearning);
    expect(r3.card.step, 0);
    expect(r3.card.scheduledDays, 0);
    expect(r3.card.elapsedDays, 2);
    expect(r3.card.reps, 3);
    expect(r3.card.lapses, 1);
    expect(r3.card.stability, closeTo(0.60770166, 1e-6));
    expect(
      r3.card.due,
      t1.add(const Duration(days: 2, minutes: 10)),
    );
  });

  test('ts-fsrs goldens: New + Again enters Learning at 1 minute', () {
    final scheduler = referenceScheduler();
    final card = Card(cardId: 1, due: t0, state: State.newCard);

    final next = scheduler.reviewCard(card, Rating.again, reviewDateTime: t0);

    expect(next.card.state, State.learning);
    expect(next.card.step, 0);
    expect(next.card.due.difference(t0), const Duration(minutes: 1));
    expect(next.card.scheduledDays, 0);
    expect(next.card.reps, 1);
    expect(next.card.lapses, 0);
    expect(next.card.stability, closeTo(0.212, 1e-6));
    expect(next.card.difficulty, closeTo(6.4133, 1e-6));
  });

  test(
      'ts-fsrs goldens: same-day Hard leaves a Review card stability unchanged',
      () {
    final scheduler = referenceScheduler();
    final card = Card(cardId: 1, due: t0, state: State.newCard);

    // Easy on a new card graduates it straight to Review (there is no Easy
    // entry in the learning-steps strategy): stability 8.2956, difficulty
    // clamped to 1.0, scheduled 8 days out.
    final easy = scheduler.reviewCard(card, Rating.easy, reviewDateTime: t0);
    expect(easy.card.state, State.review);
    expect(easy.card.stability, closeTo(8.2956, 1e-6));
    expect(easy.card.difficulty, closeTo(1.0, 1e-6));
    expect(easy.card.scheduledDays, 8);
    expect(easy.card.due.difference(t0), const Duration(days: 8));

    // Hard reviewed the same instant (elapsed 0): the short-term stability
    // sinc for Hard is below 1.0, floored to 1.0, so stability is unchanged.
    final hard = scheduler.reviewCard(
      easy.card,
      Rating.hard,
      reviewDateTime: t0,
    );
    expect(hard.card.stability, closeTo(easy.card.stability!, 1e-9));
    expect(hard.card.difficulty, closeTo(4.01060897, 1e-6));
    expect(hard.card.scheduledDays, 8);
    expect(hard.card.elapsedDays, 0);
    expect(hard.card.reps, 2);
    expect(hard.card.lapses, 0);
    expect(hard.card.due.difference(t0), const Duration(days: 8));
  });

  test('ts-fsrs goldens: Again at the last learning step graduates to Review',
      () {
    final scheduler = referenceScheduler();
    // A card at learning step 2 of a 2-step schedule: the ts-fsrs step
    // strategy returns {} for any grade, graduating the card.
    final card = Card(
      cardId: 1,
      state: State.learning,
      step: 2,
      stability: 2.5,
      difficulty: 5.0,
      due: t0,
      lastReview: t0,
    );

    final next = scheduler.reviewCard(card, Rating.again, reviewDateTime: t0);

    expect(next.card.state, State.review);
    expect(next.card.step, isNull,
        reason: 'dart-fsrs documents step as null in the Review state');
    expect(next.card.scheduledDays, 1);
    expect(next.card.stability, closeTo(0.83566689, 1e-6));
    expect(next.card.reps, 1);
    expect(next.card.lapses, 0);
    expect(next.card.due.difference(t0), const Duration(days: 1));
  });
}
