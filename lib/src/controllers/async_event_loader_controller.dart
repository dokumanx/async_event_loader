import 'dart:async';

import 'package:async_event_loader/src/enums/async_status.dart';
import 'package:async_event_loader/src/models/async_event.dart';
import 'package:async_event_loader/src/models/event_status.dart';

class AsyncEventLoaderController {
  AsyncEventLoaderController({
    required this.events,
    this.retryLimit = 3,
    this.skipOnError = false,
  }) {
    _eventSubscription = _eventController.stream.listen(_listenToEvents);
    _emitStatus(currentEventStatus.copyWith(total: events.length));
  }

  late final StreamSubscription<AsyncEvent> _eventSubscription;

  AsyncEvent get currentEvent => events[currentEventStatus.completed];

  int _retryCount = 0;

  int get retryCount => _retryCount;

  bool _isDisposed = false; // Flag to track if the controller is disposed

  void run() {
    _markAsProcessing();
    _eventController.add(currentEvent);
  }

  void pause() {
    _markAsPaused();
  }

  void _retry(void Function()? errorFallback) {
    if (_isDisposed) return; // Check if the controller is disposed

    if (exceededRetryLimit) {
      _markEventFail();

      if (skipOnError) {
        if (isLastEvent) {
          _markAsCompleted();
        } else {
          _next();
        }
      } else {
        errorFallback?.call();
      }
    } else {
      _retryCount++;
      _markAsRetrying();
      _eventController.add(currentEvent);
    }
  }

  void reset() {
    _resetRetryCount();
    _emitStatus(EventStatus.initial());
  }

  void _resetRetryCount() {
    _retryCount = 0;
  }

  void _next() {
    if (_isDisposed || isPaused) return;

    var completed = currentEventStatus.completed;
    var status = AsyncStatus.processing;

    if (isRetrying) {
      status = AsyncStatus.retrying;
    } else {
      completed = currentEventStatus.completed + 1;
    }
    final total = currentEventStatus.total;

    if (completed <= total - 1) {
      _emitStatus(
        currentEventStatus.copyWith(
          status: status,
          current: currentEvent,
          completed: completed,
        ),
      );
      _eventController.add(currentEvent);
    } else {
      if(completed == total) {
        _markAsCompleted(completed);
      }
    }
  }

  void _markEventFail() {
    if (_isDisposed) return; // Check if the controller is disposed

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.error,
      ),
    );
  }

  void _markAsCompleted([int? completed]) {
    if (_isDisposed) return; // Check if the controller is disposed

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.completed,
        completed: completed ?? currentEventStatus.completed,
      ),
    );
  }

  void _markAsError() {
    if (_isDisposed) return; // Check if the controller is disposed

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.error,
      ),
    );
  }

  bool get isLastEvent =>
      currentEventStatus.completed == currentEventStatus.total;

  void _markAsProcessing() {
    if (_isDisposed) return; // Check if the controller is disposed

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.processing,
      ),
    );
  }

  void _markAsRetrying() {
    if (_isDisposed) return; // Check if the controller is disposed

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.retrying,
      ),
    );
  }

  void _markAsPaused() {
    if (_isDisposed) return; // Check if the controller is disposed

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.paused,
      ),
    );
  }

  void retryCurrent() {
    if (_isDisposed) return; // Check if the controller is disposed

    _eventController.add(currentEvent);
  }

  void _emitStatus(EventStatus eventStatus) {
    if (_isDisposed) return; // Check if the controller is disposed

    currentEventStatus = eventStatus;
    _eventStatusController.add(eventStatus);
  }

  bool get isCompleted => currentEventStatus.status == AsyncStatus.completed;

  bool get isProcessing => currentEventStatus.status == AsyncStatus.processing;

  bool get isPaused => currentEventStatus.status == AsyncStatus.paused;

  bool get isCanceled => currentEventStatus.status == AsyncStatus.canceled;

  bool get isError => currentEventStatus.status == AsyncStatus.error;

  bool get isRetrying => currentEventStatus.status == AsyncStatus.retrying;

  bool get isInitial => currentEventStatus.status == AsyncStatus.initial;

  bool get shouldDispose => isCompleted || isCanceled || isError;

  bool get exceededRetryLimit => _retryCount >= retryLimit;

  Future<void> _listenToEvents(AsyncEvent event) async {
    if (shouldDispose) {
      dispose();
    } else {
      try {
        if (!isRetrying) {
          _markAsProcessing();
        }
        await event.action();
        event.onSuccess?.call();

        if (!isError) {
          _next();
        }
      } catch (e) {
        _retry(() {
          event.onError?.call(e);
        });
      }
    }
  }

  /// The list of events to be processed
  final List<AsyncEvent> events;

  /// The number of times the controller will retry an event before failing
  final int retryLimit;

  /// If false, the controller will be disposed after the last failed event
  ///
  /// If true, error status will be emitted and the controller will continue
  /// to the next event
  final bool skipOnError;

  final _eventStatusController = StreamController<EventStatus>.broadcast();
  final _eventController = StreamController<AsyncEvent>.broadcast();
  EventStatus currentEventStatus = EventStatus.initial();

  /// Should be disposed after use
  Stream<EventStatus> get eventStatusStream => _eventStatusController.stream;

  void dispose() {
    _isDisposed = true; // Set the dispose flag
    _eventSubscription.cancel();
    _eventController.close();
    _eventStatusController.close();
  }
}
