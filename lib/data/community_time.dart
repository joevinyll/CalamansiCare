({String relative, String exact}) communityTime(Object? value,
    {DateTime? now}) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return (relative: 'Time unavailable', exact: '');
  final local = parsed.toLocal();
  final age = (now ?? DateTime.now()).difference(parsed);
  final relative = age.isNegative
      ? 'Posted'
      : age.inMinutes < 1
          ? 'Just now'
          : age.inHours < 1
              ? '${age.inMinutes} min ago'
              : age.inDays < 1
                  ? '${age.inHours} hr ago'
                  : '${age.inDays} ${age.inDays == 1 ? 'day' : 'days'} ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return (
    relative: relative,
    exact:
        '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute${local.hour < 12 ? 'am' : 'pm'}'
  );
}
