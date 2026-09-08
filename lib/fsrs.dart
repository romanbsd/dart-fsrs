/// This module defines each of the classes used in the fsrs package.
///
/// Classes:
///   State: Enum representing the learning state of a Card object.
///   Rating: Enum representing the four possible ratings when reviewing a card.
///   Card: Represents a flashcard in the FSRS system.
///   ReviewLog: Represents the log entry of a Card that has been reviewed.
///   Scheduler: The FSRS spaced-repetition scheduler.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// ts-fsrs 5.4.2 `default_w` (FSRS-6); the previous value was the FSRS-5.1 set.
const defaultParameters = [
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

const stabilityMin = 0.001;
const stabilityMax = 36500.0;
const lowerBoundsParameters = [
  stabilityMin,
  stabilityMin,
  stabilityMin,
  stabilityMin,
  1.0,
  0.001,
  0.001,
  0.001,
  0.0,
  0.0,
  0.001,
  0.001,
  0.001,
  0.001,
  0.0,
  0.0,
  1.0,
  0.0,
  0.0,
  0.01,
  0.1,
];

const initialStabilityMax = 100.0;
const upperBoundsParameters = [
  initialStabilityMax,
  initialStabilityMax,
  initialStabilityMax,
  initialStabilityMax,
  10.0,
  4.0,
  4.0,
  0.75,
  4.5,
  0.8,
  3.5,
  5.0,
  0.25,
  0.9,
  4.0,
  1.0,
  6.0,
  2.0,
  2.0,
  0.8,
  0.8,
];

const minDifficulty = 1.0;
const maxDifficulty = 10.0;

const fuzzRanges = [
  {
    'start': 2.5,
    'end': 7.0,
    'factor': 0.15,
  },
  {
    'start': 7.0,
    'end': 20.0,
    'factor': 0.1,
  },
  {
    'start': 20.0,
    'end': double.infinity,
    'factor': 0.05,
  },
];

/// {@template fsrs.state}
/// Enum representing the learning state of a Card object.
/// {@endtemplate}
enum State {
  /// Unseen card — matches ts-fsrs `State.New` (value 0).
  newCard(0),
  learning(1),
  review(2),
  relearning(3);

  /// {@macro fsrs.state}
  const State(this.value);

  /// {@macro fsrs.state}
  static State fromValue(int value) {
    switch (value) {
      case 0:
        return State.newCard;
      case 1:
        return State.learning;
      case 2:
        return State.review;
      case 3:
        return State.relearning;
      default:
        throw ArgumentError('Invalid state value: $value');
    }
  }

  final int value;
}

/// {@template fsrs.rating}
/// Enum representing the four possible ratings when reviewing a card.
/// {@endtemplate}
enum Rating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  /// {@macro fsrs.rating}
  const Rating(this.value);

  /// {@macro fsrs.rating}
  static Rating fromValue(int value) {
    switch (value) {
      case 1:
        return Rating.again;
      case 2:
        return Rating.hard;
      case 3:
        return Rating.good;
      case 4:
        return Rating.easy;
      default:
        throw ArgumentError('Invalid rating value: $value');
    }
  }

  final int value;
}

/// {@template fsrs.card}
/// Represents a flashcard in the FSRS system.
/// {@endtemplate}
class Card {
  /// The id of the card. Defaults to the epoch milliseconds of when the card was created.
  final int cardId;

  /// The card's current learning state.
  State state;

  /// The card's current learning or relearning step or null if the card is in the Review state.
  int? step;

  /// Core mathematical parameter used for future scheduling.
  double? stability;

  /// Core mathematical parameter used for future scheduling.
  double? difficulty;

  /// The date and time when the card is due next.
  DateTime due;

  /// The date and time of the card's last review.
  DateTime? lastReview;

  /// Number of times the card has been reviewed (ts-fsrs `reps`).
  int reps;

  /// Number of times the card has lapsed (Again while in Review).
  int lapses;

  /// Whole days elapsed since the previous review at the last transition
  /// (ts-fsrs `elapsed_days`).
  int elapsedDays;

  /// Whole days in the interval scheduled by the last transition
  /// (ts-fsrs `scheduled_days`). Sub-day learning intervals are `0`.
  int scheduledDays;

  /// {@macro fsrs.card}
  Card({
    required this.cardId,
    this.state = State.learning,
    this.step,
    this.stability,
    this.difficulty,
    DateTime? due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
  }) : due = due ?? DateTime.now().toUtc() {
    if (state == State.learning && step == null) {
      step = 0;
    }
  }

  // The Python original constructor uses time.sleep which can't be used in
  // Dart's constructor.
  // This method is used to create a Card object matching the behavior of the
  // Python original constructor.
  /// {@macro fsrs.card}
  static Future<Card> create({
    State state = State.learning,
    int? step,
    double? stability,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int reps = 0,
    int lapses = 0,
    int elapsedDays = 0,
    int scheduledDays = 0,
  }) async {
    // epoch milliseconds of when the card was created
    final cardId = DateTime.now().millisecondsSinceEpoch;

    // wait 1ms to prevent potential cardId collision on next Card creation
    await Future.delayed(const Duration(milliseconds: 1));

    return Card(
      cardId: cardId,
      state: state,
      step: step,
      stability: stability,
      difficulty: difficulty,
      due: due,
      lastReview: lastReview,
      reps: reps,
      lapses: lapses,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
    );
  }

