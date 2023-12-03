import 'package:async_event_loader/src/enums/async_status.dart';
import 'package:async_event_loader/src/models/async_event.dart';
import 'package:equatable/equatable.dart';

class EventStatus with EquatableMixin {
  EventStatus({
    required this.status,
    required this.current,
    required this.total,
    required this.completed,
    required this.label,
  }) {
    progress = completed / total;
  }

  EventStatus.initial()
      : status = AsyncStatus.initial,
        current = AsyncEvent(action: () async {}),
        total = 0,
        completed = 0,
        progress = 0,
        label = '';

  final AsyncStatus status;
  final AsyncEvent current;
  final int total;
  final int completed;
  late final double progress;
  final String label;

  @override
  List<Object?> get props =>
      [status, current, total, completed, progress, label];

  EventStatus copyWith({
    AsyncStatus? status,
    AsyncEvent? current,
    int? total,
    int? completed,
    String? label,
  }) {
    return EventStatus(
      status: status ?? this.status,
      current: current ?? this.current,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      label: label ?? this.label,
    );
  }

  @override
  String toString() {
    return '''
        Completed Events: $completed,
        Progress: %${(progress * 100).toStringAsFixed(0)},
        Event Status: $status,
        Current Event Order: ${current.order},
    ''';
  }
}
