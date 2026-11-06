import 'package:fsrs/fsrs.dart';

void main() async {
  // FSRS-7 (default): 34 weights, dual-trace memory, fractional elapsed days.
  // The arguments below are the FSRS-7 defaults; `enableFuzzing` is shown
  // enabled for illustration (the default is false).
  var scheduler = Scheduler(
    desiredRetention: 0.9,
    learningSteps: [
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    relearningSteps: [
      Duration(minutes: 10),
    ],
    maximumInterval: 36500,
    enableFuzzing: true,
  );

  // FSRS-6 (legacy, frozen at ts-fsrs 5.4.2 parity) with its 21 weights:
  // final legacy = Scheduler(version: FSRSVersion.fsrs6);

  final cardInitial = await Card.create();

  // Rating.Again (==1) forgot the card
  // Rating.Hard (==2) remembered the card with serious difficulty
  // Rating.Good (==3) remembered the card after a hesitation
  // Rating.Easy (==4) remembered the card easily

  final rating = Rating.again;

  final (:card, :reviewLog) = scheduler.reviewCard(cardInitial, rating);

  print("Card rated ${reviewLog.rating} at ${reviewLog.reviewDateTime}");

  final due = card.due;

  // how much time between when the card is due and now
  final timeDelta = due.difference(DateTime.now());

  print("Card due on $due");
  print("Card due in ${timeDelta.inSeconds} seconds");

  final retrievability = scheduler.getCardRetrievability(card);

  print("There is a $retrievability probability that this card is remembered.");

  // serialize before storage
  final schedulerDict = scheduler.toMap();
  final cardDict = card.toMap();
  final reviewLogDict = reviewLog.toMap();

  // deserialize from dict
  final newScheduler = Scheduler.fromMap(schedulerDict);
  final newCard = Card.fromMap(cardDict);
  final newReviewLog = ReviewLog.fromMap(reviewLogDict);

  print(
      "Are the original and deserialized schedulers equal? ${scheduler == newScheduler}");
  print("Are the original and deserialized cards equal? ${card == newCard}");
  print(
      "Are the original and deserialized review logs equal? ${reviewLog == newReviewLog}");
}
