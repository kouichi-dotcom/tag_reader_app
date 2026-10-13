/// 伝票紐付け時の更新後ステータス / tag_table3.tag_mode を用件から推定する。
class SlipLinkStatusResolver {
  SlipLinkStatusResolver._();

  /// 引取／来店(返品)（納品明細の返却記録対象）
  static bool isPickupReturn(String subject) {
    final s = subject.trim();
    return s == '引取' || s == '来店(返品)';
  }

  /// 警告の「EPC xxx:」を商品表示に置き換える用のラベル
  static String productDisplayLabel({
    required String name,
    required String code,
    String? number,
  }) {
    final n = (number == null || number.isEmpty) ? '--' : number;
    final nm = name.trim().isEmpty ? '--' : name.trim();
    final cd = code.trim().isEmpty ? '--' : code.trim();
    return '$nm（コード $cd / 番号 $n）';
  }

  /// API 警告文の先頭「EPC …:」を [epcToLabel] の商品表示に置換する
  static String rewriteWarningEpc(String warning, Map<String, String> epcToLabel) {
    final m = RegExp(
      r'^EPC\s+(.+?):\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(warning.trim());
    if (m == null) return warning;
    final epc = m.group(1)!.trim();
    final rest = m.group(2)!;
    final label = epcToLabel[epc] ??
        epcToLabel.entries
            .where((e) => e.key.toLowerCase() == epc.toLowerCase())
            .map((e) => e.value)
            .firstOrNull;
    if (label == null || label.isEmpty) return warning;
    return '$label: $rest';
  }

  static List<String> rewriteWarnings(
    List<String> warnings,
    Map<String, String> epcToLabel,
  ) {
    if (warnings.isEmpty || epcToLabel.isEmpty) return warnings;
    return warnings.map((w) => rewriteWarningEpc(w, epcToLabel)).toList();
  }

  /// 送信成功ダイアログ用メッセージ
  static String successMessage({
    required String receptionNo,
    required String subject,
    String? linkMode,
    required int linked,
    required int deliveryReturnUpdated,
    List<String> warnings = const [],
    Map<String, String> epcToLabel = const {},
  }) {
    final displayWarnings = rewriteWarnings(warnings, epcToLabel);
    final lines = <String>[
      '伝票 $receptionNo の送信が完了しました。',
    ];
    if (isPickupReturn(subject)) {
      lines.add('・商品ステータス: 在庫へ戻しました（$linked 件）');
      if (deliveryReturnUpdated > 0) {
        lines.add('・納品明細の返却記録: $deliveryReturnUpdated 件（返却＝1）');
      } else {
        lines.add('・納品明細の返却記録: 0 件（付けられませんでした）');
      }
    } else if (subject.trim() == '交換' && linkMode != null && linkMode.isNotEmpty) {
      lines.add('・$linkMode: $linked 件を記録しました');
    } else {
      lines.add('・紐付け: $linked 件を記録しました');
    }
    if (displayWarnings.isNotEmpty) {
      lines.add('');
      lines.add('警告:');
      for (final w in displayWarnings.take(5)) {
        lines.add('・$w');
      }
      if (displayWarnings.length > 5) {
        lines.add('・…他 ${displayWarnings.length - 5} 件');
      }
    }
    return lines.join('\n');
  }

  /// 送信成功ダイアログのタイトル
  static String successTitle({
    required String subject,
    required int deliveryReturnUpdated,
    List<String> warnings = const [],
  }) {
    if (warnings.isNotEmpty) return '送信完了（警告あり）';
    if (isPickupReturn(subject)) {
      return deliveryReturnUpdated > 0 ? '返却処理完了' : '送信完了（返却未記録）';
    }
    return '送信完了';
  }

  /// ICタグ台帳の tag_mode2（更新後ステータス）
  static String statusAfter({
    required String subject,
    String? linkMode,
  }) {
    final s = subject.trim();
    if (s == '引取' || s == '来店(返品)') return '在庫';
    if (s == '交換') {
      if (linkMode == '交換返品') return '整備中';
      return '貸出中'; // 交換納品
    }
    return '貸出中';
  }

  /// tag_table3.tag_mode 相当
  static String tagMode({
    required String subject,
    String? linkMode,
  }) {
    final s = subject.trim();
    if (s == '引取' || s == '来店(返品)') return '返品';
    if (s == '交換') {
      if (linkMode == '交換返品') return '交換返品';
      if (linkMode == '交換納品') return '交換納品';
      return linkMode ?? '交換納品';
    }
    return '納品';
  }
}
