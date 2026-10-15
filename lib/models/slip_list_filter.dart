/// 伝票一覧の取得条件（API のクエリパラメータに対応）。
class SlipListFilter {
  /// 担当者コードで絞り込み（日付なし＝期日の直近1ヶ月から新しい順）
  /// 例: SlipListFilter(assigneeCode: '69')
  const SlipListFilter({
    this.date,
    this.assigneeCode,
    this.unassignedOnly = false,
    this.random = false,
    this.subjectFilter,
    this.excludeSubjectFilter,
    this.limit = 10,
    this.offset = 0,
  });

  /// 期日で1日指定（yyyy-MM-dd）。省略時は期日の直近1ヶ月
  final DateTime? date;
  final String? assigneeCode;
  final bool unassignedOnly;
  final bool random;
  /// 用件で絞り込み（API の subjects にカンマ区切りで渡す）。例: ['来店(納品)', '来店(返品)']
  final List<String>? subjectFilter;
  /// 用件で除外（API の excludeSubjects にカンマ区切りで渡す）。例: ['来店(納品)', '来店(返品)']
  final List<String>? excludeSubjectFilter;
  /// 1回の取得件数（API limit）。省略時 10
  final int limit;
  /// 先頭からスキップする件数（API offset）
  final int offset;

  /// 全伝票一覧用（日付・担当者絞りなし、期日の新しい順）
  /// ※ 来店除外は [allNonVisit] を使う
  static const SlipListFilter all = SlipListFilter();

  /// 全伝票一覧（来店以外）: 来店(納品)・来店(返品)を除外
  static const SlipListFilter allNonVisit = SlipListFilter(
    excludeSubjectFilter: ['来店(納品)', '来店(返品)'],
  );

  /// テスト用：ランダム取得
  static const SlipListFilter randomForTest = SlipListFilter(random: true);

  /// 来店伝票一覧用：用件が「来店(納品)」「来店(返品)」のみ
  static const SlipListFilter visitSlipOnly = SlipListFilter(
    subjectFilter: ['来店(納品)', '来店(返品)'],
  );

  /// 急ぎ来店納品用：来店(納品)のみ・期日は呼び出し側で date を今日に設定
  static const SlipListFilter urgentVisitDelivery = SlipListFilter(
    subjectFilter: ['来店(納品)'],
    limit: 50,
  );

  SlipListFilter copyWith({
    DateTime? date,
    String? assigneeCode,
    bool? unassignedOnly,
    bool? random,
    List<String>? subjectFilter,
    List<String>? excludeSubjectFilter,
    int? limit,
    int? offset,
  }) {
    return SlipListFilter(
      date: date ?? this.date,
      assigneeCode: assigneeCode ?? this.assigneeCode,
      unassignedOnly: unassignedOnly ?? this.unassignedOnly,
      random: random ?? this.random,
      subjectFilter: subjectFilter ?? this.subjectFilter,
      excludeSubjectFilter: excludeSubjectFilter ?? this.excludeSubjectFilter,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}