  @override
  String toString() {
    return 'Card('
        'cardId: $cardId, '
        'state: $state, '
        'step: $step, '
        'stability: $stability, '
        'difficulty: $difficulty, '
        'due: $due, '
        'lastReview: $lastReview, '
        'reps: $reps, '
        'lapses: $lapses, '
        'elapsedDays: $elapsedDays, '
        'scheduledDays: $scheduledDays)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Card &&
        other.cardId == cardId &&
        other.state == state &&
        other.step == step &&
        other.stability == stability &&
        other.difficulty == difficulty &&
        other.due == due &&
        other.lastReview == lastReview &&
        other.reps == reps &&
        other.lapses == lapses &&
        other.elapsedDays == elapsedDays &&
        other.scheduledDays == scheduledDays;
  }

  @override
  int get hashCode {
    return Object.hash(cardId, state, step, stability, difficulty, due,
        lastReview, reps, lapses, elapsedDays, scheduledDays);
  }

  /// Returns a JSON-serializable Map representation of the Card object.
  ///
  /// This method is specifically useful for storing Card objects in a database.
  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'state': state.value,
      'step': step,
      'stability': stability,
      'difficulty': difficulty,
      'due': due.toIso8601String(),
      'lastReview': lastReview?.toIso8601String(),
      'reps': reps,
      'lapses': lapses,
      'elapsedDays': elapsedDays,
      'scheduledDays': scheduledDays,
    };
  }

  /// {@macro fsrs.card}
  ///
  /// Creates a Card object from an existing Map.
  static Card fromMap(Map<String, dynamic> sourceMap) {
    return Card(
      cardId: sourceMap['cardId'] as int,
      state: State.fromValue(sourceMap['state'] as int),
      step: sourceMap['step'] as int?,
      stability: sourceMap['stability'] as double?,
      difficulty: sourceMap['difficulty'] as double?,
      due: DateTime.parse(sourceMap['due'] as String),
      lastReview: sourceMap['lastReview'] != null
          ? DateTime.parse(sourceMap['lastReview'] as String)
          : null,
      reps: (sourceMap['reps'] as num?)?.toInt() ?? 0,
      lapses: (sourceMap['lapses'] as num?)?.toInt() ?? 0,
      elapsedDays: (sourceMap['elapsedDays'] as num?)?.toInt() ?? 0,
      scheduledDays: (sourceMap['scheduledDays'] as num?)?.toInt() ?? 0,
    );
  }

  /// {@macro fsrs.card}
  ///
  /// Creates a copy of this Card with the given fields replaced with new values.
  Card copyWith({
    int? cardId,
    State? state,
    int? step,
    double? stability,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    int? elapsedDays,
    int? scheduledDays,
  }) {
    return Card(
      cardId: cardId ?? this.cardId,
      state: state ?? this.state,
      step: step ?? this.step,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      due: due ?? this.due,
      lastReview: lastReview ?? this.lastReview,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
    );
  }
}

/// {@template fsrs.review_log}
/// Represents the log entry of a Card object that has been reviewed.
/// {@endtemplate}
class ReviewLog {
  /// The id of the card being reviewed.
  final int cardId;

  /// The rating given to the card during the review.
  final Rating rating;

  /// The date and time of the review.
  final DateTime reviewDateTime;

  /// The number of milliseconds it took to review the card or null if unspecified.
  final int? reviewDuration;

  /// {@macro fsrs.review_log}
  const ReviewLog({
    required this.cardId,
    required this.rating,
    required this.reviewDateTime,
    this.reviewDuration,
  });

  @override
  String toString() {
    return 'ReviewLog('
        'cardId: $cardId, '
        'rating: $rating, '
        'reviewDateTime: $reviewDateTime, '
        'reviewDuration: $reviewDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewLog &&
        other.cardId == cardId &&
        other.rating == rating &&
        other.reviewDateTime == reviewDateTime &&
        other.reviewDuration == reviewDuration;
  }

  @override
  int get hashCode {
    return Object.hash(cardId, rating, reviewDateTime, reviewDuration);
  }

  /// Returns a JSON-serializable Map representation of the ReviewLog object.
  ///
  /// This method is specifically useful for storing ReviewLog objects in a database.
  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'rating': rating.value,
      'reviewDateTime': reviewDateTime.toIso8601String(),
      'reviewDuration': reviewDuration,
    };
  }

  /// {@macro fsrs.review_log}
  ///
  /// Creates a ReviewLog object from an existing Map.
  static ReviewLog fromMap(Map<String, dynamic> sourceMap) {
    return ReviewLog(
      cardId: sourceMap['cardId'] as int,
      rating: Rating.fromValue(sourceMap['rating'] as int),
      reviewDateTime: DateTime.parse(sourceMap['reviewDateTime'] as String),
      reviewDuration: sourceMap['reviewDuration'] as int?,
    );
  }
}

