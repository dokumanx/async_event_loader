import 'package:equatable/equatable.dart';

class AsyncEvent with EquatableMixin {
  AsyncEvent({
    required this.action,
    this.onSuccess,
    this.onRetry,
    this.onError,
    this.onCancel,
    this.order,
    this.label,
  });

  final Future<dynamic> Function() action;
  final void Function()? onRetry;
  final void Function()? onSuccess;
  final void Function(dynamic error)? onError;
  final void Function()? onCancel;
  final int? order;
  final String? label;

  AsyncEvent copyWith({
    Future<dynamic> Function()? action,
    void Function()? onRetry,
    void Function()? onSuccess,
    void Function(dynamic error)? onError,
    void Function()? onCancel,
    int? order,
    String? label,
  }) {
    return AsyncEvent(
      action: action ?? this.action,
      onRetry: onRetry ?? this.onRetry,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      onCancel: onCancel ?? this.onCancel,
      order: order ?? this.order,
      label: label ?? this.label,
    );
  }

  @override
  List<Object?> get props => [order, action];
}
