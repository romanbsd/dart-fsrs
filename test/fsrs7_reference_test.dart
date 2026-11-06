// FSRS-7 parity against ts-fsrs v6.0.0 (fsrs-rs c9562d6 / srs-benchmark b4b0254
// goldens, float32 reference values; Dart evaluates in float64).
//
// Tolerances mirror model.spec.ts:
//   states:   max(1e-7, |expected| * 1e-4)
//   intervals: max(1e-8, |interval| * 2e-3)
//   curve:    closeTo(..., 5)

import 'dart:math';

import 'package:fsrs/fsrs.dart';
import 'package:test/test.dart';

void main() {
  group('FSRS-7 reference histories', () {
    test('history 0 replays every memory state', () {
      final history = <({double deltaT, Rating rating})>[
        (deltaT: 0.0, rating: Rating.values[0]),
        (deltaT: 0.0, rating: Rating.values[2]),
        (deltaT: 1.0, rating: Rating.values[2]),
        (deltaT: 3.0, rating: Rating.values[2]),
        (deltaT: 8.0, rating: Rating.values[2]),
        (deltaT: 21.0, rating: Rating.values[2]),
      ];
      final expected =
          <({double stability, double stabilityFast, double difficulty})>[
        (stability: 0.1104, stabilityFast: 0.08832, difficulty: 6.1686),
        (stability: 0.11041191, stabilityFast: 0.08832, difficulty: 6.109214),
        (
          stability: 0.91686124,
          stabilityFast: 44.444206,
          difficulty: 6.0504217
        ),
        (stability: 3.5337858, stabilityFast: 193.5973, difficulty: 5.9922175),
        (stability: 10.186002, stabilityFast: 407.62646, difficulty: 5.934595),
        (stability: 25.985723, stabilityFast: 700.5589, difficulty: 5.877549),
      ];
      final benchmark =
          <({double stability, double stabilityFast, double difficulty})>[
        (
          stability: 0.1103999987244606,
          stabilityFast: 0.08832000195980072,
          difficulty: 6.168600082397461
        ),
        (
          stability: 0.11041191220283508,
          stabilityFast: 0.08832000195980072,
          difficulty: 6.109213829040527
        ),
        (
          stability: 0.9168612360954285,
          stabilityFast: 44.44420623779297,
          difficulty: 6.050421714782715
        ),
        (
          stability: 3.533785820007324,
          stabilityFast: 193.59730529785156,
          difficulty: 5.992217540740967
        ),
        (
          stability: 10.186001777648926,
          stabilityFast: 407.62646484375,
          difficulty: 5.934595108032227
        ),
        (
          stability: 25.985713958740234,
          stabilityFast: 700.5588989257812,
          difficulty: 5.877549171447754
        ),
      ];
      final scheduler = Scheduler();
      var state = scheduler.stepFSRS7(
        elapsedDays: history.first.deltaT,
        rating: history.first.rating,
      );
      expectState(state, expected[0]);
      expectState(state, benchmark[0]);
      for (var i = 1; i < history.length; i++) {
        state = scheduler.stepFSRS7(
          stability: state.stability,
          stabilityFast: state.stabilityFast,
          difficulty: state.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
        expectState(state, expected[i]);
        expectState(state, benchmark[i]);
      }
      // Splitting the history in half must not change the first states.
      final split = history.length ~/ 2;
      var half = scheduler.stepFSRS7(
        elapsedDays: history.first.deltaT,
        rating: history.first.rating,
      );
      for (var i = 1; i < split; i++) {
        half = scheduler.stepFSRS7(
          stability: half.stability,
          stabilityFast: half.stabilityFast,
          difficulty: half.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
      }
      expectState(half, expected[split - 1]);
    });

    test('history 1 replays every memory state', () {
      final history = <({double deltaT, Rating rating})>[
        (deltaT: 0.0, rating: Rating.values[0]),
        (deltaT: 0.99791664, rating: Rating.values[0]),
        (deltaT: 0.82361114, rating: Rating.values[0]),
        (deltaT: 1.0388889, rating: Rating.values[0]),
        (deltaT: 0.0013888889, rating: Rating.values[2]),
        (deltaT: 0.0020833334, rating: Rating.values[2]),
        (deltaT: 0.0020833334, rating: Rating.values[2]),
        (deltaT: 0.0027777778, rating: Rating.values[2]),
      ];
      final expected =
          <({double stability, double stabilityFast, double difficulty})>[
        (stability: 0.1104, stabilityFast: 0.08832, difficulty: 6.1686),
        (
          stability: 0.06706447,
          stabilityFast: 0.016565936,
          difficulty: 8.047908
        ),
        (
          stability: 0.04536918,
          stabilityFast: 0.0034119464,
          difficulty: 8.764432
        ),
        (
          stability: 0.0329967,
          stabilityFast: 0.00074974925,
          difficulty: 9.098293
        ),
        (stability: 0.14780034, stabilityFast: 2.8802187, difficulty: 9.009611),
        (stability: 0.24254547, stabilityFast: 7.019944, difficulty: 8.921815),
        (stability: 0.3307042, stabilityFast: 10.166433, difficulty: 8.834897),
        (stability: 0.4365655, stabilityFast: 13.619719, difficulty: 8.748848),
      ];
      final benchmark =
          <({double stability, double stabilityFast, double difficulty})>[
        (
          stability: 0.1103999987244606,
          stabilityFast: 0.08832000195980072,
          difficulty: 6.168600082397461
        ),
        (
          stability: 0.06706447154283524,
          stabilityFast: 0.01656593568623066,
          difficulty: 8.047908782958984
        ),
        (
          stability: 0.04536918178200722,
          stabilityFast: 0.003411946352571249,
          difficulty: 8.764432907104492
        ),
        (
          stability: 0.03299669921398163,
          stabilityFast: 0.0007497492479160428,
          difficulty: 9.098294258117676
        ),
        (
          stability: 0.1478002816438675,
          stabilityFast: 2.8802170753479004,
          difficulty: 9.009612083435059
        ),
        (
          stability: 0.24254533648490906,
          stabilityFast: 7.019941329956055,
          difficulty: 8.921815872192383
        ),
        (
          stability: 0.3307039737701416,
          stabilityFast: 10.166431427001953,
          difficulty: 8.834897994995117
        ),
        (
          stability: 0.4365651309490204,
          stabilityFast: 13.61971378326416,
          difficulty: 8.748848915100098
        ),
      ];
      final scheduler = Scheduler();
      var state = scheduler.stepFSRS7(
        elapsedDays: history.first.deltaT,
        rating: history.first.rating,
      );
      expectState(state, expected[0]);
      expectState(state, benchmark[0]);
      for (var i = 1; i < history.length; i++) {
        state = scheduler.stepFSRS7(
          stability: state.stability,
          stabilityFast: state.stabilityFast,
          difficulty: state.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
        expectState(state, expected[i]);
        expectState(state, benchmark[i]);
      }
      // Splitting the history in half must not change the first states.
      final split = history.length ~/ 2;
      var half = scheduler.stepFSRS7(
        elapsedDays: history.first.deltaT,
        rating: history.first.rating,
      );
      for (var i = 1; i < split; i++) {
        half = scheduler.stepFSRS7(
          stability: half.stability,
          stabilityFast: half.stabilityFast,
          difficulty: half.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
      }
      expectState(half, expected[split - 1]);
    });

    test('history 2 replays every memory state', () {
      final history = <({double deltaT, Rating rating})>[
        (deltaT: 0.0, rating: Rating.values[3]),
        (deltaT: 0.001, rating: Rating.values[1]),
        (deltaT: 0.25, rating: Rating.values[0]),
        (deltaT: 0.0, rating: Rating.values[2]),
        (deltaT: 1.5, rating: Rating.values[3]),
        (deltaT: 2.75, rating: Rating.values[1]),
        (deltaT: 100.5, rating: Rating.values[0]),
      ];
      final expected =
          <({double stability, double stabilityFast, double difficulty})>[
        (stability: 11.7841, stabilityFast: 9.427279, difficulty: 1.0),
        (stability: 12.22947, stabilityFast: 13.9512825, difficulty: 4.636193),
        (stability: 2.6588404, stabilityFast: 0.3485167, difficulty: 9.259369),
        (stability: 2.6589437, stabilityFast: 0.3485167, difficulty: 9.169076),
        (stability: 5.028668, stabilityFast: 25.826185, difficulty: 8.743264),
        (stability: 7.37282, stabilityFast: 65.00047, difficulty: 9.166955),
        (stability: 2.3163264, stabilityFast: 0.89478546, difficulty: 9.615685),
      ];
      final benchmark =
          <({double stability, double stabilityFast, double difficulty})>[
        (
          stability: 11.784099578857422,
          stabilityFast: 9.427279472351074,
          difficulty: 1.0
        ),
        (
          stability: 12.229470252990723,
          stabilityFast: 13.951282501220703,
          difficulty: 4.63619327545166
        ),
        (
          stability: 2.6588404178619385,
          stabilityFast: 0.34851670265197754,
          difficulty: 9.259368896484375
        ),
        (
          stability: 2.6589436531066895,
          stabilityFast: 0.34851670265197754,
          difficulty: 9.169075965881348
        ),
        (
          stability: 5.02866792678833,
          stabilityFast: 25.82618522644043,
          difficulty: 8.743264198303223
        ),
        (
          stability: 7.372819900512695,
          stabilityFast: 65.00047302246094,
          difficulty: 9.16695499420166
        ),
        (
          stability: 2.316326379776001,
          stabilityFast: 0.894785463809967,
          difficulty: 9.61568546295166
        ),
      ];
      final scheduler = Scheduler();
      var state = scheduler.stepFSRS7(
        elapsedDays: history.first.deltaT,
        rating: history.first.rating,
      );
      expectState(state, expected[0]);
      expectState(state, benchmark[0]);
      for (var i = 1; i < history.length; i++) {
        state = scheduler.stepFSRS7(
          stability: state.stability,
          stabilityFast: state.stabilityFast,
          difficulty: state.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
        expectState(state, expected[i]);
        expectState(state, benchmark[i]);
      }
      // Splitting the history in half must not change the first states.
      final split = history.length ~/ 2;
      var half = scheduler.stepFSRS7(
        elapsedDays: history.first.deltaT,
        rating: history.first.rating,
      );
      for (var i = 1; i < split; i++) {
        half = scheduler.stepFSRS7(
          stability: half.stability,
          stabilityFast: half.stabilityFast,
          difficulty: half.difficulty,
          elapsedDays: history[i].deltaT,
          rating: history[i].rating,
        );
      }
      expectState(half, expected[split - 1]);
    });
  });

  group('FSRS-7 reference cases', () {
    test('case 0 at elapsedDays=0', () {
      final scheduler = Scheduler();
      const elapsedDays = 0.0;
      // grade 1
      {
        final state = scheduler.stepFSRS7(
          elapsedDays: elapsedDays,
          rating: Rating.values[0],
        );
        expectState(state,
            (stability: 0.1104, stabilityFast: 0.08832, difficulty: 6.1686));
        expectState(state, (
          stability: 0.1103999987244606,
          stabilityFast: 0.08832000195980072,
          difficulty: 6.168600082397461
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.1104,
          stabilityFast: 0.08832,
          difficulty: 6.1686,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.1104,
          stabilityFast: 0.08832,
          difficulty: 6.1686,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(0.05082268, 1.016e-04));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.1104,
          stabilityFast: 0.08832,
          difficulty: 6.1686,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(3.8275626e-05, 7.655e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.1104,
          stabilityFast: 0.08832,
          difficulty: 6.1686,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(1.4600521e-06, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.1104,
          stabilityFast: 0.08832,
          difficulty: 6.1686,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 2
      {
        final state = scheduler.stepFSRS7(
          elapsedDays: elapsedDays,
          rating: Rating.values[1],
        );
        expectState(state, (
          stability: 2.2395,
          stabilityFast: 1.7916001,
          difficulty: 5.261278
        ));
        expectState(state, (
          stability: 2.239500045776367,
          stabilityFast: 1.7916001081466675,
          difficulty: 5.26127815246582
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2395,
          stabilityFast: 1.7916001,
          difficulty: 5.261278,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2395,
          stabilityFast: 1.7916001,
          difficulty: 5.261278,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(128.5822, 2.572e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2395,
          stabilityFast: 1.7916001,
          difficulty: 5.261278,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(0.5974598, 1.195e-03));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2395,
          stabilityFast: 1.7916001,
          difficulty: 5.261278,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.00016643705, 3.329e-07));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2395,
          stabilityFast: 1.7916001,
          difficulty: 5.261278,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 3
      {
        final state = scheduler.stepFSRS7(
          elapsedDays: elapsedDays,
          rating: Rating.values[2],
        );
        expectState(state,
            (stability: 3.9221, stabilityFast: 3.13768, difficulty: 3.5307243));
        expectState(state, (
          stability: 3.922100067138672,
          stabilityFast: 3.1376800537109375,
          difficulty: 3.530724287033081
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 3.9221,
          stabilityFast: 3.13768,
          difficulty: 3.5307243,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 3.9221,
          stabilityFast: 3.13768,
          difficulty: 3.5307243,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(551.4476, 1.103e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 3.9221,
          stabilityFast: 3.13768,
          difficulty: 3.5307243,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(4.7777247, 9.555e-03));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 3.9221,
          stabilityFast: 3.13768,
          difficulty: 3.5307243,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.0006202255, 1.240e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 3.9221,
          stabilityFast: 3.13768,
          difficulty: 3.5307243,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 4
      {
        final state = scheduler.stepFSRS7(
          elapsedDays: elapsedDays,
          rating: Rating.values[3],
        );
        expectState(state,
            (stability: 11.7841, stabilityFast: 9.427279, difficulty: 1.0));
        expectState(state, (
          stability: 11.784099578857422,
          stabilityFast: 9.427279472351074,
          difficulty: 1.0
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 11.7841,
          stabilityFast: 9.427279,
          difficulty: 1.0,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 11.7841,
          stabilityFast: 9.427279,
          difficulty: 1.0,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(4747.62, 9.495e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 11.7841,
          stabilityFast: 9.427279,
          difficulty: 1.0,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(53.869392, 1.077e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 11.7841,
          stabilityFast: 9.427279,
          difficulty: 1.0,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.0160555, 3.211e-05));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 11.7841,
          stabilityFast: 9.427279,
          difficulty: 1.0,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
    });

    test('case 1 at elapsedDays=0', () {
      final scheduler = Scheduler();
      const stability = 10.0, stabilityFast = 8.0, difficulty = 5.0;
      const elapsedDays = 0.0;
      final curve = scheduler.getCardRetrievability(
        Card(
          cardId: 1,
          state: State.review,
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          lastReview: DateTime.utc(2024),
          due: DateTime.utc(2024),
        ),
        currentDateTime: DateTime.utc(2024).add(
          Duration(
              microseconds:
                  (elapsedDays * Duration.microsecondsPerDay).round()),
        ),
      );
      expect(curve, closeTo(0.99999, 1e-5));
      expect(curve, closeTo(0.9999899864196777, 1e-5));
      // grade 1
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[0],
        );
        expectState(state, (
          stability: 2.2577837,
          stabilityFast: 0.100594744,
          difficulty: 9.405907
        ));
        expectState(state, (
          stability: 2.2577836513519287,
          stabilityFast: 0.10059474408626556,
          difficulty: 9.405906677246094
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2577837,
          stabilityFast: 0.100594744,
          difficulty: 9.405907,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2577837,
          stabilityFast: 0.100594744,
          difficulty: 9.405907,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(20.48605, 4.097e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2577837,
          stabilityFast: 0.100594744,
          difficulty: 9.405907,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(0.0018849585, 3.770e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2577837,
          stabilityFast: 0.100594744,
          difficulty: 9.405907,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(4.721809e-06, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.2577837,
          stabilityFast: 0.100594744,
          difficulty: 9.405907,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 2
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[1],
        );
        expectState(state,
            (stability: 10.000857, stabilityFast: 8.0, difficulty: 6.9766846));
        expectState(state, (
          stability: 10.00085735321045,
          stabilityFast: 8.0,
          difficulty: 6.9766845703125
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.000857,
          stabilityFast: 8.0,
          difficulty: 6.9766846,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.000857,
          stabilityFast: 8.0,
          difficulty: 6.9766846,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(684.7744, 1.370e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.000857,
          stabilityFast: 8.0,
          difficulty: 6.9766846,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(6.4759326, 1.295e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.000857,
          stabilityFast: 8.0,
          difficulty: 6.9766846,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.0018957761, 3.792e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.000857,
          stabilityFast: 8.0,
          difficulty: 6.9766846,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 3
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[2],
        );
        expectState(state,
            (stability: 10.00134, stabilityFast: 8.0, difficulty: 4.9522996));
        expectState(state, (
          stability: 10.00133991241455,
          stabilityFast: 8.0,
          difficulty: 4.95229959487915
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 4.9522996,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 4.9522996,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(1267.4237, 2.535e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 4.9522996,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(12.954835, 2.591e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 4.9522996,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.0029926773, 5.985e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 4.9522996,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 4
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[3],
        );
        expectState(state,
            (stability: 10.00134, stabilityFast: 8.0, difficulty: 2.927915));
        expectState(state, (
          stability: 10.00133991241455,
          stabilityFast: 8.0,
          difficulty: 2.927915096282959
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 2.927915,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 2.927915,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(2281.588, 4.563e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 2.927915,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(24.618153, 4.924e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 2.927915,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.005193322, 1.039e-05));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 10.00134,
          stabilityFast: 8.0,
          difficulty: 2.927915,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
    });

    test('case 2 at elapsedDays=0.5', () {
      final scheduler = Scheduler();
      const stability = 10.0, stabilityFast = 8.0, difficulty = 5.0;
      const elapsedDays = 0.5;
      final curve = scheduler.getCardRetrievability(
        Card(
          cardId: 1,
          state: State.review,
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          lastReview: DateTime.utc(2024),
          due: DateTime.utc(2024),
        ),
        currentDateTime: DateTime.utc(2024).add(
          Duration(
              microseconds:
                  (elapsedDays * Duration.microsecondsPerDay).round()),
        ),
      );
      expect(curve, closeTo(0.96410644, 1e-5));
      expect(curve, closeTo(0.9641064405441284, 1e-5));
      // grade 1
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[0],
        );
        expectState(state, (
          stability: 2.3247545,
          stabilityFast: 0.32210514,
          difficulty: 9.260623
        ));
        expectState(state, (
          stability: 2.324754476547241,
          stabilityFast: 0.32210513949394226,
          difficulty: 9.26062297821045
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.3247545,
          stabilityFast: 0.32210514,
          difficulty: 9.260623,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.3247545,
          stabilityFast: 0.32210514,
          difficulty: 9.260623,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(24.85494, 4.971e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.3247545,
          stabilityFast: 0.32210514,
          difficulty: 9.260623,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(0.0075385687, 1.508e-05));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.3247545,
          stabilityFast: 0.32210514,
          difficulty: 9.260623,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(1.6371883e-05, 3.274e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.3247545,
          stabilityFast: 0.32210514,
          difficulty: 9.260623,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 2
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[1],
        );
        expectState(state, (
          stability: 13.15481,
          stabilityFast: 70.479515,
          difficulty: 6.9766846
        ));
        expectState(state, (
          stability: 13.154809951782227,
          stabilityFast: 70.4795150756836,
          difficulty: 6.9766845703125
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 13.15481,
          stabilityFast: 70.479515,
          difficulty: 6.9766846,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 13.15481,
          stabilityFast: 70.479515,
          difficulty: 6.9766846,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(1035.9792, 2.072e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 13.15481,
          stabilityFast: 70.479515,
          difficulty: 6.9766846,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(11.1759, 2.235e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 13.15481,
          stabilityFast: 70.479515,
          difficulty: 6.9766846,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.022712797, 4.543e-05));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 13.15481,
          stabilityFast: 70.479515,
          difficulty: 6.9766846,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 3
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[2],
        );
        expectState(state, (
          stability: 14.930931,
          stabilityFast: 109.39487,
          difficulty: 4.9522996
        ));
        expectState(state, (
          stability: 14.930931091308594,
          stabilityFast: 109.39486694335938,
          difficulty: 4.95229959487915
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 109.39487,
          difficulty: 4.9522996,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 109.39487,
          difficulty: 4.9522996,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(2184.7634, 4.370e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 109.39487,
          difficulty: 4.9522996,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(24.830954, 4.966e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 109.39487,
          difficulty: 4.9522996,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.066923104, 1.338e-04));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 109.39487,
          difficulty: 4.9522996,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 4
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[3],
        );
        expectState(state, (
          stability: 14.930931,
          stabilityFast: 118.20608,
          difficulty: 2.927915
        ));
        expectState(state, (
          stability: 14.930931091308594,
          stabilityFast: 118.2060775756836,
          difficulty: 2.927915096282959
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 118.20608,
          difficulty: 2.927915,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 118.20608,
          difficulty: 2.927915,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(3812.6233, 7.625e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 118.20608,
          difficulty: 2.927915,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(44.30529, 8.861e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 118.20608,
          difficulty: 2.927915,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.135339, 2.707e-04));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 14.930931,
          stabilityFast: 118.20608,
          difficulty: 2.927915,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
    });

    test('case 3 at elapsedDays=21', () {
      final scheduler = Scheduler();
      const stability = 10.0, stabilityFast = 8.0, difficulty = 5.0;
      const elapsedDays = 21.0;
      final curve = scheduler.getCardRetrievability(
        Card(
          cardId: 1,
          state: State.review,
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          lastReview: DateTime.utc(2024),
          due: DateTime.utc(2024),
        ),
        currentDateTime: DateTime.utc(2024).add(
          Duration(
              microseconds:
                  (elapsedDays * Duration.microsecondsPerDay).round()),
        ),
      );
      expect(curve, closeTo(0.8774615, 1e-5));
      expect(curve, closeTo(0.8774614930152893, 1e-5));
      // grade 1
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[0],
        );
        expectState(state, (
          stability: 2.4947672,
          stabilityFast: 0.4401131,
          difficulty: 8.909818
        ));
        expectState(state, (
          stability: 2.494767189025879,
          stabilityFast: 0.4401130974292755,
          difficulty: 8.909817695617676
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.4947672,
          stabilityFast: 0.4401131,
          difficulty: 8.909818,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.4947672,
          stabilityFast: 0.4401131,
          difficulty: 8.909818,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(33.78813, 6.758e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.4947672,
          stabilityFast: 0.4401131,
          difficulty: 8.909818,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(0.018415969, 3.683e-05));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.4947672,
          stabilityFast: 0.4401131,
          difficulty: 8.909818,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(2.4697547e-05, 4.940e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 2.4947672,
          stabilityFast: 0.4401131,
          difficulty: 8.909818,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 2
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[1],
        );
        expectState(state, (
          stability: 21.447685,
          stabilityFast: 133.01303,
          difficulty: 6.9766846
        ));
        expectState(state, (
          stability: 21.44768524169922,
          stabilityFast: 133.01303100585938,
          difficulty: 6.9766845703125
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 21.447685,
          stabilityFast: 133.01303,
          difficulty: 6.9766846,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 21.447685,
          stabilityFast: 133.01303,
          difficulty: 6.9766846,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(1928.8544, 3.858e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 21.447685,
          stabilityFast: 133.01303,
          difficulty: 6.9766846,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(21.950428, 4.390e-02));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 21.447685,
          stabilityFast: 133.01303,
          difficulty: 6.9766846,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.07205106, 1.441e-04));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 21.447685,
          stabilityFast: 133.01303,
          difficulty: 6.9766846,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 3
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[2],
        );
        expectState(state, (
          stability: 27.8926,
          stabilityFast: 210.87737,
          difficulty: 4.9522996
        ));
        expectState(state, (
          stability: 27.89259910583496,
          stabilityFast: 210.8773651123047,
          difficulty: 4.95229959487915
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 210.87737,
          difficulty: 4.9522996,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 210.87737,
          difficulty: 4.9522996,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(4599.419, 9.199e+00));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 210.87737,
          difficulty: 4.9522996,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(54.32485, 1.086e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 210.87737,
          difficulty: 4.9522996,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.2915443, 5.831e-04));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 210.87737,
          difficulty: 4.9522996,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 4
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[3],
        );
        expectState(state, (
          stability: 27.8926,
          stabilityFast: 228.5074,
          difficulty: 2.927915
        ));
        expectState(state, (
          stability: 27.89259910583496,
          stabilityFast: 228.5074005126953,
          difficulty: 2.927915096282959
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 228.5074,
          difficulty: 2.927915,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 228.5074,
          difficulty: 2.927915,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(7835.2026, 1.567e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 228.5074,
          difficulty: 2.927915,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(93.77022, 1.875e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 228.5074,
          difficulty: 2.927915,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.6741429, 1.348e-03));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 27.8926,
          stabilityFast: 228.5074,
          difficulty: 2.927915,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
    });

    test('case 4 at elapsedDays=1.1574074e-05', () {
      final scheduler = Scheduler();
      const stability = 0.0001, stabilityFast = 0.0001, difficulty = 10.0;
      const elapsedDays = 1.1574074e-05;
      final curve = scheduler.getCardRetrievability(
        Card(
          cardId: 1,
          state: State.review,
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          lastReview: DateTime.utc(2024),
          due: DateTime.utc(2024),
        ),
        currentDateTime: DateTime.utc(2024).add(
          Duration(
              microseconds:
                  (elapsedDays * Duration.microsecondsPerDay).round()),
        ),
      );
      expect(curve, closeTo(0.34352458, 1e-5));
      expect(curve, closeTo(0.3435245752334595, 1e-5));
      // grade 1
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[0],
        );
        expectState(state,
            (stability: 0.0001, stabilityFast: 0.0001, difficulty: 9.9023));
        expectState(state, (
          stability: 9.999999747378752e-05,
          stabilityFast: 9.999999747378752e-05,
          difficulty: 9.902299880981445
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0001,
          stabilityFast: 0.0001,
          difficulty: 9.9023,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(0.05710887, 1.142e-04));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0001,
          stabilityFast: 0.0001,
          difficulty: 9.9023,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(1.373549e-07, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0001,
          stabilityFast: 0.0001,
          difficulty: 9.9023,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(8.1039175e-09, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0001,
          stabilityFast: 0.0001,
          difficulty: 9.9023,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(5.47304e-10, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0001,
          stabilityFast: 0.0001,
          difficulty: 9.9023,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 2
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[1],
        );
        expectState(state, (
          stability: 0.0002527925,
          stabilityFast: 0.30059442,
          difficulty: 9.9023
        ));
        expectState(state, (
          stability: 0.00025279249530285597,
          stabilityFast: 0.3005944490432739,
          difficulty: 9.902299880981445
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0002527925,
          stabilityFast: 0.30059442,
          difficulty: 9.9023,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(125.090706, 2.502e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0002527925,
          stabilityFast: 0.30059442,
          difficulty: 9.9023,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(0.00052409014, 1.048e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0002527925,
          stabilityFast: 0.30059442,
          difficulty: 9.9023,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(3.3155135e-05, 6.631e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0002527925,
          stabilityFast: 0.30059442,
          difficulty: 9.9023,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(2.2697163e-06, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0002527925,
          stabilityFast: 0.30059442,
          difficulty: 9.9023,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 3
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[2],
        );
        expectState(state, (
          stability: 0.0003388129,
          stabilityFast: 0.48775733,
          difficulty: 9.9023
        ));
        expectState(state, (
          stability: 0.0003388129116501659,
          stabilityFast: 0.4877573549747467,
          difficulty: 9.902299880981445
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.48775733,
          difficulty: 9.9023,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(211.37048, 4.227e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.48775733,
          difficulty: 9.9023,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(0.00086739927, 1.735e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.48775733,
          difficulty: 9.9023,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(5.4908778e-05, 1.098e-07));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.48775733,
          difficulty: 9.9023,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(3.7600585e-06, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.48775733,
          difficulty: 9.9023,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 4
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[3],
        );
        expectState(state, (
          stability: 0.0003388129,
          stabilityFast: 0.53013474,
          difficulty: 9.9023
        ));
        expectState(state, (
          stability: 0.0003388129116501659,
          stabilityFast: 0.5301347970962524,
          difficulty: 9.902299880981445
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.53013474,
          difficulty: 9.9023,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(228.3057, 4.566e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.53013474,
          difficulty: 9.9023,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(0.00094360433, 1.887e-06));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.53013474,
          difficulty: 9.9023,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(5.9806927e-05, 1.196e-07));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.53013474,
          difficulty: 9.9023,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(4.0970463e-06, 1.000e-08));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 0.0003388129,
          stabilityFast: 0.53013474,
          difficulty: 9.9023,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
    });

    test('case 5 at elapsedDays=36500', () {
      final scheduler = Scheduler();
      const stability = 36500.0, stabilityFast = 0.01, difficulty = 1.0;
      const elapsedDays = 36500.0;
      final curve = scheduler.getCardRetrievability(
        Card(
          cardId: 1,
          state: State.review,
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          lastReview: DateTime.utc(2024),
          due: DateTime.utc(2024),
        ),
        currentDateTime: DateTime.utc(2024).add(
          Duration(
              microseconds:
                  (elapsedDays * Duration.microsecondsPerDay).round()),
        ),
      );
      expect(curve, closeTo(0.973712, 1e-5));
      expect(curve, closeTo(0.9737120270729065, 1e-5));
      // grade 1
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[0],
        );
        expectState(state, (
          stability: 390.85403,
          stabilityFast: 0.0025306938,
          difficulty: 8.817285
        ));
        expectState(state, (
          stability: 390.8540344238281,
          stabilityFast: 0.0025306937750428915,
          difficulty: 8.81728458404541
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 390.85403,
          stabilityFast: 0.0025306938,
          difficulty: 8.817285,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 390.85403,
          stabilityFast: 0.0025306938,
          difficulty: 8.817285,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(30587.924, 6.118e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 390.85403,
          stabilityFast: 0.0025306938,
          difficulty: 8.817285,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(367.7285, 7.355e-01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 390.85403,
          stabilityFast: 0.0025306938,
          difficulty: 8.817285,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(0.50528693, 1.011e-03));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 390.85403,
          stabilityFast: 0.0025306938,
          difficulty: 8.817285,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 2
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[1],
        );
        expectState(state, (
          stability: 36500.0,
          stabilityFast: 48.136513,
          difficulty: 4.636193
        ));
        expectState(state, (
          stability: 36500.0,
          stabilityFast: 48.136512756347656,
          difficulty: 4.63619327545166
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 48.136513,
          difficulty: 4.636193,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 48.136513,
          difficulty: 4.636193,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 48.136513,
          difficulty: 4.636193,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 48.136513,
          difficulty: 4.636193,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(5114.481, 1.023e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 48.136513,
          difficulty: 4.636193,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 3
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[2],
        );
        expectState(state,
            (stability: 36500.0, stabilityFast: 78.11211, difficulty: 1.0));
        expectState(state, (
          stability: 36500.0,
          stabilityFast: 78.11210632324219,
          difficulty: 1.0
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 78.11211,
          difficulty: 1.0,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 78.11211,
          difficulty: 1.0,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 78.11211,
          difficulty: 1.0,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 78.11211,
          difficulty: 1.0,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(12157.432, 2.431e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 78.11211,
          difficulty: 1.0,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
      // grade 4
      {
        final state = scheduler.stepFSRS7(
          stability: stability,
          stabilityFast: stabilityFast,
          difficulty: difficulty,
          elapsedDays: elapsedDays,
          rating: Rating.values[3],
        );
        expectState(state,
            (stability: 36500.0, stabilityFast: 84.89918, difficulty: 1.0));
        expectState(state, (
          stability: 36500.0,
          stabilityFast: 84.89917755126953,
          difficulty: 1.0
        ));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 84.89918,
          difficulty: 1.0,
          desiredRetention: 0.1,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 84.89918,
          difficulty: 1.0,
          desiredRetention: 0.65,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 84.89918,
          difficulty: 1.0,
          desiredRetention: 0.9,
        );
        expect(interval, closeTo(36500.0, 7.300e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 84.89918,
          difficulty: 1.0,
          desiredRetention: 0.99,
        );
        expect(interval, closeTo(12158.069, 2.432e+01));
      }
      {
        final interval = scheduler.nextIntervalFSRS7(
          stability: 36500.0,
          stabilityFast: 84.89918,
          difficulty: 1.0,
          desiredRetention: 0.9999,
        );
        expect(interval, closeTo(0.0, 1.000e-08));
      }
    });
  });
}

void expectState(
  ({double stability, double stabilityFast, double difficulty}) actual,
  ({double stability, double stabilityFast, double difficulty}) expected,
) {
  void check(String key, double actualValue, double expectedValue) {
    expect(
      (actualValue - expectedValue).abs(),
      lessThanOrEqualTo(max(1e-7, expectedValue.abs() * 1e-4)),
      reason: '$key: $actualValue vs $expectedValue',
    );
  }

  check('stability', actual.stability, expected.stability);
  check('stabilityFast', actual.stabilityFast, expected.stabilityFast);
  check('difficulty', actual.difficulty, expected.difficulty);
}
