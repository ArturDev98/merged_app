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

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

// Redondeo y no inDays: un cambio de horario deja días de 23 o 25 horas.
int _daysAgo(DateTime date, DateTime now) =>
    (_midnight(now).difference(_midnight(date.toLocal())).inHours / 24).round();

bool isToday(DateTime date, {DateTime? now}) =>
    _daysAgo(date, now ?? DateTime.now()) <= 0;

/// Encabezado para agrupar por día: "Hoy", "Ayer" o "Jueves 24 sep".
String dayLabel(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final days = _daysAgo(date, reference);
  if (days <= 0) return 'Hoy';
  if (days == 1) return 'Ayer';

  final local = date.toLocal();
  final year = local.year == reference.year ? '' : ' ${local.year}';
  final label =
      '${_weekdays[local.weekday - 1]} ${local.day} '
      '${_months[local.month - 1]}$year';
  return label[0].toUpperCase() + label.substring(1);
}

/// Hora local, "09:05".
String clockTime(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
