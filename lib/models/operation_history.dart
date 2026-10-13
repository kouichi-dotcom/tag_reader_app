/// 更新操作の種類（履歴本体の operation_type）
enum OperationType {
  statusUpdate('status_update'),
  slipLink('slip_link'),
  tagRegistration('tag_registration'),
  epcUpdate('epc_update'),
  productCodeUpdate('product_code_update');

  const OperationType(this.value);
  final String value;

  static OperationType fromValue(String value) {
    return OperationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OperationType.statusUpdate,
    );
  }

  /// UI 表示名
  String get displayName {
    switch (this) {
      case OperationType.statusUpdate:
        return 'ステータス更新';
      case OperationType.slipLink:
        return '伝票紐付け';
      case OperationType.tagRegistration:
        return 'タグ新規登録';
      case OperationType.epcUpdate:
        return 'タグID再設定';
      case OperationType.productCodeUpdate:
        return '商品コード変更';
    }
  }
}

/// 履歴本体の結果
enum HistoryResultStatus {
  success('success'),
  failed('failed'),
  partialFailure('partial_failure');

  const HistoryResultStatus(this.value);
  final String value;

  static HistoryResultStatus fromValue(String value) {
    return HistoryResultStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HistoryResultStatus.failed,
    );
  }

  String get displayLabel {
    switch (this) {
      case HistoryResultStatus.success:
        return '✓ 成功';
      case HistoryResultStatus.failed:
        return '× 失敗';
      case HistoryResultStatus.partialFailure:
        return '△ 一部失敗';
    }
  }
}

/// 履歴明細の結果
enum ItemResultStatus {
  success('success'),
  failed('failed'),
  notSent('not_sent');

  const ItemResultStatus(this.value);
  final String value;

  static ItemResultStatus fromValue(String value) {
    return ItemResultStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ItemResultStatus.notSent,
    );
  }

  String get displayLabel {
    switch (this) {
      case ItemResultStatus.success:
        return '成功';
      case ItemResultStatus.failed:
        return '失敗';
      case ItemResultStatus.notSent:
        return '未送信';
    }
  }
}

/// 履歴明細 1 件
class OperationHistoryItem {
  const OperationHistoryItem({
    this.id,
    this.historyId,
    this.epc,
    this.productCode,
    this.number,
    this.productName,
    this.statusBefore,
    this.statusAfter,
    this.tagMode,
    this.resultStatus = ItemResultStatus.success,
    this.httpStatus,
    this.errorMessage,
    this.epcBefore,
    this.epcAfter,
    this.productCodeBefore,
    this.productCodeAfter,
    this.numberBefore,
    this.numberAfter,
  });

  final int? id;
  final int? historyId;
  final String? epc;
  final String? productCode;
  final String? number;
  final String? productName;
  final String? statusBefore;
  final String? statusAfter;
  final String? tagMode;
  final ItemResultStatus resultStatus;
  final int? httpStatus;
  final String? errorMessage;
  final String? epcBefore;
  final String? epcAfter;
  final String? productCodeBefore;
  final String? productCodeAfter;
  final String? numberBefore;
  final String? numberAfter;

  OperationHistoryItem copyWith({
    int? id,
    int? historyId,
    String? epc,
    String? productCode,
    String? number,
    String? productName,
    String? statusBefore,
    String? statusAfter,
    String? tagMode,
    ItemResultStatus? resultStatus,
    int? httpStatus,
    String? errorMessage,
    String? epcBefore,
    String? epcAfter,
    String? productCodeBefore,
    String? productCodeAfter,
    String? numberBefore,
    String? numberAfter,
  }) {
    return OperationHistoryItem(
      id: id ?? this.id,
      historyId: historyId ?? this.historyId,
      epc: epc ?? this.epc,
      productCode: productCode ?? this.productCode,
      number: number ?? this.number,
      productName: productName ?? this.productName,
      statusBefore: statusBefore ?? this.statusBefore,
      statusAfter: statusAfter ?? this.statusAfter,
      tagMode: tagMode ?? this.tagMode,
      resultStatus: resultStatus ?? this.resultStatus,
      httpStatus: httpStatus ?? this.httpStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      epcBefore: epcBefore ?? this.epcBefore,
      epcAfter: epcAfter ?? this.epcAfter,
      productCodeBefore: productCodeBefore ?? this.productCodeBefore,
      productCodeAfter: productCodeAfter ?? this.productCodeAfter,
      numberBefore: numberBefore ?? this.numberBefore,
      numberAfter: numberAfter ?? this.numberAfter,
    );
  }

