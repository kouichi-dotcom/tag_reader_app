import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../config/api_config.dart';
import '../models/operation_history.dart';
import '../utils/api_error_presenter.dart';
import 'employee_storage.dart';
import 'operation_history_repository.dart';

/// 画面から呼ぶ更新履歴の記録・参照 API。
///
/// 履歴保存失敗は握りつぶしログのみ。業務 API の成否には影響させない。
class OperationHistoryService {
  OperationHistoryService({OperationHistoryRepository? repository})
      : _repository = repository ?? OperationHistoryRepository();

  final OperationHistoryRepository _repository;

  static final OperationHistoryService instance = OperationHistoryService();

  /// Flavor から環境ラベルを取得。
  static String currentEnvironment() {
    if (kUseLocalApi) return 'local';
    if (kIsProdFlavor) return 'prod';
    if (kIsStagingFlavor) return 'staging';
    return 'unknown';
  }

  /// 例外から HTTP ステータスを抽出（通信未成立は null）。
  static int? httpStatusOf(Object? error) {
    if (error is ApiException) return error.statusCode;
    return null;
  }

  /// 例外からユーザー向け短いエラー文言を抽出。
  static String? errorMessageOf(Object? error) {
    if (error == null) return null;
    final facing = toUserFacingApiError(error);
    if (facing.title == '通信エラー') return facing.title;
    final msg = facing.message.trim();
    if (msg.isEmpty) return facing.title;
    // 1 行目だけ短く
    final firstLine = msg.split('\n').first.trim();
    return firstLine.isEmpty ? facing.title : firstLine;
  }

  /// 明細結果から本体 result_status を集約し、代表エラーを決めて記録する。
  Future<void> record({
    required OperationType operationType,
    required List<OperationHistoryItem> items,
    HistoryResultStatus? resultStatus,
    int? httpStatus,
    String? errorMessage,
    String? userId,
    String? userName,
    String? receptionNo,
    String? companyName,
    String? siteName,
    String? subject,
    String? linkMode,
    int? createdAtMs,
  }) async {
    try {
      final resolvedStatus =
          resultStatus ?? OperationHistory.aggregateResult(items);

      final firstFailed = items.cast<OperationHistoryItem?>().firstWhere(
            (i) => i?.resultStatus == ItemResultStatus.failed,
            orElse: () => null,
          );

      final code = userId ?? await EmployeeStorage.getCode();
      final name = userName ?? await EmployeeStorage.getName();

      final history = OperationHistory(
        createdAtMs:
            createdAtMs ?? DateTime.now().toUtc().millisecondsSinceEpoch,
        operationType: operationType,
        resultStatus: resolvedStatus,
        httpStatus: httpStatus ?? firstFailed?.httpStatus,
        errorMessage: errorMessage ?? firstFailed?.errorMessage,
        environment: currentEnvironment(),
        userId: code,
        userName: name,
        receptionNo: receptionNo,
        companyName: companyName,
        siteName: siteName,
        subject: subject,
        linkMode: linkMode,
        items: items,
      );

      await _repository.insert(history);
    } catch (e, st) {
      _logSaveFailure(e, st);
    }
  }

  /// ステータス更新（複数明細・部分失敗あり）を記録。
  Future<void> recordStatusUpdate({
    required List<OperationHistoryItem> items,
    String? userId,
    String? userName,
  }) {
    return record(
      operationType: OperationType.statusUpdate,
      items: items,
      userId: userId,
      userName: userName,
    );
  }

  /// 伝票紐付けを記録。
  Future<void> recordSlipLink({
    required List<OperationHistoryItem> items,
    required HistoryResultStatus resultStatus,
    required String receptionNo,
    String? companyName,
    String? siteName,
    String? subject,
    String? linkMode,
    int? httpStatus,
    String? errorMessage,
    String? userId,
    String? userName,
  }) {
    return record(
      operationType: OperationType.slipLink,
      items: items,
      resultStatus: resultStatus,
      httpStatus: httpStatus,
      errorMessage: errorMessage,
      receptionNo: receptionNo,
      companyName: companyName,
      siteName: siteName,
      subject: subject,
      linkMode: linkMode,
      userId: userId,
      userName: userName,
    );
  }

  /// タグ新規登録を記録。
  Future<void> recordTagRegistration({
    required OperationHistoryItem item,
    required HistoryResultStatus resultStatus,
    int? httpStatus,
    String? errorMessage,
    String? userId,
    String? userName,
  }) {
    return record(
      operationType: OperationType.tagRegistration,
      items: [item],
      resultStatus: resultStatus,
      httpStatus: httpStatus,
      errorMessage: errorMessage,
      userId: userId,
      userName: userName,
    );
  }

  /// タグID再設定（EPC 書換え）を記録。
  Future<void> recordEpcUpdate({
    required OperationHistoryItem item,
    required HistoryResultStatus resultStatus,
    String? errorMessage,
    String? userId,
    String? userName,
  }) {
    return record(
      operationType: OperationType.epcUpdate,
      items: [item],
      resultStatus: resultStatus,
      errorMessage: errorMessage,
      userId: userId,
      userName: userName,
    );
  }

  /// 直近 10 日分を取得（先に purge してから返す）。
  Future<List<OperationHistory>> listRecent({bool purgeFirst = true}) async {
    try {
      if (purgeFirst) await purgeOlderThanRetention();
      return await _repository.listRecent();
    } catch (e, st) {
      _logSaveFailure(e, st, context: 'listRecent');
      return const [];
    }
  }

  /// 10 日より古い履歴を削除。
  Future<void> purgeOlderThanRetention() async {
    try {
      await _repository.purgeOlderThan();
    } catch (e, st) {
      _logSaveFailure(e, st, context: 'purge');
    }
  }

  void _logSaveFailure(Object e, StackTrace st, {String context = 'save'}) {
    final msg = 'OperationHistoryService $context failed: $e';
    debugPrint(msg);
    developer.log(msg, name: 'OperationHistory', error: e, stackTrace: st);
  }
}
