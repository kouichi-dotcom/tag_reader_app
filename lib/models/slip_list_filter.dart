/// 伝票一覧の取得条件（API のクエリパラメータに対応）。
class SlipListFilter {
  /// 担当者コードで絞り込み（日付なし＝全期間から受付日時の新しい順）
  /// 例: SlipListFilter(assigneeCode: '69')
  const SlipListFilter({
    this.date,
    this.assigneeCode,
    this.unassignedOnly = false,
    this.random = false,
    this.subjectFilter,
    this.limit = 10,
    this.offset = 0,
  });

  final DateTime? date;
  final String? assigneeCode;
  final bool unassignedOnly;
  final bool random;
  /// 用件で絞り込み（API の subjects にカンマ区切りで渡す）。例: ['来店(納品)', '来店(返品)']
  final List<String>? subjectFilter;
  /// 1回の取得件数（API limit）。省略時 10
  final int limit;
  /// 先頭からスキップする件数（API offset）
  final int offset;

  /// 全伝票一覧用（日付・担当者絞りなし、受付日時順）
  static const SlipListFilter all = SlipListFilter();

  /// テスト用：ランダム取得
  static const SlipListFilter randomForTest = SlipListFilter(random: true);

  /// 来店伝票一覧用：用件が「来店(納品)」「来店(返品)」のみ
  static const SlipListFilter visitSlipOnly = SlipListFilter(
    subjectFilter: ['来店(納品)', '来店(返品)'],
  );

  SlipListFilter copyWith({
    DateTime? date,
    String? assigneeCode,
    bool? unassignedOnly,
    bool? random,
    List<String>? subjectFilter,
    int? limit,
    int? offset,
  }) {
    return SlipListFilter(
      date: date ?? this.date,
      assigneeCode: assigneeCode ?? this.assigneeCode,
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      random: random ?? this.random,
      subjectFilter: subjectFilter ?? this.subjectFilter,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}
