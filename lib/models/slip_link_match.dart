import '../mocks/mock_data.dart';
import 'reception_detail_item.dart';

/// 伝票明細と紐付け選択の照合結果（確認画面用）
/// 表示は重複なく次の3分類:
/// 1. 合致する紐付け商品
/// 2. 不足する商品
/// 3. 伝票にない紐付け商品（余分含む）
class SlipLinkMatch {
  const SlipLinkMatch({
    required this.matchedProducts,
    required this.shortageRows,
    required this.notOnSlipProducts,
    required this.linkedProducts,
  });

  /// 伝票内容と合致する紐付け（必要数までの分）
  final List<MockLinkProduct> matchedProducts;
  /// 伝票内容に対して不足している明細
  final List<SlipLinkShortageRow> shortageRows;
  /// 伝票にない／必要数を超えた紐付け
  final List<MockLinkProduct> notOnSlipProducts;
  final List<MockLinkProduct> linkedProducts;

  bool get hasShortage => shortageRows.isNotEmpty;
  bool get hasExtra => notOnSlipProducts.isNotEmpty;
  bool get hasMismatch => hasShortage || hasExtra;
  bool get isComplete =>
      linkedProducts.isNotEmpty && !hasShortage && !hasExtra;

  /// [details] と [linked] を商品コード単位で照合し、3分類に振り分ける。
  static SlipLinkMatch analyze({
    required List<ReceptionDetailItem> details,
    required List<MockLinkProduct> linked,
  }) {
    final requiredByCode = <String, ({String name, int qty})>{};
    for (final d in details) {
      final code = d.productCode?.toString().trim() ?? '';
      if (code.isEmpty) continue;
      final need = d.quantity?.toInt() ?? 0;
      final name = d.productName.trim().isEmpty ? '商品コード: $code' : d.productName.trim();
      final existing = requiredByCode[code];
      if (existing == null) {
        requiredByCode[code] = (name: name, qty: need);
      } else {
        requiredByCode[code] = (name: existing.name, qty: existing.qty + need);
      }
    }

    final linkedByCode = <String, List<MockLinkProduct>>{};
    final unknownCode = <MockLinkProduct>[];
    for (final p in linked) {
      final code = p.code.trim();
      if (code.isEmpty || code == '--' || !requiredByCode.containsKey(code)) {
        unknownCode.add(p);
        continue;
      }
      linkedByCode.putIfAbsent(code, () => <MockLinkProduct>[]).add(p);
    }

    final matched = <MockLinkProduct>[];
    final notOnSlip = <MockLinkProduct>[...unknownCode];
    final shortages = <SlipLinkShortageRow>[];

    final codes = requiredByCode.keys.toList()..sort();
    for (final code in codes) {
      final req = requiredByCode[code]!;
      final list = linkedByCode[code] ?? const <MockLinkProduct>[];
      final take = list.length < req.qty ? list.length : req.qty;
      matched.addAll(list.take(take));
      if (list.length > take) {
        notOnSlip.addAll(list.skip(take));
      }
      if (list.length < req.qty) {
        shortages.add(SlipLinkShortageRow(
          productCode: code,
          productName: req.name,
          requiredQty: req.qty,
          linkedQty: list.length,
          shortageQty: req.qty - list.length,
        ));
      }
    }

    return SlipLinkMatch(
      matchedProducts: matched,
      shortageRows: shortages,
      notOnSlipProducts: notOnSlip,
      linkedProducts: linked,
    );
  }
}

class SlipLinkShortageRow {
  const SlipLinkShortageRow({
    required this.productCode,
    required this.productName,
    required this.requiredQty,
    required this.linkedQty,
    required this.shortageQty,
  });

  final String productCode;
  final String productName;
  final int requiredQty;
  final int linkedQty;
  final int shortageQty;
}

/// 紐付け画面から伝票一覧へ戻す結果
class SlipLinkPopResult {
  const SlipLinkPopResult({
    required this.products,
    this.submitted = false,
  });

  final List<MockLinkProduct> products;
  /// true: 確認画面から API 送信済み
  final bool submitted;
}
