String cleanStationName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(
        RegExp(r'\s*-\s*REDONE\s*$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? value.trim() : cleaned;
}

String _walkingInterchangeKey(String value) {
  var result = cleanStationName(value).toUpperCase();
  result = result.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ');
  result = result
      .replaceAll(RegExp(r'\b(STATION|STN)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return result;
}

bool areKnownWalkingInterchangeNames(String first, String second) {
  final a = _walkingInterchangeKey(first);
  final b = _walkingInterchangeKey(second);

  bool containsPair(String left, String right) {
    return (a.contains(left) && b.contains(right)) ||
        (a.contains(right) && b.contains(left));
  }

  return containsPair('KL SENTRAL', 'MUZIUM NEGARA') ||
      containsPair('MERDEKA', 'PLAZA RAKYAT') ||
      containsPair('BUKIT NANAS', 'DANG WANGI');
}
