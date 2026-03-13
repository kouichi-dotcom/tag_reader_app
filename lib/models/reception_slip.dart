import 'reception_detail_item.dart';

/// 受付台帳の1件（API レスポンス）
class ReceptionSlip {
  const ReceptionSlip({
    required this.receptionNo,
    required this.subject,
    required this.customerName,
    this.customerNameOther,
    required this.siteName,
    this.siteNameOther,
    this.dueDate,
    this.deadlineName,
    this.deadline2,
    this.memo,
    this.receptionAt,
    this.handlerCode,
    this.handlerName,
    this.details = const [],
  });

  final String receptionNo;
  final String subject;
  final String customerName;
  final String? customerNameOther;
  final String siteName;
  final String? siteNameOther;
  final DateTime? dueDate;
  final String? deadlineName;
  final String? deadline2;
  final String? memo;
  final DateTime? receptionAt;
  /// 処理者（担当者コード）
  final String? handlerCode;
  /// 処理者（担当者コード）に対応する担当者氏名
  final String? handlerName;
  final List<ReceptionDetailItem> details;

  /// 担当者表示用：担当者名があればそのまま、なければ「コード: X」または「--」
  String get handlerDisplay {
    if (handlerName != null && handlerName!.trim().isNotEmpty) return handlerName!;
    if (handlerCode != null && handlerCode!.trim().isNotEmpty) return 'コード: ${handlerCode!.trim()}';
    return '--';
  }

  static List<ReceptionDetailItem> _parseDetails(dynamic raw) {
    if (raw == null || raw is! List) return const [];
    return raw
        .map((e) => ReceptionDetailItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// JSON のキーは API が camelCase / PascalCase のどちらで返しても読めるように両方対応
  static String? _str(Map<String, dynamic> json, String camel, String pascal) {
    final v = json[camel] ?? json[pascal];
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static ReceptionSlip fromJson(Map<String, dynamic> json) {
    return ReceptionSlip(
      receptionNo: _str(json, 'receptionNo', 'ReceptionNo') ?? '',
      subject: _str(json, 'subject', 'Subject') ?? '',
      customerName: _str(json, 'customerName', 'CustomerName') ?? '',
      customerNameOther: _str(json, 'customerNameOther', 'CustomerNameOther'),
      siteName: _str(json, 'siteName', 'SiteName') ?? '',
      siteNameOther: _str(json, 'siteNameOther', 'SiteNameOther'),
      dueDate: json['dueDate'] != null || json['DueDate'] != null
          ? DateTime.tryParse((json['dueDate'] ?? json['DueDate']).toString())
          : null,
      deadlineName: _str(json, 'deadlineName', 'DeadlineName'),
      deadline2: _str(json, 'deadline2', 'Deadline2'),
      memo: _str(json, 'memo', 'Memo'),
      receptionAt: json['receptionAt'] != null || json['ReceptionAt'] != null
          ? DateTime.tryParse((json['receptionAt'] ?? json['ReceptionAt']).toString())
          : null,
      handlerCode: _str(json, 'handlerCode', 'HandlerCode'),
      handlerName: _str(json, 'handlerName', 'HandlerName'),
      details: _parseDetails(json['details'] ?? json['Details']),
    );
  }
}
