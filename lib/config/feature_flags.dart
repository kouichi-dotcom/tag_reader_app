import 'package:flutter/foundation.dart';

import 'api_config.dart';

/// 未完成機能の公開状態。実行中に利用者は変更できない。
enum AppFeature {
  urgentStoreDelivery,
}

/// テストからプラットフォームと環境の組み合わせを渡すための判定。
/// 環境の正しさは [kAppEnvValidation] / [kIsProdFlavor] の結果を受け取る。
bool isAppFeatureEnabled(
  AppFeature feature, {
  required bool isIos,
  required bool envValid,
  required bool isProdFlavor,
}) {
  switch (feature) {
    case AppFeature.urgentStoreDelivery:
      if (!envValid) return false;
      if (isIos && isProdFlavor) return false;
      return true;
  }
}

/// ウィジェットテスト用。本番の起動経路では null のままにする。
@visibleForTesting
bool? debugUrgentStoreDeliveryOverride;

/// 急ぎ来店納品を出してよいか。
/// iOS の prod だけ不可。不正な環境設定も不可。Android は Flavor に関わらず可。
bool get enableUrgentStoreDelivery {
  final override = debugUrgentStoreDeliveryOverride;
  if (override != null) return override;
  return isAppFeatureEnabled(
    AppFeature.urgentStoreDelivery,
    isIos: defaultTargetPlatform == TargetPlatform.iOS,
    envValid: kAppEnvValidation.isValid,
    isProdFlavor: kIsProdFlavor,
  );
}