/// {@template fsrs.scheduler}
/// The FSRS scheduler.
///
/// Enables the reviewing and future scheduling of cards according to the FSRS algorithm.
/// {@endtemplate}
class Scheduler {
  /// The model weights of the FSRS scheduler.
  final List<double> parameters;

  /// The desired retention rate of cards scheduled with the scheduler.
  final double desiredRetention;

  /// Small time intervals that schedule cards in the Learning state.
  final List<Duration> learningSteps;

  /// Small time intervals that schedule cards in the Relearning state.
  final List<Duration> relearningSteps;

  /// The maximum number of days a Review-state card can be scheduled into the future.
  final int maximumInterval;

  /// Whether to apply a small amount of random 'fuzz' to calculated intervals.
  final bool enableFuzzing;

  late final double _decay;
  late final double _factor;
  late final double _intervalModifier;

  /// Set by [Scheduler.customRandom]; when null, fuzzing uses the ts-fsrs
  /// `alea` PRNG seeded with [_fuzzSeed] (captured in [reviewCard]).
  math.Random? _fuzzRandom;

  /// ts-fsrs `DefaultInitSeedStrategy` seed for the current review.
  String? _fuzzSeed;

  /// {@macro fsrs.scheduler}
  Scheduler({
    List<double> parameters = defaultParameters,
    this.desiredRetention = 0.9,
    this.learningSteps = const [
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    this.relearningSteps = const [
      Duration(minutes: 10),
    ],
    this.maximumInterval = 36500,
    // ts-fsrs `default_enable_fuzz` is false.
    this.enableFuzzing = false,
  }) : parameters = List<double>.from(parameters) {
    _validateParameters(this.parameters);

    _decay = -this.parameters[20];
    _factor = _roundTo8((math.pow(0.9, 1 / _decay) - 1).toDouble());
    // ts-fsrs `calculate_interval_modifier()`:
    // roundTo((requestRetention^(1/decay) - 1) / factor, 8).
    _intervalModifier = _roundTo8(
        ((math.pow(desiredRetention, 1 / _decay) - 1) / _factor).toDouble());
  }

  /// {@macro fsrs.scheduler}
  ///
  /// Creates a Scheduler with custom random number generator.
  ///
  /// This is useful for testing purposes, where you want to control the randomness of the scheduler.
  @visibleForTesting
  factory Scheduler.customRandom(
    math.Random random, {
    List<double> parameters = defaultParameters,
    double desiredRetention = 0.9,
    List<Duration> learningSteps = const [
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    List<Duration> relearningSteps = const [
      Duration(minutes: 10),
    ],
    int maximumInterval = 36500,
    bool enableFuzzing = false,
  }) {
    final scheduler = Scheduler(
      parameters: parameters,
      desiredRetention: desiredRetention,
      learningSteps: learningSteps,
      relearningSteps: relearningSteps,
      maximumInterval: maximumInterval,
      enableFuzzing: enableFuzzing,
    );

    scheduler._fuzzRandom = random;

    return scheduler;
  }

  void _validateParameters(List<double> parameters) {
    // ts-fsrs `checkParameters()` only accepts the FSRSv4 (17), FSRSv5 (19)
    // and FSRSv6 (21) weight counts, migrating the shorter ones.
    if (parameters.length == 17 || parameters.length == 19) {
      _migrateParameters(parameters);
    } else if (parameters.length != lowerBoundsParameters.length) {
      throw ArgumentError(
          'Expected 17, 19 or 21 parameters, got ${parameters.length}.');
    }

    final errorMessages = <String>[];
    for (int i = 0; i < parameters.length; i++) {
      final parameter = parameters[i];
      final lowerBound = lowerBoundsParameters[i];
      final upperBound = upperBoundsParameters[i];

      if (!(lowerBound <= parameter && parameter <= upperBound)) {
        final errorMessage =
            'parameters[$i] = $parameter is out of bounds: ($lowerBound, $upperBound)';
        errorMessages.add(errorMessage);
      }
    }

    if (errorMessages.isNotEmpty) {
      throw ArgumentError('One or more parameters are out of bounds:\n'
          '${errorMessages.join('\n')}');
    }
  }

  /// Migrates FSRSv4 (17) / FSRSv5 (19) weights to FSRSv6 (21), matching
  /// ts-fsrs `migrateParameters()`.
  void _migrateParameters(List<double> parameters) {
    if (parameters.length == 19) {
      parameters.add(0.0); // w[19]
      parameters.add(0.5); // w[20] = FSRS-5 decay
    } else if (parameters.length == 17) {
      // FSRSv4 → FSRSv6 conversions, applied in ts-fsrs order.
      parameters[4] = _roundTo8(parameters[5] * 2.0 + parameters[4]);
      parameters[5] = _roundTo8(math.log(parameters[5] * 3.0 + 1.0) / 3.0);
      parameters[6] = _roundTo8(parameters[6] + 0.5);
      parameters.add(0.0);
      parameters.add(0.0);
      parameters.add(0.0);
      parameters.add(0.5); // w[20] = FSRS-5 decay
    }

    // ts-fsrs `clipParameters()` clamps migrated weights into bounds, so the
    // appended/derived values (e.g. w[19]=0.0 vs lower bound 0.01) don't fail
    // the range check below. Only runs on the migration path.
    for (int i = 0; i < parameters.length; i++) {
      parameters[i] = parameters[i]
          .clamp(lowerBoundsParameters[i], upperBoundsParameters[i]);
    }
  }

  @override
  String toString() {
    return 'Scheduler('
        'parameters: $parameters, '
        'desiredRetention: $desiredRetention, '
        'learningSteps: $learningSteps, '
        'relearningSteps: $relearningSteps, '
        'maximumInterval: $maximumInterval, '
        'enableFuzzing: $enableFuzzing)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Scheduler &&
        _listEquals(other.parameters, parameters) &&
        other.desiredRetention == desiredRetention &&
        _listEquals(other.learningSteps, learningSteps) &&
        _listEquals(other.relearningSteps, relearningSteps) &&
        other.maximumInterval == maximumInterval &&
        other.enableFuzzing == enableFuzzing;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(parameters),
      desiredRetention,
      Object.hashAll(learningSteps),
      Object.hashAll(relearningSteps),
      maximumInterval,
      enableFuzzing,
    );
  }

  /// Calculates a Card object's current retrievability for a given date and time.
  ///
  /// The retrievability of a card is the predicted probability that the card is correctly recalled at the provided datetime.
  ///
  /// Args:
  ///   - card: The card whose retrievability is to be calculated
  ///   - currentDateTime: The current date and time
  ///
  /// Returns:
  ///   - The retrievability of the Card object.
  double getCardRetrievability(Card card, {DateTime? currentDateTime}) {
    if (currentDateTime != null && !currentDateTime.isUtc) {
      throw ArgumentError('datetime must be in UTC');
    }

    if (card.lastReview == null) {
      return 0;
    }

    currentDateTime ??= DateTime.now().toUtc();
    final elapsedDays =
        math.max(0, _daysBetween(card.lastReview!, currentDateTime));

    return _roundTo8(math
        .pow(1 + _factor * elapsedDays / card.stability!, _decay)
        .toDouble());
  }

  /// Reviews a card with a given rating at a given time for a specified duration.
  ///
  /// Args:
  ///   - [card]: The card being reviewed.
  ///   - [rating]: The chosen rating for the card being reviewed.
  ///   - [reviewDateTime]: The date and time of the review.
  ///   - [reviewDuration]: The number of milliseconds it took to review the card or null if unspecified.
  ///
  /// Returns:
  ///   - A tuple containing the updated, reviewed card and its corresponding review log.
  ///
  /// Throws:
  ///   - ArgumentError: If the [reviewDateTime] argument is not in UTC.
  ({Card card, ReviewLog reviewLog}) reviewCard(
    Card card,
    Rating rating, {
    DateTime? reviewDateTime,
    int? reviewDuration,
  }) {
    if (reviewDateTime != null && !reviewDateTime.isUtc) {
      throw ArgumentError('datetime must be in UTC');
    }

    card = card.copyWith();

    reviewDateTime ??= DateTime.now().toUtc();

    // ts-fsrs `DefaultInitSeedStrategy` seed, captured before the card is
    // mutated: `${review_time}_${reps}_${difficulty * stability}`.
    _fuzzSeed = '${reviewDateTime.millisecondsSinceEpoch}_${card.reps + 1}_'
        '${_jsNumberString((card.difficulty ?? double.nan) * (card.stability ?? double.nan))}';

    final daysSinceLastReview = card.lastReview != null
        ? _daysBetween(card.lastReview!, reviewDateTime)
        : null;

    final wasReview = card.state == State.review;

    // ts-fsrs State.New (0): first review enters the learning path.
    if (card.state == State.newCard) {
      card.state = State.learning;
      card.step ??= 0;
    }

    Duration nextInterval;

    switch (card.state) {
      case State.newCard:
        // Unreachable: newCard is converted to learning above.
        throw StateError('newCard must be converted before scheduling');
      case State.learning:
        // update the card's stability and difficulty
        if (card.stability == null && card.difficulty == null) {
          card.stability = _initialStability(rating);
          card.difficulty = _clampDifficulty(_initialDifficulty(rating));
        } else if (daysSinceLastReview != null && daysSinceLastReview < 1) {
          card.stability = _shortTermStability(
            stability: card.stability!,
            rating: rating,
          );
          card.difficulty = _nextDifficulty(
            difficulty: card.difficulty!,
            rating: rating,
          );
        } else {
          card.stability = _nextStability(
            difficulty: card.difficulty!,
            stability: card.stability!,
            retrievability:
                getCardRetrievability(card, currentDateTime: reviewDateTime),
            rating: rating,
          );
          card.difficulty = _nextDifficulty(
            difficulty: card.difficulty!,
            rating: rating,
          );
        }

        // calculate the card's next interval
        // ts-fsrs `BasicLearningStepsStrategy` returns {} (graduating the card
        // to Review for any grade) when there are no steps or the current step
        // is exhausted — this also covers cards previously scheduled with a
        // Scheduler with more learningSteps than the current one.
        if (learningSteps.isEmpty || card.step! >= learningSteps.length) {
          card.state = State.review;
          card.step = null;

          final nextIntervalDays = _getFuzzedInterval(
            _nextInterval(stability: card.stability!),
            daysSinceLastReview ?? 0,
          );
          nextInterval = Duration(days: nextIntervalDays);
        } else {
          switch (rating) {
            case Rating.again:
              card.step = 0;
              nextInterval = learningSteps[card.step!];

            case Rating.hard:
              // Independent of the current step (see _hardStepInterval).
              nextInterval = _hardStepInterval(learningSteps);

            case Rating.good:
              if (card.step! + 1 == learningSteps.length) {
                // the last step
                card.state = State.review;
                card.step = null;

                final nextIntervalDays = _getFuzzedInterval(
                  _nextInterval(stability: card.stability!),
                  daysSinceLastReview ?? 0,
                );
                nextInterval = Duration(days: nextIntervalDays);
              } else {
                card.step = card.step! + 1;
                nextInterval = learningSteps[card.step!];
              }
              break;

            case Rating.easy:
              card.state = State.review;
              card.step = null;

              final nextIntervalDays = _getFuzzedInterval(
                _nextInterval(stability: card.stability!),
                daysSinceLastReview ?? 0,
              );
              nextInterval = Duration(days: nextIntervalDays);
              break;
          }
        }
        break;

      case State.review:
        // ts-fsrs `BasicScheduler.reviewState()` computes stability for every
        // grade with a shared retrievability, then interlocks the fuzzed
        // intervals: hard = min(I_hard, I_good), good = max(I_good, hard + 1),
        // easy = max(I_easy, good + 1).
        final shortTerm = daysSinceLastReview != null && daysSinceLastReview < 1;
        // Capture the pre-review stability/difficulty: every grade's stability
        // derives from these, so they must not see the mutations below.
        final baseStability = card.stability!;
        final baseDifficulty = card.difficulty!;
        // Retrievability is the same for every grade; compute it once instead
        // of once per stabilityFor call.
        final retrievability = shortTerm
            ? double.nan
            : getCardRetrievability(card, currentDateTime: reviewDateTime);
        // Memoize per grade: only the grades a branch actually needs are
        // computed, and each at most once.
        final stabilityCache = <Rating, double>{};
        double stabilityFor(Rating r) => stabilityCache.putIfAbsent(
              r,
              () => shortTerm
                  ? _shortTermStability(stability: baseStability, rating: r)
                  : _nextStability(
                      difficulty: baseDifficulty,
                      stability: baseStability,
                      retrievability: retrievability,
                      rating: r,
                    ),
            );

        final elapsedDays = daysSinceLastReview ?? 0;

        card.stability = stabilityFor(rating);

        card.difficulty = _nextDifficulty(
          difficulty: card.difficulty!,
          rating: rating,
        );

        // calculate the card's next interval (fuzz included)
        switch (rating) {
          case Rating.again:
            // if there are no relearning steps (they were left blank) the
            // card stays in the Review state
            if (relearningSteps.isEmpty) {
              final nextIntervalDays = _getFuzzedInterval(
                _nextInterval(stability: stabilityFor(Rating.again)),
                elapsedDays,
              );
              nextInterval = Duration(days: nextIntervalDays);
            } else {
              card.state = State.relearning;
              card.step = 0;
              nextInterval = relearningSteps[card.step!];
            }

          case Rating.hard:
            final hardInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.hard)),
              elapsedDays,
            );
            final goodInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.good)),
              elapsedDays,
            );
            nextInterval = Duration(days: math.min(hardInterval, goodInterval));

          case Rating.good:
            final hardInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.hard)),
              elapsedDays,
            );
            final goodInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.good)),
              elapsedDays,
            );
            nextInterval = Duration(
              days: math.max(
                goodInterval,
                math.min(hardInterval, goodInterval) + 1,
              ),
            );

          case Rating.easy:
            final hardInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.hard)),
              elapsedDays,
            );
            final goodInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.good)),
              elapsedDays,
            );
            final easyInterval = _getFuzzedInterval(
              _nextInterval(stability: stabilityFor(Rating.easy)),
              elapsedDays,
            );
            final goodMax = math.max(
              goodInterval,
              math.min(hardInterval, goodInterval) + 1,
            );
            nextInterval = Duration(days: math.max(easyInterval, goodMax + 1));
        }

      case State.relearning:
        // A card constructed directly in the relearning state has no step;
        // default it like the learning path does (the Card constructor only
        // defaults step for learning).
        card.step ??= 0;

        // update the card's stability and difficulty
        if (daysSinceLastReview != null && daysSinceLastReview < 1) {
          card.stability = _shortTermStability(
            stability: card.stability!,
            rating: rating,
          );
          card.difficulty = _nextDifficulty(
            difficulty: card.difficulty!,
            rating: rating,
          );
        } else {
          card.stability = _nextStability(
            difficulty: card.difficulty!,
            stability: card.stability!,
            retrievability:
                getCardRetrievability(card, currentDateTime: reviewDateTime),
            rating: rating,
          );
          card.difficulty = _nextDifficulty(
            difficulty: card.difficulty!,
            rating: rating,
          );
        }

        // calculate the card's next interval
        // ts-fsrs `BasicLearningStepsStrategy` returns {} (graduating the card
        // to Review for any grade) when there are no steps or the current step
        // is exhausted — this also covers cards previously scheduled with a
        // Scheduler with more relearningSteps than the current one.
        if (relearningSteps.isEmpty || card.step! >= relearningSteps.length) {
          card.state = State.review;
          card.step = null;

          final nextIntervalDays = _getFuzzedInterval(
            _nextInterval(stability: card.stability!),
            daysSinceLastReview ?? 0,
          );
          nextInterval = Duration(days: nextIntervalDays);
        } else {
          switch (rating) {
            case Rating.again:
              card.step = 0;
              nextInterval = relearningSteps[card.step!];

            case Rating.hard:
              // Independent of the current step (see _hardStepInterval).
              nextInterval = _hardStepInterval(relearningSteps);

            case Rating.good:
              if (card.step! + 1 == relearningSteps.length) {
                // the last step
                card.state = State.review;
                card.step = null;

                final nextIntervalDays = _getFuzzedInterval(
                  _nextInterval(stability: card.stability!),
                  daysSinceLastReview ?? 0,
                );
                nextInterval = Duration(days: nextIntervalDays);
              } else {
                card.step = card.step! + 1;
                nextInterval = relearningSteps[card.step!];
              }

            case Rating.easy:
              card.state = State.review;
              card.step = null;

              final nextIntervalDays = _getFuzzedInterval(
                _nextInterval(stability: card.stability!),
                daysSinceLastReview ?? 0,
              );
              nextInterval = Duration(days: nextIntervalDays);
          }
        }
    }

    card.due = reviewDateTime.add(nextInterval);
    card.lastReview = reviewDateTime;
    card.elapsedDays = daysSinceLastReview ?? 0;
    card.scheduledDays = nextInterval.inDays;
    card.reps += 1;
    if (rating == Rating.again && wasReview) {
      card.lapses += 1;
    }

    final reviewLog = ReviewLog(
      cardId: card.cardId,
      rating: rating,
      reviewDateTime: reviewDateTime,
      reviewDuration: reviewDuration,
    );

    return (card: card, reviewLog: reviewLog);
  }

  /// Returns a JSON-serializable Map representation of the Scheduler object.
  ///
  /// This method is specifically useful for storing Scheduler objects in a database.
  Map<String, dynamic> toMap() {
    return {
      'parameters': parameters,
      'desiredRetention': desiredRetention,
      'learningSteps': learningSteps.map((step) => step.inSeconds).toList(),
      'relearningSteps': relearningSteps.map((step) => step.inSeconds).toList(),
      'maximumInterval': maximumInterval,
      'enableFuzzing': enableFuzzing,
    };
  }

  /// {@macro fsrs.scheduler}
  ///
  /// Creates a Scheduler object from an existing Map.
  static Scheduler fromMap(Map<String, dynamic> sourceMap) {
    return Scheduler(
      parameters: List<double>.from(sourceMap['parameters']),
      desiredRetention: sourceMap['desiredRetention'] as double,
      learningSteps: (sourceMap['learningSteps'] as List)
          .map((step) => Duration(seconds: step as int))
          .toList(),
      relearningSteps: (sourceMap['relearningSteps'] as List)
          .map((step) => Duration(seconds: step as int))
          .toList(),
      maximumInterval: sourceMap['maximumInterval'] as int,
      enableFuzzing: sourceMap['enableFuzzing'] as bool,
    );
  }

  double _clampDifficulty(double difficulty) {
    return difficulty.clamp(minDifficulty, maxDifficulty);
  }

  double _clampStability(double stability) {
    return math.max(math.min(stability, stabilityMax), stabilityMin);
  }

  double _initialStability(Rating rating) {
    // ts-fsrs init_stability(): max(w[g-1], 0.1).
    return math.max(parameters[rating.value - 1], 0.1);
  }

  double _initialDifficulty(Rating rating) {
    // ts-fsrs init_difficulty(): rounded to 8 decimals, clamped by callers.
    return _roundTo8(
        parameters[4] - math.exp(parameters[5] * (rating.value - 1)) + 1);
  }

  int _nextInterval({required double stability}) {
    // ts-fsrs `next_interval()`: round(stability * intervalModifier), with a
    // minimum of 1 day and capped at the maximum interval.
    num nextInterval = stability * _intervalModifier;

    nextInterval = nextInterval.round(); // intervals are full days

    // must be at least 1 day long
    nextInterval = math.max(nextInterval, 1);

    // can not be longer than the maximum interval
    nextInterval = math.min(nextInterval, maximumInterval);

    return nextInterval.toInt();
  }

  double _shortTermStability(
      {required double stability, required Rating rating}) {
    final sinc =
        math.exp(parameters[17] * (rating.value - 3 + parameters[18])) *
            math.pow(stability, -parameters[19]);

    // ts-fsrs next_short_term_stability(): floored at 1.0 for any grade >= Hard.
    final maskedSinc = rating != Rating.again ? math.max(sinc, 1.0) : sinc;

    final shortTermStability = stability * maskedSinc;

    return _roundTo8(math
        .max(math.min(shortTermStability, stabilityMax), stabilityMin)
        .toDouble());
  }

  double _nextDifficulty({required double difficulty, required Rating rating}) {
    double _linearDamping(
        {required double deltaDifficulty, required double difficulty}) {
      // ts-fsrs linear_damping(): roundTo((delta_d * (10 - d)) / 9, 8).
      return _roundTo8((10.0 - difficulty) * deltaDifficulty / 9.0);
    }

    double _meanReversion({required double arg1, required double arg2}) {
      // ts-fsrs mean_reversion(): roundTo(w7 * init + (1 - w7) * current, 8).
      return _roundTo8(parameters[7] * arg1 + (1 - parameters[7]) * arg2);
    }

    final arg1 = _initialDifficulty(Rating.easy);

    final deltaDifficulty = -(parameters[6] * (rating.value - 3));
    final arg2 = difficulty +
        _linearDamping(
            deltaDifficulty: deltaDifficulty, difficulty: difficulty);

    var nextDifficulty = _meanReversion(arg1: arg1, arg2: arg2);

    nextDifficulty = _clampDifficulty(nextDifficulty);

    return nextDifficulty;
  }

  double _nextStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required Rating rating,
  }) {
    double nextStability;

    if (rating == Rating.again) {
      nextStability = _nextForgetStability(
        difficulty: difficulty,
        stability: stability,
        retrievability: retrievability,
      );
    } else {
      nextStability = _nextRecallStability(
        difficulty: difficulty,
        stability: stability,
        retrievability: retrievability,
        rating: rating,
      );
    }

    nextStability = _clampStability(nextStability);

    return nextStability;
  }

  double _nextForgetStability({
    required double difficulty,
    required double stability,
    required double retrievability,
  }) {
    final longTerm = parameters[11] *
        math.pow(difficulty, -parameters[12]) *
        (math.pow((stability + 1), (parameters[13])) - 1) *
        math.exp((1 - retrievability) * parameters[14]);

    // ts-fsrs next_state() (grade 1):
    // s_after_fail = roundTo(clamp(longTerm, S_MIN, 36500), 8), then
    // new_s = clamp(roundTo(s / e^(w17 * w18), 8), S_MIN, s_after_fail).
    final sAfterFail = _roundTo8(
        math.max(math.min(longTerm, stabilityMax), stabilityMin).toDouble());
    final nextSMin =
        _roundTo8(stability / math.exp(parameters[17] * parameters[18]));

    return math.max(math.min(sAfterFail, nextSMin), stabilityMin);
  }

  double _nextRecallStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required Rating rating,
  }) {
    final hardPenalty = rating == Rating.hard ? parameters[15] : 1.0;
    final easyBonus = rating == Rating.easy ? parameters[16] : 1.0;

    final nextStability = stability *
        (1 +
            math.exp(parameters[8]) *
                (11 - difficulty) *
                math.pow(stability, -parameters[9]) *
                (math.exp((1 - retrievability) * parameters[10]) - 1) *
                hardPenalty *
                easyBonus);

    // ts-fsrs next_recall_stability(): roundTo(clamp(..., S_MIN, 36500), 8).
    return _roundTo8(math
        .max(math.min(nextStability, stabilityMax), stabilityMin)
        .toDouble());
  }

  /// Applies the ts-fsrs `apply_fuzz()` to [intervalDays]: a deterministic
  /// draw from `alea(seed)` (or the configured [math.Random]) within the fuzz
  /// range, floored. When the interval is longer than the days elapsed since
  /// the previous review, the lower bound is the day after the previous review.
  ///
  /// Args:
  ///   - intervalDays: The calculated next interval, in days, before fuzzing.
  ///   - elapsedDays: Whole days since the previous review.
  ///
  /// Returns:
  ///   - The new interval, in days, after fuzzing.
  int _getFuzzedInterval(int intervalDays, int elapsedDays) {
    // fuzz is not applied to intervals less than 2.5 days
    if (!enableFuzzing || intervalDays < 2.5) {
      return intervalDays;
    }

    /// Helper function that computes the possible upper and lower bounds of the interval after fuzzing.
    (int minIvL, int maxIvL) getFuzzRange(int intervalDays, int elapsedDays) {
      var delta = 1.0;
      for (final fuzzRange in fuzzRanges) {
        delta += fuzzRange['factor']! *
            math.max(
              math.min(intervalDays, fuzzRange['end']!) - fuzzRange['start']!,
              0.0,
            );
      }

      final ivl = math.min(intervalDays, maximumInterval);
      var minIvL = math.max(2, (ivl - delta).round());
      final maxIvL = math.min((ivl + delta).round(), maximumInterval);

      // make sure the minIvL and maxIvL fall into a valid range
      if (ivl > elapsedDays) {
        minIvL = math.max(minIvL, elapsedDays + 1);
      }
      minIvL = math.min(minIvL, maxIvL);

      return (minIvL, maxIvL);
    }

    final (minIvL, maxIvL) = getFuzzRange(intervalDays, elapsedDays);

    // ts-fsrs `apply_fuzz()` re-seeds alea(seed) on every call, so all
    // intervals computed within one review share the same fuzz factor.
    final fuzzFactor = _fuzzRandom != null
        ? _fuzzRandom!.nextDouble()
        : _Alea(_fuzzSeed!).next();

    final fuzzedIntervalDays =
        (fuzzFactor * (maxIvL - minIvL + 1) + minIvL).floor();

    return fuzzedIntervalDays;
  }
}

