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
