enum ReaderFamily {
  unknown,
  sr7,
  r5000,
}

ReaderFamily detectReaderFamilyFromName(String? name) {
  final n = (name ?? '').trim().toUpperCase();
  if (n.isEmpty) return ReaderFamily.unknown;

  if (n.startsWith('R-5000')) return ReaderFamily.r5000;
  if (n.startsWith('SR-7') || n.startsWith('SR7')) return ReaderFamily.sr7;

  return ReaderFamily.unknown;
}