// Dart's Utils section
// This section contains utility functions that are not part of the main
// repository

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Rounds to 8 decimal places, matching ts-fsrs `roundTo(x, 8)`.
double _roundTo8(double value) => (value * 1e8).roundToDouble() / 1e8;

/// Whole calendar days from [from] to [to] computed in UTC, matching ts-fsrs
/// `dateDiffInDays()` (Math.floor of the UTC day difference).
int _daysBetween(DateTime from, DateTime to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  final diffMs = toUtc.difference(fromUtc).inMilliseconds;
  return (diffMs / Duration.millisecondsPerDay).floor();
}

/// ts-fsrs Hard interval for a learning/relearning step: round(first * 1.5)
/// with one step, else round((first + second) / 2), rounded to whole minutes.
/// Computed in fractional minutes (via microseconds) so sub-minute steps keep
/// their precision instead of truncating to 0 as `Duration.inMinutes` would.
Duration _hardStepInterval(List<Duration> steps) {
  double minutes(Duration d) =>
      d.inMicroseconds / Duration.microsecondsPerMinute;
  final m = steps.length == 1
      ? minutes(steps[0]) * 1.5
      : (minutes(steps[0]) + minutes(steps[1])) / 2;
  return Duration(minutes: m.round());
}

/// JavaScript-compatible unsigned 32-bit truncation (`x >>> 0`).
double _toUint32(double value) => (value.truncate() % 4294967296).toDouble();