  Map<String, Object?> toMap(int historyId) {
    return {
      'history_id': historyId,
      'epc': epc,
      'product_code': productCode,
      'number': number,
      'product_name': productName,
      'status_before': statusBefore,
      'status_after': statusAfter,
      'tag_mode': tagMode,
      'result_status': resultStatus.value,
      'http_status': httpStatus,
      'error_message': errorMessage,
      'epc_before': epcBefore,
      'epc_after': epcAfter,
      'product_code_before': productCodeBefore,
      'product_code_after': productCodeAfter,
      'number_before': numberBefore,
      'number_after': numberAfter,
    };
  }

  factory OperationHistoryItem.fromMap(Map<String, Object?> map) {
    return OperationHistoryItem(
      id: map['id'] as int?,
      historyId: map['history_id'] as int?,
      epc: map['epc'] as String?,
      productCode: map['product_code'] as String?,
      number: map['number'] as String?,
      productName: map['product_name'] as String?,
      statusBefore: map['status_before'] as String?,
      statusAfter: map['status_after'] as String?,
      tagMode: map['tag_mode'] as String?,
      resultStatus: ItemResultStatus.fromValue(
        map['result_status'] as String? ?? ItemResultStatus.notSent.value,
      ),
      httpStatus: map['http_status'] as int?,
      errorMessage: map['error_message'] as String?,
      epcBefore: map['epc_before'] as String?,
      epcAfter: map['epc_after'] as String?,
      productCodeBefore: map['product_code_before'] as String?,
      productCodeAfter: map['product_code_after'] as String?,
      numberBefore: map['number_before'] as String?,
      numberAfter: map['number_after'] as String?,
    );
  }
}

/// 履歴本体 1 件（明細を含む）
class OperationHistory {
  const OperationHistory({
    this.id,
    required this.createdAtMs,
    required this.operationType,
    required this.resultStatus,
    this.httpStatus,
    this.errorMessage,
    this.environment,
    this.userId,
    this.userName,
    this.receptionNo,
    this.companyName,
    this.siteName,
    this.subject,
    this.linkMode,
    this.items = const [],
  });

  final int? id;

  /// UTC Unix milliseconds
  final int createdAtMs;
  final OperationType operationType;
  final HistoryResultStatus resultStatus;
  final int? httpStatus;
  final String? errorMessage;
  final String? environment;
  final String? userId;
  final String? userName;
  final String? receptionNo;
  final String? companyName;
  final String? siteName;
  final String? subject;
  final String? linkMode;
  final List<OperationHistoryItem> items;

  /// 端末ローカル日時（UI 表示用）
  DateTime get createdAtLocal =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true).toLocal();

  Map<String, Object?> toMap() {
    return {
      'created_at_ms': createdAtMs,
      'operation_type': operationType.value,
      'result_status': resultStatus.value,
      'http_status': httpStatus,
      'error_message': errorMessage,
      'environment': environment,
      'user_id': userId,
      'user_name': userName,
      'reception_no': receptionNo,
      'company_name': companyName,
      'site_name': siteName,
      'subject': subject,
      'link_mode': linkMode,
    };
  }

  factory OperationHistory.fromMap(
    Map<String, Object?> map, {
    List<OperationHistoryItem> items = const [],
  }) {
    return OperationHistory(
      id: map['id'] as int?,
      createdAtMs: map['created_at_ms'] as int? ?? 0,
      operationType: OperationType.fromValue(
        map['operation_type'] as String? ?? OperationType.statusUpdate.value,
      ),
      resultStatus: HistoryResultStatus.fromValue(
        map['result_status'] as String? ?? HistoryResultStatus.failed.value,
      ),
      httpStatus: map['http_status'] as int?,
      errorMessage: map['error_message'] as String?,
      environment: map['environment'] as String?,
      userId: map['user_id'] as String?,
      userName: map['user_name'] as String?,
      receptionNo: map['reception_no'] as String?,
      companyName: map['company_name'] as String?,
      siteName: map['site_name'] as String?,
      subject: map['subject'] as String?,
      linkMode: map['link_mode'] as String?,
      items: items,
    );
  }

  /// 明細の結果から本体の result_status を集約する。
  static HistoryResultStatus aggregateResult(List<OperationHistoryItem> items) {
    if (items.isEmpty) return HistoryResultStatus.failed;
    final hasSuccess =
        items.any((i) => i.resultStatus == ItemResultStatus.success);
    final hasFailureOrNotSent = items.any(
      (i) =>
          i.resultStatus == ItemResultStatus.failed ||
          i.resultStatus == ItemResultStatus.notSent,
    );
    if (hasSuccess && hasFailureOrNotSent) {
      return HistoryResultStatus.partialFailure;
    }
    if (hasSuccess) return HistoryResultStatus.success;
    return HistoryResultStatus.failed;
  }
}
