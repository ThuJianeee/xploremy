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
