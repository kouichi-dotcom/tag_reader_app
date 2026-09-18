/// 自社 EPC 生成規則:
/// `c0de0038` + `YYYYMMDDHHmmss` + `cc`（1/100秒）= 24桁 hex
class EpcGenerator {
  EpcGenerator._();

  static const String prefix = 'c0de0038';
  static const int totalLength = 24;
  static const int maxCollisionRetries = 100;

  /// [at] 時点の EPC を1件生成する（小文字 hex）。
  static String generate({DateTime? at}) {
    final t = at ?? DateTime.now();
    final y = t.year.toString().padLeft(4, '0');
    final mo = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final cc = ((t.millisecond ~/ 10) % 100).toString().padLeft(2, '0');
    final epc = '$prefix$y$mo$d$h$mi$s$cc';
    assert(epc.length == totalLength);
    return epc;
  }

  /// 衝突回避付き生成。[isTaken] が true の間、時刻を 10ms 進めて再生成する。
  static String generateUnique({
    required bool Function(String epc) isTaken,
    DateTime? at,
    int maxRetries = maxCollisionRetries,
  }) {
    var cursor = at ?? DateTime.now();
    for (var i = 0; i < maxRetries; i++) {
      final epc = generate(at: cursor);
      if (!isTaken(epc)) return epc;
      cursor = cursor.add(const Duration(milliseconds: 10));
    }
    throw StateError('一意な EPC を生成できませんでした（衝突が解消しません）');
  }

  static bool isValidGenerated(String epc) {
    final e = epc.trim().toLowerCase();
    if (e.length != totalLength) return false;
    if (!e.startsWith(prefix)) return false;
    return RegExp(r'^[0-9a-f]+$').hasMatch(e);
  }
}
