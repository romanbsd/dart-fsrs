// FSRS-7 behavioral tests ported from ts-fsrs v6.0.0
// `default-scheduler.fsrs7.spec.ts` (minus the rollback/preview APIs that
// this package does not expose).

import 'dart:math';

import 'package:fsrs/fsrs.dart';
import 'package:test/test.dart';

void main() {
  // Model interval of a card's post-review state via the FSRS-7 unit API.
  double modelIntervalOf(Scheduler scheduler, Card card,
          {double? desiredRetention}) =>
      scheduler.nextIntervalFSRS7(
        stability: card.stability!,
        stabilityFast: card.stabilityFast!,
        difficulty: card.difficulty!,
        desiredRetention: desiredRetention,
      );

  // Milliseconds between the review time and the card's due date.
  int dueDeltaMs(Card card, DateTime from) =>
      card.due.millisecondsSinceEpoch - from.millisecondsSinceEpoch;

  group('FSRS-7 scheduler defaults', () {
    test('defaults to FSRS-7 with 34 weights and default steps', () {
      final scheduler = Scheduler();
      expect(scheduler.version, FSRSVersion.fsrs7);
      expect(scheduler.parameters, fsrs7DefaultParameters);
      expect(scheduler.learningSteps,
          [Duration(minutes: 1), Duration(minutes: 10)]);
      expect(scheduler.relearningSteps, [Duration(minutes: 10)]);
      expect(scheduler.allowModelOverride, isTrue);
      expect(scheduler.graduatingInterval, 1.0);
    });

    test('FSRS-6 pin keeps the legacy 21-weight defaults', () {
      final scheduler = Scheduler(version: FSRSVersion.fsrs6);
      expect(scheduler.parameters, fsrs6DefaultParameters);
      expect(scheduler.parameters.length, 21);
    });

    test('new card Again follows the 1m step, not the shorter model', () {
      final scheduler = Scheduler();
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(cardId: 1, state: State.newCard, due: now);
      final result =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now);
      final reviewed = result.card;
      final modelInterval = modelIntervalOf(scheduler, reviewed);
      expect(modelInterval, lessThan(1 / 1440));
      expect(reviewed.scheduledDays, 1 / 1440);
      expect(reviewed.state, State.learning);
      expect(reviewed.step, 0);
      expect(reviewed.due.difference(now), const Duration(minutes: 1));
      expect(reviewed.stabilityFast, isNotNull);
    });
  });

  group('FSRS-7 fractional elapsed days', () {
    test('uses 24-hour fractional days across minutes, not calendar days', () {
      final scheduler = Scheduler();
      final now = DateTime.utc(2024, 6, 1, 23, 58);
      final card = Card(cardId: 2, state: State.newCard, due: now);
      final first =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now);
      final later = now.add(const Duration(minutes: 2));
      final result =
          scheduler.reviewCard(first.card, Rating.good, reviewDateTime: later);

      final expected = scheduler.stepFSRS7(
        stability: first.card.stability,
        stabilityFast: first.card.stabilityFast,
        difficulty: first.card.difficulty,
        elapsedDays: 2 / 1440,
        rating: Rating.good,
      );
      expect(result.card.stability, expected.stability);
      expect(result.card.stabilityFast, expected.stabilityFast);

      // A whole-day elapsed value would give a different state.
      final wholeDay = scheduler.stepFSRS7(
        stability: first.card.stability,
        stabilityFast: first.card.stabilityFast,
        difficulty: first.card.difficulty,
        elapsedDays: 1,
        rating: Rating.good,
      );
      expect(result.card.stability, isNot(wholeDay.stability));
      expect(result.card.elapsedDays, 2 / 1440);
    });

    test('stores fractional scheduledDays and ms-truncated due dates', () {
      final scheduler = Scheduler();
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(cardId: 3, state: State.newCard, due: now);
      final reviewed =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now).card;
      expect(reviewed.scheduledDays, 1 / 1440);
      expect(dueDeltaMs(reviewed, now), 60000);
    });
  });

  group('FSRS-7 model sub-day intervals', () {
    for (final enableFuzzing in [false, true]) {
      test('stay positive and fractional with enableFuzzing=$enableFuzzing',
          () {
        // Reference uses enableShortTerm: false, i.e. no learning steps, so
        // the model interval itself is scheduled.
        final scheduler = Scheduler(
            enableFuzzing: enableFuzzing,
            learningSteps: [],
            relearningSteps: []);
        final now = DateTime.utc(2024, 6, 1);
        final card = Card(cardId: 4, state: State.newCard, due: now);
        final reviewed =
            scheduler.reviewCard(card, Rating.again, reviewDateTime: now).card;
        final interval = modelIntervalOf(scheduler, reviewed);
        expect(interval, greaterThan(0));
        expect(interval, lessThan(1));
        expect(reviewed.scheduledDays, interval);
        expect(dueDeltaMs(reviewed, now),
            (interval * Duration.millisecondsPerDay).truncate());
        expect(reviewed.state, State.learning);
      });
    }
  });

  group('FSRS-7 explicit step second-rounding', () {
    // Reference: only a positive second-rounded step overrides the model.
    const cases = <String, double>{
      '0m': 0,
      '0.001m': 0.001,
      '0.01m': 0.01,
      '1439.6m': 1439.6,
      '1440m': 1440,
    };
    cases.forEach((label, minutes) {
      test('step $label', () {
        final scheduler = Scheduler(
          learningSteps: [Duration(microseconds: (minutes * 60 * 1e6).round())],
          enableFuzzing: true,
          allowModelOverride: false,
        );
        final now = DateTime.utc(2024, 6, 1);
        final card = Card(cardId: 5, state: State.newCard, due: now);
        final reviewed =
            scheduler.reviewCard(card, Rating.again, reviewDateTime: now).card;
        final rounded = (minutes * 60).round() / 60;
        if (rounded > 0) {
          expect(reviewed.scheduledDays, rounded / 1440);
          expect(dueDeltaMs(reviewed, now), (rounded * 60000).round());
          expect(
              reviewed.state, rounded < 1440 ? State.learning : State.review);
        } else {
          final modelInterval = modelIntervalOf(scheduler, reviewed);
          expect(reviewed.scheduledDays, modelInterval);
          expect(reviewed.state, State.learning);
        }
        expect(reviewed.step, reviewed.state == State.review ? null : 0);
      });
    });

    test('a longer model interval overrides a shorter step when enabled', () {
      final scheduler = Scheduler(
        learningSteps: [const Duration(microseconds: 600000)], // 0.01m
        enableFuzzing: true,
        allowModelOverride: true,
      );
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(cardId: 6, state: State.newCard, due: now);
      final reviewed =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now).card;
      final modelInterval = modelIntervalOf(scheduler, reviewed);
      // The 0.01m step rounds to one second, shorter than the model interval.
      expect(modelInterval, greaterThan(1 / 86400));
      expect(modelInterval, lessThan(1));
      expect(reviewed.scheduledDays, modelInterval);
      expect(dueDeltaMs(reviewed, now),
          (modelInterval * Duration.millisecondsPerDay).truncate());
      expect(reviewed.state, State.learning);
      expect(reviewed.step, 0);
    });
  });

  group('FSRS-7 graduation', () {
    test('graduates a completed step to one day when the model is below', () {
      final scheduler = Scheduler(
        desiredRetention: 0.99,
        learningSteps: [const Duration(minutes: 1)],
      );
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(cardId: 7, state: State.newCard, due: now);
      final first =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now);
      expect(first.card.state, State.learning);
      final result = scheduler.reviewCard(first.card, Rating.good,
          reviewDateTime: first.card.due);
      final modelInterval =
          modelIntervalOf(scheduler, result.card, desiredRetention: 0.99);
      expect(modelInterval, lessThan(1));
      expect(result.card.scheduledDays, 1);
      expect(result.card.state, State.review);
      expect(result.card.step, isNull);
    });

    test('graduates for the configured graduating interval', () {
      final scheduler = Scheduler(
        desiredRetention: 0.99,
        learningSteps: [const Duration(minutes: 1)],
        graduatingInterval: 0.5,
      );
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(cardId: 8, state: State.newCard, due: now);
      final first =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now);
      final result = scheduler.reviewCard(first.card, Rating.good,
          reviewDateTime: first.card.due);
      final modelInterval =
          modelIntervalOf(scheduler, result.card, desiredRetention: 0.99);
      expect(modelInterval, lessThan(0.5));
      expect(result.card.scheduledDays, 0.5);
      expect(result.card.state, State.review);
      expect(result.card.step, isNull);
    });

    test('a long model interval graduates a review card Again capped at 1d',
        () {
      // Reference policy table: Review + Again with a 10m step and a long
      // model interval resolves to max(step, min(model, graduating)) = 1d,
      // and the model override keeps the card in relearning.
      final scheduler = Scheduler();
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(
        cardId: 9,
        state: State.review,
        stability: 100,
        stabilityFast: 80,
        difficulty: 5,
        lastReview: now.subtract(const Duration(days: 100)),
        due: now,
        reps: 5,
      );
      final result =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now);
      final modelInterval = modelIntervalOf(scheduler, result.card);
      expect(modelInterval, greaterThan(1));
      expect(result.card.state, State.relearning);
      expect(result.card.lapses, 1);
      expect(result.card.scheduledDays, 1);
      expect(result.card.due.difference(now), const Duration(days: 1));
      expect(result.card.step, 0);
    });
  });

  group('FSRS-7 maximum interval', () {
    test('caps the model interval at maximumInterval', () {
      final scheduler = Scheduler(maximumInterval: 2);
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(
        cardId: 10,
        state: State.review,
        stability: 1000,
        stabilityFast: 800,
        difficulty: 5,
        lastReview: now,
        due: now,
        reps: 3,
      );
      final result = scheduler.reviewCard(card, Rating.easy,
          reviewDateTime: now.add(const Duration(days: 1)));
      final modelInterval = modelIntervalOf(scheduler, result.card);
      expect(modelInterval, greaterThan(2));
      expect(result.card.scheduledDays, 2);
      expect(result.card.state, State.review);
    });
  });

  group('FSRS-7 state transitions without steps', () {
    // Reference: with empty steps the interval decides the state — below one
    // day stays in (re)learning, one day or more graduates to review.
    State expectedState(State entry, double interval) {
      if (interval >= 1) return State.review;
      return switch (entry) {
        State.newCard => State.learning,
        State.review => State.relearning,
        _ => entry,
      };
    }

    final entries = <State, (double, double)>{
      State.newCard: (0.0001, 36500),
      State.learning: (0.0001, 36500),
      State.review: (0.0001, 36500),
      State.relearning: (0.0001, 36500),
    };

    entries.forEach((entry, stabilities) {
      for (final (label, stability) in <(String, double)>[
        ('sub-day', stabilities.$1),
        ('multi-day', stabilities.$2),
      ]) {
        test('$entry card with $label interval', () {
          final scheduler = Scheduler(learningSteps: [], relearningSteps: []);
          final now = DateTime.utc(2024, 6, 1);
          final card = Card(
            cardId: 11,
            state: entry,
            stability: stability,
            stabilityFast: stability * 0.8,
            difficulty: 5,
            lastReview: entry == State.newCard
                ? null
                : now.subtract(const Duration(days: 1)),
            due: now,
            reps: 2,
          );
          final reviewed =
              scheduler.reviewCard(card, Rating.good, reviewDateTime: now).card;
          final interval = modelIntervalOf(scheduler, reviewed);
          // Recompute the decision from the pre-review state, mirroring the
          // mocked nextInterval of the reference test.
          final preInterval = scheduler.nextIntervalFSRS7(
            stability: stability,
            stabilityFast: stability * 0.8,
            difficulty: 5,
            desiredRetention: 0.9,
          );
          expect(interval, greaterThan(0));
          expect(reviewed.state, expectedState(entry, preInterval),
              reason: 'pre-review model interval $preInterval');
          if (reviewed.state == State.review) {
            expect(reviewed.step, isNull);
          } else {
            expect(reviewed.step, 0);
          }
        });
      }
    });
  });

  group('FSRS-7 learningSteps empty equals enableShortTerm false', () {
    test('replays a fractional history identically to the unit-level step', () {
      final scheduler = Scheduler(learningSteps: [], relearningSteps: []);
      final history = <({double deltaT, Rating rating})>[
        (deltaT: 0, rating: Rating.again),
        (deltaT: 0, rating: Rating.good),
        (deltaT: 1, rating: Rating.good),
        (deltaT: 3, rating: Rating.good),
        (deltaT: 8, rating: Rating.good),
        (deltaT: 21, rating: Rating.good),
      ];
      final expected = [
        (0.1104, 0.08832, 6.1686),
        (0.11041191, 0.08832, 6.109214),
        (0.91686124, 44.444206, 6.0504217),
        (3.5337858, 193.5973, 5.9922175),
        (10.186002, 407.62646, 5.934595),
        (25.985723, 700.5589, 5.877549),
      ];
      var time = DateTime.utc(2024, 6, 1);
      var card = Card(cardId: 12, state: State.newCard, due: time);
      for (var i = 0; i < history.length; i++) {
        time = time.add(Duration(
            microseconds:
                (history[i].deltaT * Duration.microsecondsPerDay).round()));
        final result =
            scheduler.reviewCard(card, history[i].rating, reviewDateTime: time);
        final (s, f, d) = expected[i];
        double tolerance(double e) =>
            [1e-7, e.abs() * 1e-4].reduce((a, b) => a > b ? a : b);
        expect(
            (result.card.stability! - s).abs(), lessThanOrEqualTo(tolerance(s)),
            reason: 'stability at review $i');
        expect((result.card.stabilityFast! - f).abs(),
            lessThanOrEqualTo(tolerance(f)),
            reason: 'stabilityFast at review $i');
        expect((result.card.difficulty! - d).abs(),
            lessThanOrEqualTo(tolerance(d)),
            reason: 'difficulty at review $i');
        card = result.card;
      }
    });

    test('an Again on a fresh card stays sub-day with no steps', () {
      final scheduler = Scheduler(learningSteps: [], relearningSteps: []);
      final now = DateTime.utc(2024, 6, 1);
      final card = Card(cardId: 13, state: State.newCard, due: now);
      final reviewed =
          scheduler.reviewCard(card, Rating.again, reviewDateTime: now).card;
      expect(reviewed.scheduledDays, lessThan(1));
      expect(reviewed.state, State.learning);
    });
  });

  group('FSRS-7 curve properties', () {
    test('distinct fast and slow traces, no rounding of fractional days', () {
      final scheduler = Scheduler();
      Card stateCard({required double stabilityFast}) => Card(
            cardId: 14,
            state: State.review,
            stability: 10,
            stabilityFast: stabilityFast,
            difficulty: 5,
            lastReview: DateTime.utc(2024),
            due: DateTime.utc(2024),
          );
      double curveAt(Card card, double days) =>
          scheduler.getCardRetrievability(card,
              currentDateTime: DateTime.utc(2024).add(Duration(
                  microseconds: (days * Duration.microsecondsPerDay).round())));

      final base = stateCard(stabilityFast: 8);
      expect(curveAt(base, 0), closeTo(0.99999, 1e-9));
      expect(curveAt(base, 0.5), isNot(curveAt(base, 0)));
      expect(curveAt(base, 0.5), isNot(curveAt(base, 1)));
      expect(curveAt(stateCard(stabilityFast: 0.01), 0.5),
          isNot(curveAt(base, 0.5)));

      // The step must also distinguish fractional elapsed days.
      final s0 = scheduler.stepFSRS7(
          stability: 10,
          stabilityFast: 8,
          difficulty: 5,
          elapsedDays: 0,
          rating: Rating.good);
      final s05 = scheduler.stepFSRS7(
          stability: 10,
          stabilityFast: 8,
          difficulty: 5,
          elapsedDays: 0.5,
          rating: Rating.good);
      final s1 = scheduler.stepFSRS7(
          stability: 10,
          stabilityFast: 8,
          difficulty: 5,
          elapsedDays: 1,
          rating: Rating.good);
      expect(s05.stability, isNot(s0.stability));
      expect(s05.stability, isNot(s1.stability));
    });

    test('w20 is not a forgetting-curve decay parameter', () {
      final weightsA = List<double>.from(fsrs7DefaultParameters)..[20] = 0.001;
      final weightsB = List<double>.from(fsrs7DefaultParameters)..[20] = 5;
      final a = Scheduler(parameters: weightsA);
      final b = Scheduler(parameters: weightsB);
      Card stateCard() => Card(
            cardId: 15,
            state: State.review,
            stability: 12,
            stabilityFast: 9.6,
            difficulty: 5,
            lastReview: DateTime.utc(2024),
            due: DateTime.utc(2024),
          );
      const at = Duration(days: 10);
      expect(
        a.getCardRetrievability(stateCard(),
            currentDateTime: DateTime.utc(2024).add(at)),
        b.getCardRetrievability(stateCard(),
            currentDateTime: DateTime.utc(2024).add(at)),
      );
    });

    test('retrievability is 0 without a last review', () {
      final scheduler = Scheduler();
      final card = Card(cardId: 16, state: State.newCard);
      expect(scheduler.getCardRetrievability(card), 0);
    });

    test('repeated lapse stays under two minutes, next Good over two hours',
        () {
      final scheduler = Scheduler();
      final history = <({double deltaT, Rating rating})>[
        (deltaT: 0, rating: Rating.again),
        (deltaT: 0.99791664, rating: Rating.again),
        (deltaT: 0.82361114, rating: Rating.again),
        (deltaT: 1.0388889, rating: Rating.again),
        (deltaT: 0.0013888889, rating: Rating.good),
        (deltaT: 0.0020833334, rating: Rating.good),
        (deltaT: 0.0020833334, rating: Rating.good),
        (deltaT: 0.0027777778, rating: Rating.good),
      ];
      var state = scheduler.stepFSRS7(
          elapsedDays: history.first.deltaT, rating: history.first.rating);
      final states = [state];
      for (var i = 1; i < history.length; i++) {
        state = scheduler.stepFSRS7(
          stability: state.stability,
          stabilityFast: state.stabilityFast,
          difficulty: state.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
        states.add(state);
      }
      final again = scheduler.nextIntervalFSRS7(
              stability: states[3].stability,
              stabilityFast: states[3].stabilityFast,
              difficulty: states[3].difficulty,
              desiredRetention: 0.65) *
          1440;
      expect(again, greaterThan(0));
      expect(again, lessThan(2));
      final good = scheduler.nextIntervalFSRS7(
              stability: states[4].stability,
              stabilityFast: states[4].stabilityFast,
              difficulty: states[4].difficulty,
              desiredRetention: 0.65) *
          1440;
      expect(good, greaterThan(120));
    });
  });

  group('FSRS-7 fuzzing', () {
    test('is deterministic per card id and reps, ignoring customRandom', () {
      final now = DateTime.utc(2024, 6, 1);
      Card longCard() => Card(
            cardId: 42,
            state: State.review,
            stability: 400,
            stabilityFast: 320,
            difficulty: 5,
            lastReview: now,
            due: now,
            reps: 7,
          );
      final a = Scheduler.customRandom(Random(1),
          enableFuzzing: true, learningSteps: [], relearningSteps: []);
      final b = Scheduler.customRandom(Random(999),
          enableFuzzing: true, learningSteps: [], relearningSteps: []);
      final unfuzzed = Scheduler(
          enableFuzzing: false, learningSteps: [], relearningSteps: []);
      final dueA = a
          .reviewCard(longCard(), Rating.good,
              reviewDateTime: now.add(const Duration(days: 100)))
          .card
          .due;
      final dueB = b
          .reviewCard(longCard(), Rating.good,
              reviewDateTime: now.add(const Duration(days: 100)))
          .card
          .due;
      final dueU = unfuzzed
          .reviewCard(longCard(), Rating.good,
              reviewDateTime: now.add(const Duration(days: 100)))
          .card
          .due;
      expect(dueA, dueB);
      expect(dueA, isNot(dueU));
    });

    test('leaves intervals below 2.5 days unfuzzed', () {
      final now = DateTime.utc(2024, 6, 1);
      Card midCard() => Card(
            cardId: 43,
            state: State.review,
            stability: 0.5,
            stabilityFast: 0.4,
            difficulty: 5,
            lastReview: now,
            due: now,
            reps: 2,
          );
      final fuzzed = Scheduler(
          enableFuzzing: true, learningSteps: [], relearningSteps: []);
      final plain = Scheduler(
          enableFuzzing: false, learningSteps: [], relearningSteps: []);
      final reviewTime = now.add(const Duration(days: 1));
      final dueFuzzed = fuzzed
          .reviewCard(midCard(), Rating.good, reviewDateTime: reviewTime)
          .card;
      final duePlain = plain
          .reviewCard(midCard(), Rating.good, reviewDateTime: reviewTime)
          .card;
      final interval = modelIntervalOf(fuzzed, duePlain);
      expect(interval, lessThan(2.5));
      expect(dueFuzzed.due, duePlain.due);
    });
  });

  group('FSRS-7 validation', () {
    test('requires exactly 34 weights', () {
      expect(
          () => Scheduler(
              parameters:
                  List<double>.from(fsrs7DefaultParameters.sublist(0, 33))),
          throwsArgumentError);
      expect(
          () => Scheduler(
              version: FSRSVersion.fsrs6, parameters: fsrs7DefaultParameters),
          throwsArgumentError);
      expect(() => Scheduler(parameters: const []), throwsArgumentError);
    });

    test('rejects non-finite weights', () {
      final weights = List<double>.from(fsrs7DefaultParameters)
        ..[10] = double.nan;
      expect(() => Scheduler(parameters: weights), throwsArgumentError);
    });

    test('silently clips out-of-bounds weights in place', () {
      final weights = List<double>.from(fsrs7DefaultParameters)
        ..[6] = 100
        ..[10] = -42;
      final scheduler = Scheduler(parameters: weights);
      expect(scheduler.parameters[6], 4.0);
      expect(scheduler.parameters[10], 0.01);
    });

    test('applies cross-parameter monotonicity in index order', () {
      final weights = List<double>.from(fsrs7DefaultParameters)
        ..[1] = 0.0001 // below w[0] and its own box min
        ..[25] = 0.2 // below w[24]=0.0801? no: 0.2 > 0.0801, keep
        ..[26] = 0.5; // below w[25]
      weights[26] = 0.5; // box min for 26 is 0.5, but must be >= w[25]=0.2421
      final scheduler = Scheduler(parameters: weights);
      // w[1] = max(boxMin 1e-4, w[0] 0.1104) = 0.1104.
      expect(scheduler.parameters[1], 0.1104);
      // w[26] = max(boxMin 0.5, w[25]) after w[25] is unchanged (0.2421).
      expect(scheduler.parameters[26], 0.5);
      // The clip is idempotent: re-validating an already-clipped set passes.
      expect(
          () => Scheduler(parameters: List<double>.from(scheduler.parameters)),
          returnsNormally);
    });

    test('FSRS-7 validates desiredRetention, FSRS-6 does not', () {
      expect(() => Scheduler(desiredRetention: 0), throwsArgumentError);
      expect(() => Scheduler(desiredRetention: 1), throwsArgumentError);
      expect(() => Scheduler(desiredRetention: -0.5), throwsArgumentError);
      expect(
          () => Scheduler(desiredRetention: double.nan), throwsArgumentError);
      expect(() => Scheduler(version: FSRSVersion.fsrs6, desiredRetention: 0),
          returnsNormally);
    });

    test('stepFSRS7 and nextIntervalFSRS7 require the FSRS-7 scheduler', () {
      final legacy = Scheduler(version: FSRSVersion.fsrs6);
      expect(() => legacy.stepFSRS7(elapsedDays: 0, rating: Rating.good),
          throwsStateError);
      expect(
          () => legacy.nextIntervalFSRS7(
              stability: 1, stabilityFast: 0.8, difficulty: 5),
          throwsStateError);
    });

    test('stepFSRS7 rejects a non-positive existing state', () {
      final scheduler = Scheduler();
      expect(
          () => scheduler.stepFSRS7(
                stability: 0,
                stabilityFast: 5,
                difficulty: 5,
                elapsedDays: 1,
                rating: Rating.good,
              ),
          throwsArgumentError);
    });

    test('nextIntervalFSRS7 rejects retention outside (0,1)', () {
      final scheduler = Scheduler();
      expect(
          () => scheduler.nextIntervalFSRS7(
              stability: 1,
              stabilityFast: 0.8,
              difficulty: 5,
              desiredRetention: 1),
          throwsArgumentError);
      expect(
          () => scheduler.nextIntervalFSRS7(
              stability: 1,
              stabilityFast: 0.8,
              difficulty: 5,
              desiredRetention: 0),
          throwsArgumentError);
    });

    test('saturated retention yields a zero interval', () {
      final scheduler = Scheduler();
      expect(
          scheduler.nextIntervalFSRS7(
              stability: 1,
              stabilityFast: 0.8,
              difficulty: 5,
              desiredRetention: 0.9999),
          0);
    });
  });

  group('FSRS-7 serialization', () {
    test('toMap/fromMap round-trips version, weights and the fast trace', () {
      final scheduler = Scheduler(
        version: FSRSVersion.fsrs7,
        graduatingInterval: 2,
        allowModelOverride: false,
      );
      final map = scheduler.toMap();
      expect(map['version'], 'FSRS-7');
      expect(map['graduatingInterval'], 2.0);
      expect(map['allowModelOverride'], isFalse);
      final restored = Scheduler.fromMap(map);
      expect(restored, scheduler);

      final card = Card(
        cardId: 77,
        state: State.review,
        stability: 12.5,
        stabilityFast: 9.75,
        difficulty: 6.25,
        elapsedDays: 1.5,
        scheduledDays: 2.25,
      );
      final cardMap = card.toMap();
      expect(cardMap['stabilityFast'], 9.75);
      final cardCopy = Card.fromMap(cardMap);
      expect(cardCopy, card);
      expect(cardCopy.elapsedDays, 1.5);
      expect(cardCopy.scheduledDays, 2.25);
    });

    test('fromMap infers FSRS-7 from 34 weights and FSRS-6 from 21', () {
      final map7 = Scheduler(version: FSRSVersion.fsrs7).toMap()
        ..remove('version');
      expect(Scheduler.fromMap(map7).version, FSRSVersion.fsrs7);

      final map6 = Scheduler(version: FSRSVersion.fsrs6).toMap()
        ..remove('version');
      expect(Scheduler.fromMap(map6).version, FSRSVersion.fsrs6);

      // Legacy maps without the new keys default to graduation + override.
      map6.remove('graduatingInterval');
      map6.remove('allowModelOverride');
      final legacy = Scheduler.fromMap(map6);
      expect(legacy.graduatingInterval, 1.0);
      expect(legacy.allowModelOverride, isTrue);
    });
  });
}
