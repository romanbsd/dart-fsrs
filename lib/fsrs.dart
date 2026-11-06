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

/// {@template fsrs.version}
/// The FSRS model version a [Scheduler] runs.
///
/// * [FSRSVersion.fsrs7] — dual-trace FSRS-7 (ts-fsrs v6.0.0 parity); the default.
/// * [FSRSVersion.fsrs6] — legacy FSRS-6 (ts-fsrs 5.4.2 parity), frozen.
/// {@endtemplate}
enum FSRSVersion {
  /// FSRS-6 (21 weights, single-trace).
  fsrs6('FSRS-6'),

  /// FSRS-7 (34 weights, dual-trace fast/slow memory).
  fsrs7('FSRS-7');

  /// {@macro fsrs.version}
  const FSRSVersion(this.label);

  /// The stored label, matching ts-fsrs version strings.
  final String label;
}

/// ts-fsrs v6.0.0 `FSRS7_DEFAULT_WEIGHTS` (34 weights).
const fsrs7DefaultParameters = [
  0.1104,
  2.2395,
  3.9221,
  11.7841,
  6.1686,
  0.6457,
  3.6807,
  1.9795,
  0.0,
  1.3826,
  0.7024,
  0.5999,
  0.8146,
  0.6398,
  1.0,
  1.3207,
  0.6707,
  3.8668,
  0.4416,
  0.0934,
  1.8631,
  0.6162,
  1.0869,
  0.1567,
  0.0801,
  0.2421,
  0.9464,
  0.1433,
  0.7145,
  0.0,
  0.5667,
  0.3734,
  0.5333,
  0.3048,
];

/// Alias of [fsrs7DefaultParameters], the default weight set.
const defaultParameters = fsrs7DefaultParameters;

/// ts-fsrs 5.4.2 `default_w` (FSRS-6); the previous value was the FSRS-5.1 set.
const fsrs6DefaultParameters = [
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

// ---------------------------------------------------------------------------
// FSRS-7 model bounds (ts-fsrs `FSRS7_MODEL_BOUNDS` + `FSRS7ParameterBounds`).
// ---------------------------------------------------------------------------

const _sMin7 = 0.0001;
const _sMax7 = 36500.0;
const _sFastMin7 = 0.0001;
const _sFastMax7 = 36500.0;
const _dMin7 = 1.0;
const _dMax7 = 10.0;

/// `MIN_T = 1 / 86400`: the shortest interval the curve inverter considers.
const _minT7 = 1 / 86400;

/// `DR_MIN`: the lowest desired retention the inverter accepts after clamping.
const _drMin7 = 0.0001;

/// `DR_MAX`: desired retention at or above this yields a zero interval.
const _drMax7 = 0.9999;

/// Fresh box bounds in weight-index order; the clipper also enforces
/// cross-parameter constraints (see [Scheduler._validateParameters7]).
const _fsrs7LowerBounds = [
  _sMin7, // 0
  _sMin7, // 1
  _sMin7, // 2
  _sMin7, // 3
  _dMin7, // 4
  0.001, // 5
  0.1, // 6
  0.0, // 7
  0.0, // 8
  0.3, // 9
  0.01, // 10
  0.1, // 11
  0.0, // 12
  0.0, // 13
  1.0, // 14
  0.0, // 15
  0.0, // 16
  0.5, // 17
  0.001, // 18
  0.001, // 19
  0.0, // 20
  0.0, // 21
  1.0, // 22
  0.01, // 23
  0.01, // 24
  0.2, // 25
  0.5, // 26
  0.01, // 27
  0.1, // 28
  0.0, // 29
  0.1, // 30
  0.0, // 31
  0.0, // 32
  0.0, // 33
];

const _fsrs7UpperBounds = [
  50.0, // 0: INIT_S_MAX / 2
  100.0, // 1
  100.0, // 2
  100.0, // 3
  _dMax7, // 4
  4.0, // 5
  4.0, // 6
  4.0, // 7
  1.2, // 8
  3.0, // 9
  1.5, // 10
  1.0, // 11
  3.5, // 12
  1.0, // 13
  7.0, // 14
  4.0, // 15
  2.0, // 16
  6.0, // 17
  1.5, // 18
  1.0, // 19
  5.0, // 20
  1.0, // 21
  7.0, // 22
  0.25, // 23
  0.95, // 24
  0.85, // 25
  0.99, // 26
  1.0, // 27
  1.0, // 28
  0.9, // 29
  1.1, // 30
  1.0, // 31
  0.6, // 32
  0.6, // 33
];

const stabilityMin = 0.001;
const stabilityMax = 36500.0;

/// An FSRS-7 memory state: both traces plus difficulty.
typedef _State7 = ({double stability, double stabilityFast, double difficulty});

/// Time-independent FSRS-7 curve parameters (ts-fsrs `CurveParameters`).
typedef _CurveParams7 = ({
  double fastDecay,
  double fastScale,
  double decay,
  double scale,
  double weight1,
  double weight2,
  double total,
});
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
  (start: 2.5, end: 7.0, factor: 0.15),
  (start: 7.0, end: 20.0, factor: 0.1),
  (start: 20.0, end: double.infinity, factor: 0.05),
];

/// Default learning steps, matching ts-fsrs `DefaultLearningSteps`.
const _defaultLearningSteps = [Duration(minutes: 1), Duration(minutes: 10)];

