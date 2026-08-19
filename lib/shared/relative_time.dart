/// Tiempo relativo en español, corto, para listas.
String relativeTime(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  final reference = now ?? DateTime.now();
  final diff = reference.difference(date);

  if (diff.isNegative) return 'ahora';
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  if (diff.inDays < 7) return 'hace ${diff.inDays} días';
  if (diff.inDays < 30) return 'hace ${(diff.inDays / 7).floor()} sem';
  if (diff.inDays < 365) return 'hace ${(diff.inDays / 30).floor()} meses';
  return 'hace ${(diff.inDays / 365).floor()} años';
}
