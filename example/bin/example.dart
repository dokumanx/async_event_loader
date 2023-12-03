import 'package:async_event_loader/async_event_loader.dart';

void main(List<String> arguments) async {
  final events = [
    AsyncEvent(
      order: 1,
      action: () async {
        print('########  1 processing');
      },
      onSuccess: () {
        print('########  1 success');
      },
    ),
    AsyncEvent(
      order: 2,
      action: () async {
        print('########  2 processing');
        throw Exception('error');
      },
      onSuccess: () {
        print('########  2 success');
      },
    ),
    AsyncEvent(
      order: 3,
      action: () async {
        print('########  3 processing');
      },
      onSuccess: () {
        print('########  3 success');
      },
    ),
    AsyncEvent(
      order: 4,
      action: () async {
        print('########  4 processing');
      },
      onSuccess: () {
        print('########  4 success');
      },
    ),
    AsyncEvent(
      order: 5,
      action: () async {
        print('########  5 processing');
      },
      onSuccess: () {
        print('########  5 success');
      },
    ),
  ];

  final loader = AsyncEventLoaderController(
    events: events,
    retryLimit: 2,
    skipOnError: true,
  )..run();

  final subs = loader.eventStatusStream.listen((eventStatus) {
    print(eventStatus);
  });

  subs.onDone(() {
    subs.cancel();
  });
}