/// Default relearning steps, matching ts-fsrs `DefaultRelearningSteps`.
const _defaultRelearningSteps = [Duration(minutes: 10)];

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
  static State fromValue(int value) => State.values.firstWhere(
    (state) => state.value == value,
    orElse: () => throw ArgumentError('Invalid state value: $value'),
  );

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
  static Rating fromValue(int value) => Rating.values.firstWhere(
    (rating) => rating.value == value,
    orElse: () => throw ArgumentError('Invalid rating value: $value'),
  );

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

  /// The fast memory trace of the dual-trace FSRS-7 model (ts-fsrs
  /// `stabilityFast`). Null/absent for FSRS-6 cards and unset FSRS-7 cards.
  double? stabilityFast;

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

  /// Days elapsed since the previous review at the last transition
  /// (ts-fsrs `elapsed_days`). Whole calendar days for FSRS-6; fractional
  /// 24-hour days for FSRS-7.
  double elapsedDays;

  /// Days in the interval scheduled by the last transition
  /// (ts-fsrs `scheduled_days`). Sub-day learning intervals are `0`; FSRS-7
  /// keeps fractional days.
  double scheduledDays;

  /// {@macro fsrs.card}
  Card({
    required this.cardId,
    this.state = State.learning,
    this.step,
    this.stability,
    this.stabilityFast,
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
    double? stabilityFast,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int reps = 0,
    int lapses = 0,
    double elapsedDays = 0,
    double scheduledDays = 0,
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
      stabilityFast: stabilityFast,
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
        'stabilityFast: $stabilityFast, '
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
        other.stabilityFast == stabilityFast &&
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
    return Object.hash(
      cardId,
      state,
      step,
      stability,
      stabilityFast,
      difficulty,
      due,
      lastReview,
      reps,
      lapses,
      elapsedDays,
      scheduledDays,
    );
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
      'stabilityFast': stabilityFast,
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
      stability: (sourceMap['stability'] as num?)?.toDouble(),
      stabilityFast: (sourceMap['stabilityFast'] as num?)?.toDouble(),
      difficulty: (sourceMap['difficulty'] as num?)?.toDouble(),
      due: DateTime.parse(sourceMap['due'] as String),
      lastReview: sourceMap['lastReview'] != null ? DateTime.parse(sourceMap['lastReview'] as String) : null,
      reps: (sourceMap['reps'] as num?)?.toInt() ?? 0,
      lapses: (sourceMap['lapses'] as num?)?.toInt() ?? 0,
      elapsedDays: (sourceMap['elapsedDays'] as num?)?.toDouble() ?? 0,
      scheduledDays: (sourceMap['scheduledDays'] as num?)?.toDouble() ?? 0,
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
    double? stabilityFast,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    double? elapsedDays,
    double? scheduledDays,
  }) {
    return Card(
      cardId: cardId ?? this.cardId,
      state: state ?? this.state,
      step: step ?? this.step,
      stability: stability ?? this.stability,
      stabilityFast: stabilityFast ?? this.stabilityFast,
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
  const ReviewLog({required this.cardId, required this.rating, required this.reviewDateTime, this.reviewDuration});

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
  /// The FSRS model version this scheduler runs.
  final FSRSVersion version;

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

  /// Minimum days for a review card; shorter FSRS-7 intervals stay in
  /// (re)learning. Ignored by the FSRS-6 path.
  final double graduatingInterval;

  /// Whether a longer model interval may replace an explicit learning step
  /// (FSRS-7 only; the FSRS-6 path never replaces steps).
  final bool allowModelOverride;

  late final double _decay;
  late final double _factor;
  late final double _intervalModifier;

  /// Set by [Scheduler.customRandom]; when null, FSRS-6 fuzzing uses the
  /// ts-fsrs `alea` PRNG seeded with [_fuzzSeed] (captured in [reviewCard]).
  /// The FSRS-7 path always uses its own FNV-1a/Mulberry32 seed.
  math.Random? _fuzzRandom;

  /// ts-fsrs `DefaultInitSeedStrategy` seed for the current review (FSRS-6).
  String? _fuzzSeed;

  /// {@macro fsrs.scheduler}
  ///
  /// Defaults to [FSRSVersion.fsrs7]; pass `parameters: null` to use the
  /// default weight set for the selected [version].
  Scheduler({
    FSRSVersion version = FSRSVersion.fsrs7,
    List<double>? parameters,
    this.desiredRetention = 0.9,
    this.learningSteps = _defaultLearningSteps,
    this.relearningSteps = _defaultRelearningSteps,
    this.maximumInterval = 36500,
    // ts-fsrs `default_enable_fuzz` is false.
    this.enableFuzzing = false,
    this.graduatingInterval = 1.0,
    this.allowModelOverride = true,
  }) : version = version,
       parameters = List<double>.from(
         parameters ?? (version == FSRSVersion.fsrs7 ? fsrs7DefaultParameters : fsrs6DefaultParameters),
       ) {
    if (version == FSRSVersion.fsrs7) {
      _validateParameters7(this.parameters);
      _validateRetention7(desiredRetention);
    } else {
      _validateParameters(this.parameters);

      _decay = -this.parameters[20];
      _factor = _roundTo8(_pow(0.9, 1 / _decay) - 1);
      // ts-fsrs `calculate_interval_modifier()`:
      // roundTo((requestRetention^(1/decay) - 1) / factor, 8).
      _intervalModifier = _roundTo8((_pow(desiredRetention, 1 / _decay) - 1) / _factor);
    }
  }

  /// {@macro fsrs.scheduler}
  ///
  /// Creates a Scheduler with custom random number generator.
  ///
  /// This is useful for testing purposes, where you want to control the randomness of the scheduler.
  /// The generator only affects FSRS-6 fuzzing; FSRS-7 fuzzing is always
  /// seeded deterministically from the card id and review count.
  @visibleForTesting
  factory Scheduler.customRandom(
    math.Random random, {
    FSRSVersion version = FSRSVersion.fsrs7,
    List<double>? parameters,
    double desiredRetention = 0.9,
    List<Duration> learningSteps = _defaultLearningSteps,
    List<Duration> relearningSteps = _defaultRelearningSteps,
    int maximumInterval = 36500,
    bool enableFuzzing = false,
    double graduatingInterval = 1.0,
    bool allowModelOverride = true,
  }) {
    final scheduler = Scheduler(
      version: version,
      parameters: parameters,
      desiredRetention: desiredRetention,
      learningSteps: learningSteps,
      relearningSteps: relearningSteps,
      maximumInterval: maximumInterval,
      enableFuzzing: enableFuzzing,
      graduatingInterval: graduatingInterval,
      allowModelOverride: allowModelOverride,
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
      throw ArgumentError('Expected 17, 19 or 21 parameters, got ${parameters.length}.');
    }

    final errorMessages = [
      for (var i = 0; i < parameters.length; i++)
        if (!(lowerBoundsParameters[i] <= parameters[i] && parameters[i] <= upperBoundsParameters[i]))
          'parameters[$i] = ${parameters[i]} is out of bounds: '
              '(${lowerBoundsParameters[i]}, ${upperBoundsParameters[i]})',
    ];

    if (errorMessages.isNotEmpty) {
      throw ArgumentError(
        'One or more parameters are out of bounds:\n'
        '${errorMessages.join('\n')}',
      );
    }
  }

  /// FSRS-7 validation: exactly 34 weights, then a silent in-place
  /// box + cross-parameter clip (ts-fsrs `clipFSRS7Parameters` followed by
  /// `checkFSRS7Parameters`, which passes because the clipper is idempotent).
  ///
  /// Cross-parameter constraints, evaluated in index order over already
  /// clipped values: `w[1..3] >= w[i-1]` and `w[26] >= w[25]`, each at least
  /// its box minimum. Non-finite weights are rejected (the reference clips
  /// them to the low bound, then its identity check fails).
  void _validateParameters7(List<double> parameters) {
    if (parameters.length != fsrs7DefaultParameters.length) {
      throw ArgumentError(
        'Expected ${fsrs7DefaultParameters.length} parameters, '
        'got ${parameters.length}.',
      );
    }
    for (int i = 0; i < parameters.length; i++) {
      if (!parameters[i].isFinite) {
        throw ArgumentError('parameters[$i] must be finite.');
      }
      final low = switch (i) {
        > 0 && < 4 => math.max(_fsrs7LowerBounds[i], parameters[i - 1]),
        26 => math.max(_fsrs7LowerBounds[i], parameters[25]),
        _ => _fsrs7LowerBounds[i],
      };
      parameters[i] = parameters[i].clamp(low, _fsrs7UpperBounds[i]).toDouble();
    }
  }

  /// Rejects a desired retention outside `(0, 1)` for the FSRS-7 model
  /// (shared by the constructor and [nextIntervalFSRS7] overrides).
  void _validateRetention7(double desiredRetention) {
    if (!desiredRetention.isFinite || desiredRetention <= 0 || desiredRetention >= 1) {
      throw ArgumentError.value(desiredRetention, 'desiredRetention', 'must be finite and in (0, 1)');
    }
  }

  /// Migrates FSRSv4 (17) / FSRSv5 (19) weights to FSRSv6 (21), matching
  /// ts-fsrs `migrateParameters()`.
  void _migrateParameters(List<double> parameters) {
    if (parameters.length == 19) {
      parameters.addAll([0.0, 0.5]); // w[19], w[20] = FSRS-5 decay
    } else if (parameters.length == 17) {
      // FSRSv4 → FSRSv6 conversions, applied in ts-fsrs order.
      parameters[4] = _roundTo8(parameters[5] * 2.0 + parameters[4]);
      parameters[5] = _roundTo8(math.log(parameters[5] * 3.0 + 1.0) / 3.0);
      parameters[6] = _roundTo8(parameters[6] + 0.5);
      // w[17..19] default to 0; w[20] = FSRS-5 decay.
      parameters.addAll([0.0, 0.0, 0.0, 0.5]);
    }

    // ts-fsrs `clipParameters()` clamps migrated weights into bounds, so the
    // appended/derived values (e.g. w[19]=0.0 vs lower bound 0.01) don't fail
    // the range check below. Only runs on the migration path.
    for (int i = 0; i < parameters.length; i++) {
      parameters[i] = parameters[i].clamp(lowerBoundsParameters[i], upperBoundsParameters[i]);
    }
  }

  @override
  String toString() {
    return 'Scheduler('
        'version: ${version.label}, '
        'parameters: $parameters, '
        'desiredRetention: $desiredRetention, '
        'learningSteps: $learningSteps, '
        'relearningSteps: $relearningSteps, '
        'maximumInterval: $maximumInterval, '
        'enableFuzzing: $enableFuzzing, '
        'graduatingInterval: $graduatingInterval, '
        'allowModelOverride: $allowModelOverride)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Scheduler &&
        other.version == version &&
        _listEquals(other.parameters, parameters) &&
        other.desiredRetention == desiredRetention &&
        _listEquals(other.learningSteps, learningSteps) &&
        _listEquals(other.relearningSteps, relearningSteps) &&
        other.maximumInterval == maximumInterval &&
        other.enableFuzzing == enableFuzzing &&
        other.graduatingInterval == graduatingInterval &&
        other.allowModelOverride == allowModelOverride;
  }

  @override
  int get hashCode {
    return Object.hash(
      version,
      Object.hashAll(parameters),
      desiredRetention,
      Object.hashAll(learningSteps),
      Object.hashAll(relearningSteps),
      maximumInterval,
      enableFuzzing,
      graduatingInterval,
      allowModelOverride,
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
      return 0.0;
    }

    currentDateTime ??= DateTime.now().toUtc();

    if (version == FSRSVersion.fsrs7) {
      // FSRS-7: fractional 24-hour days since the last review, raw dual-trace
      // curve (no roundTo8), matching ts-fsrs `elapsedUtcDays` + `curve`.
      final elapsedDays = _elapsedDaysSince(card.lastReview!, currentDateTime);
      return _curve7(
        elapsedDays,
        stability: card.stability ?? 0,
        stabilityFast: card.stabilityFast ?? 0,
        difficulty: card.difficulty ?? 0,
      ).retrievability;
    }

    final elapsedDays = math.max(0, _daysBetween(card.lastReview!, currentDateTime));

    return _roundTo8(_pow(1 + _factor * elapsedDays / card.stability!, _decay));
  }

  /// Reviews a card with a given rating at a given time for a specified duration.
  ///
  /// The scheduling path is selected by [version]: [FSRSVersion.fsrs7]
  /// (default) runs the dual-trace FSRS-7 pipeline, [FSRSVersion.fsrs6]
  /// keeps the frozen ts-fsrs 5.4.2 behavior.
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

    // Defensive copy so the caller's Card instance is never mutated.
    card = card.copyWith();

    reviewDateTime ??= DateTime.now().toUtc();

    if (version == FSRSVersion.fsrs7) {
      return _reviewFSRS7(card, rating, reviewDateTime, reviewDuration);
    }
    return _reviewFSRS6(card, rating, reviewDateTime, reviewDuration);
  }

  /// The frozen ts-fsrs 5.4.2 (FSRS-6) review pipeline.
  ({Card card, ReviewLog reviewLog}) _reviewFSRS6(
    Card card,
    Rating rating,
    DateTime reviewDateTime,
    int? reviewDuration,
  ) {
    // ts-fsrs `DefaultInitSeedStrategy` seed, captured before the card is
    // mutated: `${review_time}_${reps}_${difficulty * stability}`.
    _fuzzSeed =
        '${reviewDateTime.millisecondsSinceEpoch}_${card.reps + 1}_'
        '${_jsNumberString((card.difficulty ?? double.nan) * (card.stability ?? double.nan))}';

    final daysSinceLastReview = card.lastReview != null ? _daysBetween(card.lastReview!, reviewDateTime) : null;

    final wasReview = card.state == State.review;
    final elapsedDays = daysSinceLastReview ?? 0;

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
        } else {
          _updateStabilityAndDifficulty(
            card: card,
            rating: rating,
            reviewDateTime: reviewDateTime,
            daysSinceLastReview: daysSinceLastReview,
          );
        }

        nextInterval = _learningStepInterval(learningSteps, card, rating, elapsedDays);
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
        final retrievability = shortTerm ? double.nan : getCardRetrievability(card, currentDateTime: reviewDateTime);
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

        card.stability = stabilityFor(rating);

        card.difficulty = _nextDifficulty(difficulty: card.difficulty!, rating: rating);

        // calculate the card's next interval (fuzz included)
        final intervalCache = <Rating, int>{};
        // Memoized per grade like [stabilityFor]; each branch draws fuzz in
        // the same order as its computations below, keeping seeded
        // random/customRandom behavior unchanged.
        int intervalFor(Rating r) => intervalCache.putIfAbsent(
          r,
          () => _getFuzzedInterval(_nextInterval(stability: stabilityFor(r)), elapsedDays),
        );

        // Interlocked Good interval: Good is at least one day past the
        // Hard/Good minimum after rounding and fuzzing. Shared by the Good and
        // Easy branches; `intervalFor` memoization keeps the fuzz draw order
        // (hard, good, easy) identical to the reference.
        int goodInterlocked() {
          final hardInterval = intervalFor(Rating.hard);
          final goodInterval = intervalFor(Rating.good);
          return math.max(goodInterval, math.min(hardInterval, goodInterval) + 1);
        }

        switch (rating) {
          case Rating.again:
            // if there are no relearning steps (they were left blank) the
            // card stays in the Review state
            if (relearningSteps.isEmpty) {
              nextInterval = Duration(days: intervalFor(Rating.again));
            } else {
              card.state = State.relearning;
              card.step = 0;
              nextInterval = relearningSteps[card.step!];
            }

          case Rating.hard:
            nextInterval = Duration(days: math.min(intervalFor(Rating.hard), intervalFor(Rating.good)));

          case Rating.good:
            nextInterval = Duration(days: goodInterlocked());

          case Rating.easy:
            final goodMax = goodInterlocked();
            final easyInterval = intervalFor(Rating.easy);
            nextInterval = Duration(days: math.max(easyInterval, goodMax + 1));
        }

      case State.relearning:
        // A card constructed directly in the relearning state has no step;
        // _learningStepInterval defaults it like the learning path does (the
        // Card constructor only defaults step for learning).
        _updateStabilityAndDifficulty(
          card: card,
          rating: rating,
          reviewDateTime: reviewDateTime,
          daysSinceLastReview: daysSinceLastReview,
        );

        nextInterval = _learningStepInterval(relearningSteps, card, rating, elapsedDays);
    }

    card.due = reviewDateTime.add(nextInterval);
    card.lastReview = reviewDateTime;
    card.elapsedDays = elapsedDays.toDouble();
    card.scheduledDays = nextInterval.inDays.toDouble();
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

  // -------------------------------------------------------------------------
  // FSRS-7 (ts-fsrs v6.0.0) pipeline.
  //
  // The reference runs the review as a middleware onion with handlers in
  // order desiredRetention, fuzzing, stats, scheduledDays, learningSteps,
  // maximumInterval, monotonicInterval, interleaved [review, nextInterval]
  // per middleware around a base step/interval handler. This port inlines the
  // same chain in the same order:
  //   base step/interval -> monotonic interlock -> maximum cap ->
  //   learning-step restore -> learning-state transition ->
  //   scheduledDays store -> reps/lapses.
  // -------------------------------------------------------------------------

  /// The frozen ts-fsrs v6.0.0 (FSRS-7) review pipeline.
  ({Card card, ReviewLog reviewLog}) _reviewFSRS7(Card card, Rating rating, DateTime now, int? reviewDuration) {
    final entryState = card.state;

    // prepareParsedReview: fractional 24-hour elapsed days since the last
    // review (ts-fsrs `elapsedUtcDays`); New cards start at zero.
    final elapsedDays = entryState == State.newCard ? 0.0 : _elapsedDaysSince(card.lastReview ?? card.due, now);

    // Raw pre-review memory state; all-zero means "not yet initialized".
    final baseState = (
      stability: card.stability ?? 0.0,
      stabilityFast: card.stabilityFast ?? 0.0,
      difficulty: card.difficulty ?? 0.0,
    );

    // Memoized candidate steps: every grade derives from the same base state
    // and prepared retrievability (reference `candidate.step` cache). The
    // time-independent curve params are prepared once for the whole review.
    final baseParams = _prepareCurve7(
      stability: baseState.stability,
      stabilityFast: baseState.stabilityFast,
      difficulty: baseState.difficulty,
    );
    final stepCache = <Rating, _State7>{};
    _State7 stepFor(Rating grade) =>
        stepCache.putIfAbsent(grade, () => _nextState7(baseState, elapsedDays, grade, params: baseParams));

    // Model interval cache (reference `nextInterval` cache), pure in state.
    final intervalCache = <_State7, double>{};
    double modelInterval(_State7 state) => intervalCache.putIfAbsent(
      state,
      () => _nextInterval7(state.stability, state.stabilityFast, state.difficulty, desiredRetention),
    );

    // Fuzzing middleware, installed before the step policy so the policy
    // sees the fuzzed model interval. FSRS-7 draws a single FNV-1a/
    // Mulberry32 factor per review (seed `${cardId}${reps + 1}`), computed
    // once here and shared by every grade's interval in this review.
    final fuzzFactor = enableFuzzing ? _fnv1aMulberry32First('${card.cardId}${card.reps + 1}') : null;
    double fuzzedInterval(_State7 state) {
      final interval = modelInterval(state);
      // Intervals below 2.5 days are kept unfuzzed and fractional
      // (fractionalDays: true for FSRS-7).
      if (fuzzFactor == null || interval < 2.5) return interval;
      final (min: minInterval, max: maxInterval) = _fuzzRange(interval, elapsedDays);
      return (fuzzFactor * (maxInterval - minInterval + 1) + minInterval).floorToDouble();
    }

    // Learning-step resolution (learning-steps middleware), computed once
    // from the pre-review card exactly like the reference.
    final entrySteps = (entryState == State.relearning || entryState == State.review) ? relearningSteps : learningSteps;
    final stepsForGrade = _calculateLearningSteps7(entryState, entrySteps, card.step ?? 0);
    final hasSteps = entrySteps.isNotEmpty;
    // Step intervals in days, from second-rounded minutes; steps rounding to
    // zero are excluded and behave like no step at all.
    final stepIntervals = <Rating, double>{};
    for (final MapEntry(key: grade, value: step) in stepsForGrade.entries) {
      final minutes = (math.max(0.0, step.minutes) * 60).round() / 60;
      if (minutes > 0) stepIntervals[grade] = minutes / 1440;
    }
    final overridden = <Rating>{};

    // The decorated next-interval chain: step policy -> fuzz -> model.
    double intervalFor(Rating grade) {
      final candidateState = stepFor(grade);
      final stepInterval = stepIntervals[grade];
      final double result;
      if (stepInterval == null) {
        // Again without a step follows the model; Hard/Good/Easy without a
        // step graduate at no earlier than the graduating interval when steps
        // are configured, and follow the model when none are.
        final model = fuzzedInterval(candidateState);
        result = grade != Rating.again && hasSteps ? math.max(model, graduatingInterval) : model;
      } else if (grade == Rating.again) {
        // Again may follow the model, but never past graduation.
        result = allowModelOverride
            ? math.max(stepInterval, math.min(fuzzedInterval(candidateState), graduatingInterval))
            : stepInterval;
      } else {
        result = allowModelOverride ? math.max(stepInterval, fuzzedInterval(candidateState)) : stepInterval;
      }
      if (stepInterval != null && result != stepInterval) {
        overridden.add(grade);
      }
      return result;
    }

    // Base handler: step the card, then compute the decorated interval.
    final newState = stepFor(rating);
    var scheduledDays = intervalFor(rating);

    // Monotonic interlock (monotonic-interval middleware): after rounding
    // and fuzzing the current rating keeps an interval no lower rating beat.
    final candidates = <double>[
      if (rating != Rating.again)
        for (final grade in [Rating.again, Rating.hard, Rating.good].take(rating.index)) intervalFor(grade),
      scheduledDays,
    ];
    scheduledDays = _calculateScheduleDay(candidates);

    // Maximum interval cap (maximum-interval middleware), applied before the
    // learning-step restore so explicit steps keep their exact delay.
    scheduledDays = math.min(scheduledDays, maximumInterval.toDouble());

    // Learning-step restore: an explicit step keeps its exact delay unless
    // the model override replaced it (`overridden` records that decision).
    final stepInterval = stepIntervals[rating];
    if (stepInterval != null && !overridden.contains(rating)) {
      scheduledDays = stepInterval;
    }

    // Learning-state transition (learning-steps middleware): intervals below
    // graduation stay in (re)learning, and an Again replaced by the model
    // override always (re)learns.
    final staysLearning = (rating == Rating.again && overridden.contains(rating)) || scheduledDays < graduatingInterval;
    final cardState = staysLearning
        ? switch (entryState) {
            State.newCard => State.learning,
            State.review => State.relearning,
            _ => entryState,
          }
        : State.review;
    // Step of the (re)learning entry: the chosen grade's next step, or 0.
    final cardStep = stepIntervals[rating] != null ? math.max(0, stepsForGrade[rating]!.nextStep) : 0;

    // scheduledDays store (scheduled-days middleware) and stats
    // (stats middleware), then the chronology defaults.
    card.elapsedDays = elapsedDays;
    card.scheduledDays = math.max(0.0, scheduledDays);
    card.reps += 1;
    if (rating == Rating.again && entryState == State.review) {
      card.lapses += 1;
    }
    card.stability = newState.stability;
    card.stabilityFast = newState.stabilityFast;
    card.difficulty = newState.difficulty;
    card.state = cardState;
    card.step = cardState == State.review ? null : cardStep;
    card.lastReview = now;
    // `new Date(now.ms + days * MS_PER_DAY)` truncates to whole
    // milliseconds, keeping sub-day due times exact.
    card.due = DateTime.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch + (card.scheduledDays * Duration.millisecondsPerDay).truncate(),
      isUtc: true,
    );

    return (
      card: card,
      reviewLog: ReviewLog(cardId: card.cardId, rating: rating, reviewDateTime: now, reviewDuration: reviewDuration),
    );
  }

  /// FSRS-7 memory-state step (ts-fsrs `FSRS7Algorithm.next_state`).
  ///
  /// Advances `(stability, stabilityFast, difficulty)` by one review at
  /// [elapsedDays]; retrievability is computed from the state internally.
  /// An all-zero state initializes from the default weights. Requires
  /// `version == FSRSVersion.fsrs7`.
  ({double stability, double stabilityFast, double difficulty}) stepFSRS7({
    double? stability,
    double? stabilityFast,
    double? difficulty,
    required double elapsedDays,
    required Rating rating,
  }) {
    _requireFSRS7('stepFSRS7');
    return _nextState7(
      (stability: stability ?? 0.0, stabilityFast: stabilityFast ?? 0.0, difficulty: difficulty ?? 0.0),
      elapsedDays,
      rating,
    );
  }

  /// FSRS-7 raw fractional-day interval for [desiredRetention] (ts-fsrs
  /// `FSRS7Algorithm.next_interval`): 7 Newton iterations on `log(T)` with a
  /// bisection fallback. Rates >= 0.9999 yield `0`. Requires
  /// `version == FSRSVersion.fsrs7`.
  double nextIntervalFSRS7({
    required double stability,
    required double stabilityFast,
    required double difficulty,
    double? desiredRetention,
  }) {
    _requireFSRS7('nextIntervalFSRS7');
    return _nextInterval7(stability, stabilityFast, difficulty, desiredRetention ?? this.desiredRetention);
  }

  void _requireFSRS7(String method) {
    if (version != FSRSVersion.fsrs7) {
      throw StateError(
        '$method requires version: FSRSVersion.fsrs7 '
        '(scheduler is ${version.label}).',
      );
    }
  }

  /// FSRS-7 forgetting curve: dual-trace retrievability at [elapsedDays].
  ({double retrievability, double derivative}) _curve7(
    double elapsedDays, {
    required double stability,
    required double stabilityFast,
    required double difficulty,
  }) {
    final params = _prepareCurve7(stability: stability, stabilityFast: stabilityFast, difficulty: difficulty);
    return _computeCurve7(elapsedDays, params);
  }

  /// Clamps the state and prepares time-independent curve values once.
  _CurveParams7 _prepareCurve7({required double stability, required double stabilityFast, required double difficulty}) {
    final w = parameters;
    final s = _clamp7(stability, _sMin7, _sMax7);
    final sFast = _clamp7(stabilityFast, _sFastMin7, _sFastMax7);
    final d = _clamp7(difficulty, _dMin7, _dMax7);
    final fast = _prepareFast7(sFast);
    final decay = -_clamp7(w[24], 0.01, 0.95);
    final scale = ((_pow(w[26], 1 / decay) - 1) * _exp((d - 5) * (w[32] - 0.3))) / s;
    final weight1 = w[27] * _pow(sFast, -w[29]);
    final weight2 = w[28] * _pow(s, w[30]) * _exp((d - 5) * (w[31] - 0.5));
    return (
      fastDecay: fast.decay,
      fastScale: fast.scale,
      decay: decay,
      scale: scale,
      weight1: weight1,
      weight2: weight2,
      total: weight1 + weight2,
    );
  }

  /// The fast trace's decay and scale for a given fast stability
  /// (ts-fsrs `prepare_fast`).
  ({double decay, double scale}) _prepareFast7(double sFast) {
    final w = parameters;
    final decay = -_clamp7(w[23] * _pow(sFast, w[33] - 0.3), 0.01, 0.95);
    final scale = (_exp(math.min(math.log(w[25]) / decay, 60)) - 1) / sFast;
    return (decay: decay, scale: scale);
  }

  /// Evaluates the prepared dual-trace curve at [t] days
  /// (ts-fsrs `compute_curve`).
  ({double retrievability, double derivative}) _computeCurve7(double t, _CurveParams7 params) {
    final days = math.max(t, 0.0);
    final fastBase = 1 + params.fastScale * days;
    final fastRecall = _pow(fastBase, params.fastDecay);
    final fastDerivative = params.fastDecay * _pow(fastBase, params.fastDecay - 1) * params.fastScale;
    final base = 1 + params.scale * days;
    final slow = _pow(base, params.decay);
    final slowDerivative = params.decay * _pow(base, params.decay - 1) * params.scale;
    return (
      retrievability: ((params.weight1 * fastRecall + params.weight2 * slow) / params.total) * (1 - 2e-5) + 1e-5,
      derivative: ((params.weight1 * fastDerivative + params.weight2 * slowDerivative) / params.total) * (1 - 2e-5),
    );
  }

  /// Raw fractional days for retention in (0, 1) (ts-fsrs
  /// `FSRS7Algorithm.next_interval`).
  double _nextInterval7(double stability, double stabilityFast, double difficulty, double desiredRetention) {
    _validateRetention7(desiredRetention);
    final target = _clamp7(desiredRetention, _drMin7, _drMax7);
    if (target >= _drMax7) return 0;

    final s = _clamp7(stability, _sMin7, _sMax7);
    final sFast = _clamp7(stabilityFast, _sFastMin7, _sFastMax7);
    final maxStability = math.max(s, sFast);
    final params = _prepareCurve7(stability: stability, stabilityFast: stabilityFast, difficulty: difficulty);
    final logMinT = math.log(_minT7);
    final logSMax = math.log(_sMax7);
    var logT = math.log(maxStability);
    for (var i = 0; i < 7; i++) {
      logT = _clamp7(logT, logMinT, logSMax);
      final t = _clamp7(math.exp(logT), _minT7, _sMax7);
      final curve = _computeCurve7(t, params);
      logT -= _clamp7((curve.retrievability - target) / math.min(curve.derivative * t, -1e-12), -4, 4);
      if (!logT.isFinite) break;
    }
    final interval = _clamp7(math.exp(logT), 0, _sMax7);
    if ((_computeCurve7(interval, params).retrievability - target).abs() <= 1e-3) {
      return interval;
    }

    // Bisection fallback for saturated or unconverged Newton steps.
    var low = 0.0;
    var high = math.min(math.max(maxStability, 1.0), _sMax7);
    while (_computeCurve7(high, params).retrievability > target && high < _sMax7) {
      high = math.min(high * 2, _sMax7);
    }
    for (var i = 0; i < 50; i++) {
      final mid = (low + high) / 2;
      if (_computeCurve7(mid, params).retrievability > target) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  /// One FSRS-7 state transition (ts-fsrs `FSRS7Algorithm.next_state`).
  _State7 _nextState7(_State7 state, double elapsedDays, Rating rating, {_CurveParams7? params}) {
    final w = parameters;
    if (state.stability == 0 && state.stabilityFast == 0 && state.difficulty == 0) {
      // Fresh card: initialize both traces from the weight for this grade.
      final stability = _clamp7(w[rating.value - 1], _sMin7, _sMax7);
      return (
        stability: _clamp7(_roundTo8(stability), _sMin7, _sMax7),
        stabilityFast: _clamp7(_roundTo8(stability * 0.8), _sFastMin7, _sFastMax7),
        difficulty: _clamp7(_roundTo8(_initDifficulty7(rating)), _dMin7, _dMax7),
      );
    }
    if (state.stability <= 0 || state.stabilityFast <= 0) {
      throw ArgumentError('Invalid FSRS7 memory state: both stabilities must be positive');
    }

    final s = _clamp7(state.stability, _sMin7, _sMax7);
    final sFast = _clamp7(state.stabilityFast, _sFastMin7, _sFastMax7);
    final d = _clamp7(state.difficulty, _dMin7, _dMax7);
    // Mixed (slow) retrievability drives the slow trace and difficulty; the
    // fast trace uses its own raw recall curve from the same prepared params.
    final curveParams =
        params ??
        _prepareCurve7(stability: state.stability, stabilityFast: state.stabilityFast, difficulty: state.difficulty);
    final r = _computeCurve7(elapsedDays, curveParams).retrievability;

    final stability = _nextStability7(s: s, d: d, r: r, rating: rating, start: 7);
    var stabilityFast = _nextStability7(
      s: sFast,
      d: d,
      r: _fastRecall7(elapsedDays, curveParams),
      rating: rating,
      start: 15,
    );
    if (rating == Rating.again) {
      stabilityFast = math.min(stabilityFast, stability * 0.8);
    }

    var deltaD = -w[6] * (rating.value - 3);
    if (rating == Rating.again) deltaD *= r + 0.1;
    final difficulty = 0.01 * _initDifficulty7(Rating.easy) + 0.99 * (d + (10 - d) * deltaD / 9);

    return (
      stability: _clamp7(_roundTo8(stability), _sMin7, _sMax7),
      stabilityFast: _clamp7(_roundTo8(stabilityFast), _sFastMin7, _sFastMax7),
      difficulty: _clamp7(_roundTo8(difficulty), _dMin7, _dMax7),
    );
  }

  /// One trace's stability update (ts-fsrs `next_stability`); [start] is 7
  /// for the slow trace and 15 for the fast trace.
  double _nextStability7({
    required double s,
    required double d,
    required double r,
    required Rating rating,
    required int start,
  }) {
    final w = parameters;
    final fail = w[start + 3] * (_pow(s + 1, w[start + 4]) - 1) * _exp((1 - r) * w[start + 5]);
    final pls = math.min(s, fail);
    if (rating == Rating.again) return pls;
    final hardPenalty = rating == Rating.hard ? w[start + 6] : 1.0;
    final easyBonus = rating == Rating.easy ? w[start + 7] : 1.0;
    final increase =
        _exp(w[start] - 1.5) *
            (11 - d) *
            _pow(s, -w[start + 1]) *
            (_exp((1 - r) * w[start + 2]) - 1) *
            hardPenalty *
            easyBonus +
        1;
    return math.max(pls, s * increase);
  }

  /// Raw fast-trace recall at [elapsedDays] (ts-fsrs `fast_component`) from
  /// curve params already prepared for the same state.
  double _fastRecall7(double elapsedDays, _CurveParams7 params) {
    final days = math.max(elapsedDays, 0.0);
    return _pow(1 + params.fastScale * days, params.fastDecay);
  }

  /// Initial difficulty for a grade (ts-fsrs `init_difficulty`).
  double _initDifficulty7(Rating rating) {
    final w = parameters;
    return w[4] - _exp(w[5] * (rating.value - 1)) + 1;
  }

  /// Port of ts-fsrs `calculateLearningSteps`: the grade schedule for the
  /// current (re)learning step. [steps] is the entry step list chosen by the
  /// caller from [state].
  Map<Rating, ({double minutes, int nextStep})> _calculateLearningSteps7(
    State state,
    List<Duration> steps,
    int learningStep,
  ) {
    if (steps.isEmpty || learningStep >= steps.length) return {};
    double minutesOf(Duration step) => step.inMicroseconds / Duration.microsecondsPerMinute;
    final learningUnit = minutesOf(steps[math.max(0, learningStep)]);

    if (state == State.review) {
      // Review cards only map Again onto the first relearning step.
      return {Rating.again: (minutes: learningUnit, nextStep: 0)};
    }

    final first = minutesOf(steps[0]);
    final second = steps.length > 1 ? minutesOf(steps[1]) : null;
    final hard = second == null ? first * 1.5 : (first + second) / 2;
    final result = <Rating, ({double minutes, int nextStep})>{
      Rating.again: (minutes: first, nextStep: 0),
      Rating.hard: (minutes: hard, nextStep: learningStep),
    };
    if (learningStep + 1 < steps.length) {
      // Good advances to the next step; a zero-minute step is skipped.
      final next = minutesOf(steps[learningStep + 1]);
      if (next > 0) {
        result[Rating.good] = (minutes: next, nextStep: learningStep + 1);
      }
    }
    return result;
  }

  /// Port of ts-fsrs `calculateScheduleDay`: keeps the current rating's
  /// interval after every lower rating after rounding and fuzzing.
  double _calculateScheduleDay(List<double> candidates) {
    double? scheduledDay;
    var subDay = candidates.first;
    for (final (index, interval) in candidates.indexed) {
      if (interval >= 1) {
        scheduledDay = math.min(
          scheduledDay == null ? interval : math.max(interval, scheduledDay + 1),
          maximumInterval.toDouble(),
        );
      } else if (scheduledDay == null && index > 0) {
        final raised = math.max(interval, subDay);
        // A rating that is not lower than the previous one moves past it
        // when both land on the same second; a lower rating may share.
        subDay =
            subDay > 0 &&
                _toSeconds7(interval) >= _toSeconds7(candidates[index - 1]) &&
                _toSeconds7(raised) == _toSeconds7(subDay)
            ? subDay + 1 / 86400
            : raised;
      }
    }
    return scheduledDay ?? subDay;
  }

  /// ts-fsrs `getFuzzRange`, shared by both model paths; [elapsedDays] may be
  /// fractional for FSRS-7. Bounds are rounded exactly as the reference does.
  ({double min, double max}) _fuzzRange(double interval, double elapsedDays) {
    var delta = 1.0;
    for (final range in fuzzRanges) {
      delta += range.factor * math.max(math.min(interval, range.end) - range.start, 0.0);
    }
    final capped = math.min(interval, maximumInterval.toDouble());
    var minInterval = math.max(2.0, (capped - delta).roundToDouble());
    final maxInterval = math.min((capped + delta).roundToDouble(), maximumInterval.toDouble());
    if (capped > elapsedDays) {
      minInterval = math.max(minInterval, elapsedDays + 1);
    }
    return (min: math.min(minInterval, maxInterval), max: maxInterval);
  }

  /// Returns a JSON-serializable Map representation of the Scheduler object.
  ///
  /// This method is specifically useful for storing Scheduler objects in a database.
  Map<String, dynamic> toMap() {
    return {
      'version': version.label,
      'parameters': parameters,
      'desiredRetention': desiredRetention,
      'learningSteps': learningSteps.map((step) => step.inSeconds).toList(),
      'relearningSteps': relearningSteps.map((step) => step.inSeconds).toList(),
      'maximumInterval': maximumInterval,
      'enableFuzzing': enableFuzzing,
      'graduatingInterval': graduatingInterval,
      'allowModelOverride': allowModelOverride,
    };
  }

  /// {@macro fsrs.scheduler}
  ///
  /// Creates a Scheduler object from an existing Map.
  ///
  /// When `version` is missing it is inferred from the weight count
  /// (34 weights → [FSRSVersion.fsrs7], otherwise [FSRSVersion.fsrs6]);
  /// missing `graduatingInterval` defaults to `1` and missing
  /// `allowModelOverride` to `true`.
  static Scheduler fromMap(Map<String, dynamic> sourceMap) {
    final rawParameters = (sourceMap['parameters'] as List).map((parameter) => (parameter as num).toDouble()).toList();
    final inferredVersion = rawParameters.length == fsrs7DefaultParameters.length
        ? FSRSVersion.fsrs7
        : FSRSVersion.fsrs6;
    final versionLabel = sourceMap['version'] as String?;
    final version = versionLabel == null
        ? inferredVersion
        : FSRSVersion.values.firstWhere((candidate) => candidate.label == versionLabel, orElse: () => inferredVersion);
    return Scheduler(
      version: version,
      parameters: rawParameters,
      desiredRetention: (sourceMap['desiredRetention'] as num).toDouble(),
      learningSteps: (sourceMap['learningSteps'] as List)
          .map((step) => Duration(seconds: (step as num).toInt()))
          .toList(),
      relearningSteps: (sourceMap['relearningSteps'] as List)
          .map((step) => Duration(seconds: (step as num).toInt()))
          .toList(),
      maximumInterval: (sourceMap['maximumInterval'] as num).toInt(),
      enableFuzzing: sourceMap['enableFuzzing'] as bool,
      graduatingInterval: (sourceMap['graduatingInterval'] as num?)?.toDouble() ?? 1.0,
      allowModelOverride: sourceMap['allowModelOverride'] as bool? ?? true,
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
    return _roundTo8(parameters[4] - _exp(parameters[5] * (rating.value - 1)) + 1);
  }

  int _nextInterval({required double stability}) {
    // ts-fsrs `next_interval()`: round(stability * intervalModifier), with a
    // minimum of 1 day and capped at the maximum interval.
    final days = (stability * _intervalModifier).round();
    return math.min(math.max(days, 1), maximumInterval);
  }

  double _shortTermStability({required double stability, required Rating rating}) {
    final sinc = _exp(parameters[17] * (rating.value - 3 + parameters[18])) * _pow(stability, -parameters[19]);

    // ts-fsrs next_short_term_stability(): floored at 1.0 for any grade >= Hard.
    final maskedSinc = rating != Rating.again ? math.max(sinc, 1.0) : sinc;

    final shortTermStability = stability * maskedSinc;

    return _roundTo8(_clampStability(shortTermStability));
  }

  double _nextDifficulty({required double difficulty, required Rating rating}) {
    double _linearDamping({required double deltaDifficulty, required double difficulty}) {
      // ts-fsrs linear_damping(): roundTo((delta_d * (10 - d)) / 9, 8).
      return _roundTo8((10.0 - difficulty) * deltaDifficulty / 9.0);
    }

    double _meanReversion({required double arg1, required double arg2}) {
      // ts-fsrs mean_reversion(): roundTo(w7 * init + (1 - w7) * current, 8).
      return _roundTo8(parameters[7] * arg1 + (1 - parameters[7]) * arg2);
    }

    final arg1 = _initialDifficulty(Rating.easy);

    final deltaDifficulty = -(parameters[6] * (rating.value - 3));
    final arg2 = difficulty + _linearDamping(deltaDifficulty: deltaDifficulty, difficulty: difficulty);

    return _clampDifficulty(_meanReversion(arg1: arg1, arg2: arg2));
  }

  double _nextStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required Rating rating,
  }) {
    final nextStability = rating == Rating.again
        ? _nextForgetStability(difficulty: difficulty, stability: stability, retrievability: retrievability)
        : _nextRecallStability(
            difficulty: difficulty,
            stability: stability,
            retrievability: retrievability,
            rating: rating,
          );
    return _clampStability(nextStability);
  }

  double _nextForgetStability({required double difficulty, required double stability, required double retrievability}) {
    final longTerm =
        parameters[11] *
        _pow(difficulty, -parameters[12]) *
        (_pow((stability + 1), (parameters[13])) - 1) *
        _exp((1 - retrievability) * parameters[14]);

    // ts-fsrs next_state() (grade 1):
    // s_after_fail = roundTo(clamp(longTerm, S_MIN, 36500), 8), then
    // new_s = clamp(roundTo(s / e^(w17 * w18), 8), S_MIN, s_after_fail).
    final sAfterFail = _roundTo8(_clampStability(longTerm));
    final nextSMin = _roundTo8(stability / _exp(parameters[17] * parameters[18]));

    return _clampStability(math.min(sAfterFail, nextSMin));
  }

  double _nextRecallStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required Rating rating,
  }) {
    final hardPenalty = rating == Rating.hard ? parameters[15] : 1.0;
    final easyBonus = rating == Rating.easy ? parameters[16] : 1.0;

    final nextStability =
        stability *
        (1 +
            _exp(parameters[8]) *
                (11 - difficulty) *
                _pow(stability, -parameters[9]) *
                (_exp((1 - retrievability) * parameters[10]) - 1) *
                hardPenalty *
                easyBonus);

    // ts-fsrs next_recall_stability(): roundTo(clamp(..., S_MIN, 36500), 8).
    return _roundTo8(_clampStability(nextStability));
  }

  /// Sets [card] to the Review state with a `null` step and returns the
  /// fuzzed interval for its current stability.
  Duration _graduateToReview(Card card, int elapsedDays) {
    card.state = State.review;
    card.step = null;

    final nextIntervalDays = _getFuzzedInterval(_nextInterval(stability: card.stability!), elapsedDays);
    return Duration(days: nextIntervalDays);
  }

  /// Returns the next interval for a card within learning/relearning steps,
  /// graduating it to Review when there are no steps or the current step is
  /// exhausted. Matches ts-fsrs `BasicLearningStepsStrategy`, which also
  /// covers cards previously scheduled with a Scheduler that had more steps
  /// than the current one.
  Duration _learningStepInterval(List<Duration> steps, Card card, Rating rating, int elapsedDays) {
    // A card constructed directly in the relearning state has no step,
    // defaulted here like the learning path (the Card constructor only
    // defaults step for learning).
    card.step ??= 0;

    if (steps.isEmpty || card.step! >= steps.length) {
      return _graduateToReview(card, elapsedDays);
    }

    switch (rating) {
      case Rating.again:
        card.step = 0;
        return steps[card.step!];
      case Rating.hard:
        // Independent of the current step (see _hardStepInterval).
        return _hardStepInterval(steps);
      case Rating.good:
        if (card.step! + 1 == steps.length) {
          // the last step
          return _graduateToReview(card, elapsedDays);
        }
        card.step = card.step! + 1;
        return steps[card.step!];
      case Rating.easy:
        return _graduateToReview(card, elapsedDays);
    }
  }

  /// Updates [card]'s stability and difficulty for a review less than a day
  /// after the previous one (short-term) or at least a day after (long-term).
  void _updateStabilityAndDifficulty({
    required Card card,
    required Rating rating,
    required DateTime reviewDateTime,
    required int? daysSinceLastReview,
  }) {
    final shortTerm = daysSinceLastReview != null && daysSinceLastReview < 1;
    card.stability = shortTerm
        ? _shortTermStability(stability: card.stability!, rating: rating)
        : _nextStability(
            difficulty: card.difficulty!,
            stability: card.stability!,
            retrievability: getCardRetrievability(card, currentDateTime: reviewDateTime),
            rating: rating,
          );
    card.difficulty = _nextDifficulty(difficulty: card.difficulty!, rating: rating);
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

    final (min: minIvL, max: maxIvL) = _fuzzRange(intervalDays.toDouble(), elapsedDays.toDouble());

    // ts-fsrs `apply_fuzz()` re-seeds alea(seed) on every call, so all
    // intervals computed within one review share the same fuzz factor.
    final fuzzFactor = _fuzzRandom != null ? _fuzzRandom!.nextDouble() : _Alea(_fuzzSeed!).next();

    return (fuzzFactor * (maxIvL - minIvL + 1) + minIvL).floor();
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

/// `clamp` returning a `double` (ts-fsrs `clamp`).
double _clamp7(num value, num lower, num upper) =>
    value < lower ? lower.toDouble() : (value > upper ? upper.toDouble() : value.toDouble());

/// `Math.pow` as a `double`.
double _pow(num base, num exponent) => math.pow(base, exponent).toDouble();

/// `Math.exp` as a `double`.
double _exp(num value) => math.exp(value).toDouble();

/// Whole seconds in [days], matching ts-fsrs `toSeconds` (`Math.round`).
int _toSeconds7(double days) => (days * 86400).round();

/// Port of ts-fsrs `fnv1aMulberry32Rng`: FNV-1a 32-bit hash feeding
/// Mulberry32, returning the first draw (the fuzz factor for one review).
double _fnv1aMulberry32First(String seed) {
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash = _imul32(hash ^ unit, 0x01000193);
  }

  // Mulberry32 state transition; all arithmetic is mod 2^32, so tracking the
  // state as unsigned bits matches JavaScript's signed intermediates.
  var t = (hash + 0x6d2b79f5) & 0xFFFFFFFF;
  t = _imul32(t ^ (t >> 15), t | 1);
  t ^= (t + _imul32(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
  return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
}

/// 32-bit `Math.imul`: low 32 bits of `x * y`, computed without exceeding
/// 2^53 so the result stays exact on JavaScript-backed Dart too.
int _imul32(int x, int y) {
  x &= 0xFFFFFFFF;
  y &= 0xFFFFFFFF;
  final low = (x & 0xFFFF) * y;
  final high = ((x >> 16) & 0xFFFF) * y;
  return (((high & 0xFFFF) << 16) + low) & 0xFFFFFFFF;
}

/// Whole calendar days from [from] to [to] computed in UTC, matching ts-fsrs
/// `dateDiffInDays()` (Math.floor of the UTC day difference).
int _daysBetween(DateTime from, DateTime to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  final diffMs = toUtc.difference(fromUtc).inMilliseconds;
  return (diffMs / Duration.millisecondsPerDay).floor();
}

/// Fractional 24-hour days from [from] to [to], floored at zero
/// (ts-fsrs `elapsedUtcDays` for FSRS-7).
double _elapsedDaysSince(DateTime from, DateTime to) =>
    math.max(0.0, (to.millisecondsSinceEpoch - from.millisecondsSinceEpoch) / Duration.millisecondsPerDay);

/// ts-fsrs Hard interval for a learning/relearning step: round(first * 1.5)
/// with one step, else round((first + second) / 2), rounded to whole minutes.
/// Computed in fractional minutes (via microseconds) so sub-minute steps keep
/// their precision instead of truncating to 0 as `Duration.inMinutes` would.
Duration _hardStepInterval(List<Duration> steps) {
  double minutes(Duration d) => d.inMicroseconds / Duration.microsecondsPerMinute;
  final m = steps.length == 1 ? minutes(steps[0]) * 1.5 : (minutes(steps[0]) + minutes(steps[1])) / 2;
  return Duration(minutes: m.round());
}

/// JavaScript-compatible unsigned 32-bit truncation (`x >>> 0`).
double _toUint32(double value) => (value.truncate() % 4294967296).toDouble();

/// JavaScript-compatible signed 32-bit truncation (`x | 0`).
double _toInt32(double value) {
  final unsigned = value.truncate() % 4294967296;
  return unsigned >= 2147483648 ? (unsigned - 4294967296).toDouble() : unsigned.toDouble();
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
