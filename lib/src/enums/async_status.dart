enum AsyncStatus {
  initial,
  processing,
  completed,
  error,
  canceled,
  paused,
  retrying,
}


extension AsyncStatusX on AsyncStatus {
  bool get isInitial => this == AsyncStatus.initial;
  bool get isProcessing => this == AsyncStatus.processing;
  bool get isCompleted => this == AsyncStatus.completed;
  bool get isError => this == AsyncStatus.error;
  bool get isCanceled => this == AsyncStatus.canceled;
  bool get isPaused => this == AsyncStatus.paused;
  bool get isRetrying => this == AsyncStatus.retrying;
  bool get shouldDispose => isCompleted || isCanceled || isError;
  bool get canNext => !isRetrying && !isError && !isCanceled && !isPaused;
  bool get shouldEmit => !isPaused;
}
