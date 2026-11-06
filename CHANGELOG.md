## 3.0.0

- **Breaking:** default scheduler is now FSRS-7 (ts-fsrs v6.0.0 parity).
  - New `FSRSVersion` enum (`fsrs7` default, `fsrs6` legacy) and
    `Scheduler(version:)` parameter; the FSRS-6 path stays frozen at
    ts-fsrs 5.4.2 parity.
  - New `fsrs7DefaultParameters` (34 weights) becomes `defaultParameters`;
    the previous 21-weight set is exported as `fsrs6DefaultParameters`.
  - `Card` gains `stabilityFast` (the FSRS-7 fast memory trace);
    `elapsedDays` and `scheduledDays` become `double` (FSRS-7 keeps
    fractional 24-hour days).
  - FSRS-7 constructor validates `desiredRetention` to `(0, 1)` and clips
    the 34 weights into model bounds (including cross-parameter
    monotonicity) in place; non-finite weights are rejected.
  - `Scheduler.toMap` now stores `version`, `graduatingInterval`, and
    `allowModelOverride`; `Scheduler.fromMap` infers the version from the
    weight count for older maps and defaults the new keys.
  - `defaultParameters` aliasing `fsrs7DefaultParameters` means code that
    passed the old 21 weights to a default `Scheduler` must pin
    `version: FSRSVersion.fsrs6`.
- Add FSRS-7 scheduling pipeline: dual-trace forgetting curve, fractional
  elapsed days, learning steps with `allowModelOverride`, second-rounded
  step intervals, `graduatingInterval`, monotonic interlock, deterministic
  FNV-1a/Mulberry32 fuzzing, and maximum-interval capping.
- Add `stepFSRS7` and `nextIntervalFSRS7` for direct model access
  (FSRS-7-only; they throw `StateError` on an FSRS-6 scheduler).
- Bump version to 3.0.0.

## 2.1.0

- Add `State.newCard` (value `0`) to match ts-fsrs `State.New`.
- Track `reps`, `lapses`, `elapsedDays`, and `scheduledDays` on `Card`, updated in `reviewCard` to mirror ts-fsrs Card counters (needed for server `scheduler_state` round-trips).
- Match ts-fsrs 5.4.2 (FSRS-6) scheduling behavior:
  - Use the FSRS-6 default weights (21) with `w[20]` as the decay, and round
    the factor, interval modifier, stability, and difficulty to 8 decimals
    like ts-fsrs.
  - Compute elapsed time as whole calendar days in UTC (ts-fsrs
    `dateDiffInDays`), so the "same day" rule and `elapsedDays` match.
  - Learning/relearning steps: Hard is `round(first * 1.5)` with one step and
    `round((first + second) / 2)` with several; any grade graduates the card
    to Review when the steps are exhausted; Easy always graduates.
  - Review-state intervals use the ts-fsrs interlock
    (`hard <= good <= easy`, each at least one day apart) applied after each
    interval is clamped to `maximumInterval`.
  - Apply the short-term stability formula only for same-day reviews
    (elapsed 0), floored at 1.0 for Hard/Good/Easy, and cap forgetting
    stability at `S / e^(w17 * w18)`.
  - Fuzzing: now off by default (`enableFuzzing: false`, ts-fsrs
    `default_enable_fuzz`); re-seeds the ts-fsrs `alea(seed)` PRNG for each
    review, floors the fuzz draw, and lifts the lower bound to
    `elapsed_days + 1` when the interval exceeds the elapsed days.
- Accept and migrate FSRSv4 (17) and FSRSv5 (19) weight arrays to FSRSv6
  (21) instead of throwing (ts-fsrs `migrateParameters`); other lengths
  still throw.
- Bump dev dependency `lints` from `^4.0.0` to `^6.1.0`.

## 2.0.1

- fix: #24 compatability with flutter_test from sdk

## 2.0.0

- FSRS-6

## 1.1.1

- Add support json function on Card class

## 1.1.0

- Fix coding standard.
- Fix dart score analyzed
- Improve documentation

## 1.0.0

- Initial version.
