/// リーダー出力モード（手元〜遠距離）
enum OutputMode { hand, near, mid, far }

extension OutputModeX on OutputMode {
  String get mainLabel {
    switch (this) {
      case OutputMode.hand:
        return '手元';
      case OutputMode.near:
        return '近距離';
      case OutputMode.mid:
        return '中距離';
      case OutputMode.far:
        return '遠距離';
    }
  }

  /// 読み取り距離の目安（カード2行目）
  String get distanceHint {
    switch (this) {
      case OutputMode.hand:
        return '約3〜5 cm';
      case OutputMode.near:
        return '約15〜30 cm';
      case OutputMode.mid:
        return '約30〜50 cm';
      case OutputMode.far:
        return '最大 約1.2 m';
    }
  }

  /// 後方互換・ホーム表示用
  String get subLabel => distanceHint;

  String get displayLabel => '$mainLabel（$distanceHint）';

  /// ターゲット dBm 目安（内部変換用）
  int get targetDbm {
    switch (this) {
      case OutputMode.hand:
        return 4; // 3-5 の中間
      case OutputMode.near:
        return 15;
      case OutputMode.mid:
        return 20;
      case OutputMode.far:
        return 30;
    }
  }

  /// 現在の dBm から最も近いモードを返す。
  static OutputMode fromDbm(int dbm, {int maxDbm = 30}) {
    final v = dbm.clamp(0, maxDbm);
    if (v <= 5) return OutputMode.hand;
    if (v <= 15) return OutputMode.near;
    if (v <= 20) return OutputMode.mid;
    return OutputMode.far;
  }
}
