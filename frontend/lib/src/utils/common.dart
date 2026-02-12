import 'package:intl/intl.dart';

String formatDurationHms(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');
  if (s > 0 || parts.isEmpty) parts.add('${s}s');
  return parts.join(' ');
}

DateTime? _parseToLocal(dynamic datetime) {
  if (datetime == null) return null;

  if (datetime is DateTime) {
    return datetime.toLocal();
  }

  if (datetime is String) {
    try {
      return DateTime.parse(datetime).toLocal();
    } catch (_) {
      return null;
    }
  }

  return null;
}

String formatAttemptDate(dynamic datetime) {
  final dt = _parseToLocal(datetime);
  if (dt == null) return '';
  return DateFormat('dd MMM yyyy').format(dt);
}

String formatAttemptTime(dynamic datetime) {
  final dt = _parseToLocal(datetime);
  if (dt == null) return '';
  return DateFormat('HH:mm').format(dt);
}
