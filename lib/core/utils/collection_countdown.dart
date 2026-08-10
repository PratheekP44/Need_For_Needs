/// Formats a remaining duration as HH:MM:SS for collection countdown UI.
String formatCollectionCountdown(Duration remaining) {
  final totalSeconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}

/// Remaining time until [deadline] (UTC), using [now] for testability.
Duration collectionRemaining({
  required DateTime deadline,
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toUtc();
  return deadline.toUtc().difference(current);
}