/// JavaScript-compatible signed 32-bit truncation (`x | 0`).
double _toInt32(double value) {
  final unsigned = value.truncate() % 4294967296;
  return unsigned >= 2147483648
      ? (unsigned - 4294967296).toDouble()
      : unsigned.toDouble();
}

/// Port of the `Mash` closure from ts-fsrs `alea.ts`.
class _Mash {
  double _n = 0xefc8249d;

  /// Returns a float in [0, 1), mutating [_n] like the JavaScript original.
  double mash(String data) {
    for (var i = 0; i < data.length; i++) {
      _n += data.codeUnitAt(i).toDouble();
      var h = 0.02519603282416938 * _n;
      _n = _toUint32(h);
      h -= _n;
      h *= _n;
      _n = _toUint32(h);
      h -= _n;
      _n += h * 0x100000000; // 2^32
    }
    return _toUint32(_n) * 2.3283064365386963e-10; // 2^-32
  }
}

/// Port of the `Alea` PRNG from ts-fsrs `alea.ts`.
class _Alea {
  late double _c;
  late double _s0;
  late double _s1;
  late double _s2;

  _Alea(String seed) {
    final mash = _Mash();
    _c = 1;
    _s0 = mash.mash(' ');
    _s1 = mash.mash(' ');
    _s2 = mash.mash(' ');
    _s0 -= mash.mash(seed);
    if (_s0 < 0) _s0 += 1;
    _s1 -= mash.mash(seed);
    if (_s1 < 0) _s1 += 1;
    _s2 -= mash.mash(seed);
    if (_s2 < 0) _s2 += 1;
  }

  double next() {
    final t = 2091639 * _s0 + _c * 2.3283064365386963e-10; // 2^-32
    _s0 = _s1;
    _s1 = _s2;
    _c = _toInt32(t);
    _s2 = t - _c;
    return _s2;
  }
}

/// Formats [value] like JavaScript's `String(number)`: integer-valued doubles
/// (including `-0.0`) print without a trailing `.0`.
String _jsNumberString(double value) {
  if (value == value.truncateToDouble()) {
    return value.truncate().toString();
  }
  return value.toString();
}
