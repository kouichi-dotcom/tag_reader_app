/// 伝票一覧の取得条件（API のクエリパラメータに対応）。
class SlipListFilter {
  const SlipListFilter({
    this.date,
    this.assigneeCode,
    this.unassignedOnly = false,
    this.random = false,
    this.subjectFilter,
  });

  final DateTime? date;
  final String? assigneeCode;
  final bool unassignedOnly;
  final bool random;
  /// 用件で絞り込み（API の subjects にカンマ区切りで渡す）。例: ['来店(納品)', '来店(返品)']
  final List<String>? subjectFilter;

  /// 全伝票一覧用（日付・担当者絞りなし、受付日時順で最新10件）
  static const SlipListFilter all = SlipListFilter();

  /// テスト用：ランダム10件
  static const SlipListFilter randomForTest = SlipListFilter(random: true);

  /// 来店伝票一覧用：用件が「来店(納品)」「来店(返品)」のみ、最新10件
  static const SlipListFilter visitSlipOnly = SlipListFilter(
    subjectFilter: ['来店(納品)', '来店(返品)'],
  );
}
