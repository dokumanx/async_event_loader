import 'dart:async';

import 'package:async/async.dart';
import 'package:async_event_loader/src/enums/async_status.dart';
import 'package:async_event_loader/src/models/async_event.dart';
import 'package:async_event_loader/src/models/event_status.dart';
import 'package:rxdart/rxdart.dart';

/// Represents a controller for managing and controlling async events.
class AsyncEventLoaderController {
  /// Creates a new instance of [AsyncEventLoaderController].
  ///
  /// [events] is a required list of AsyncEvent that the controller will
  /// process.
  /// [retryLimit] is the number of times the controller will retry an event
  /// before failing. Default is 3.
  /// [skipOnError] determines whether the controller should continue to the
  /// next event when an error occurs. Default is false.
  AsyncEventLoaderController({
    required this.events,
    this.retryLimit = 3,
    this.skipOnError = false,
  }) {
    _eventSubscription = _eventController.stream.listen(_listenToEvents);

    _emitStatus(currentEventStatus.copyWith(total: events.length));

    _eventController
      ..doOnPause(() {
        _markAsPaused();
        _eventSubscription.pause();
      })
      ..doOnResume(() {
        _markAsProcessing();
        _eventSubscription.resume();
      });
  }

  late final StreamSubscription<AsyncEvent> _eventSubscription;

  CancelableOperation<dynamic>? _cancellable;

  /// Returns the current event that the controller is processing.
  AsyncEvent get currentEvent => events[currentEventStatus.completed];

  int _retryCount = 0;

  /// Returns the current retry count.
  int get retryCount => _retryCount;

  /// Flag to track if the controller is disposed
  bool _isDisposed = false;

  /// Starts the processing of events.
  void run() {
    _markAsProcessing();

    _eventController.add(currentEvent);
  }

  /// Pauses the processing of events.
  void pause() {
    _markAsPaused();
    _cancellable?.cancel();
  }

  /// Retries the current event.
  ///
  /// [errorFallback] is a function that will be called when the retry limit is
  /// exceeded.
  void _retry(void Function()? errorFallback) {
    if (_isDisposed) return;

    if (exceededRetryLimit) {
      _markEventFail();
      _resetRetryCount();

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
      _retryCurrent();
    }
  }

  /// Resets the controller to its initial state.
  void reset() {
    _resetRetryCount();
    _emitStatus(EventStatus.initial());
  }

  /// Resets the retry count to 0.
  void _resetRetryCount() {
    _retryCount = 0;
  }

  /// Moves to the next event in the list.
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
      if (completed == total) {
        _markAsCompleted(completed);
      }
    }
  }

  /// Marks the current event as failed.
  void _markEventFail() {
    if (_isDisposed) return;

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.error,
      ),
    );
  }

  /// Marks the current event as completed.
  void _markAsCompleted([int? completed]) {
    if (_isDisposed) return;

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.completed,
        completed: completed ?? currentEventStatus.completed,
      ),
    );
  }

  /// Checks if the current event is the last event in the list.
  bool get isLastEvent =>
      currentEventStatus.completed == currentEventStatus.total;

  /// Marks the current event as processing.
  void _markAsProcessing() {
    if (_isDisposed) return;

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.processing,
      ),
    );
  }

  /// Marks the current event as retrying.
  void _markAsRetrying() {
    if (_isDisposed) return;

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.retrying,
        retryCount: _retryCount,
      ),
    );
  }

  /// Marks the current event as paused.
  void _markAsPaused() {
    if (_isDisposed) return;

    _emitStatus(
      currentEventStatus.copyWith(
        status: AsyncStatus.paused,
      ),
    );
  }

  /// Retries the current event.
  void _retryCurrent() {
    if (_isDisposed) return;

    _eventController.add(currentEvent);
  }

  /// Emits the current event status.
  ///
  /// [eventStatus] is the status of the current event.
  void _emitStatus(EventStatus eventStatus) {
    if (_isDisposed) return;

    currentEventStatus = eventStatus.copyWith(retryCount: _retryCount);
    _eventStatusController.add(currentEventStatus);
  }

  bool get isCompleted => currentEventStatus.status.isCompleted;

  bool get isProcessing => currentEventStatus.status.isProcessing;

  bool get isPaused => currentEventStatus.status.isPaused;

  bool get isCanceled => currentEventStatus.status.isCanceled;

  bool get isError => currentEventStatus.status.isError;

  bool get isRetrying => currentEventStatus.status.isRetrying;

  bool get isInitial => currentEventStatus.status.isInitial;

  bool get shouldDispose => currentEventStatus.status.shouldDispose;

  bool get canNext => currentEventStatus.status.canNext;

  bool get exceededRetryLimit => _retryCount >= retryLimit;

  Future<void> _listenToEvents(AsyncEvent event) async {
    if (shouldDispose) {
      dispose();
    } else if (!isPaused) {
      try {
        if (!isRetrying) {
          _markAsProcessing();
        }
        _cancellable = CancelableOperation<dynamic>.fromFuture(event.action());
        await _cancellable?.value;

        event.onSuccess?.call();
        if (canNext) {
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

  final _eventStatusController =
      BehaviorSubject<EventStatus>.seeded(EventStatus.initial());
  final _eventController = BehaviorSubject<AsyncEvent>();
  EventStatus currentEventStatus = EventStatus.initial();

  /// Should be disposed after use
  Stream<EventStatus> get eventStatusStream =>
      _eventStatusController.stream.distinct((previous, next) {
        if (next.status == AsyncStatus.retrying) {
          return false;
        }

        return previous.status == next.status &&
            previous.completed == next.completed;
      });

  void dispose() {
    _isDisposed = true; // Set the dispose flag
    _eventSubscription.cancel();
    _eventController.close();
    _eventStatusController.close();
  }
}
