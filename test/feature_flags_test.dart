import 'package:flutter_test/flutter_test.dart';
import 'package:tag_reader_app/config/feature_flags.dart';

void main() {
  bool enabled({
    required bool isIos,
    required bool envValid,
    required bool isProdFlavor,
  }) {
    return isAppFeatureEnabled(
      AppFeature.urgentStoreDelivery,
      isIos: isIos,
      envValid: envValid,
      isProdFlavor: isProdFlavor,
    );
  }

  test('急ぎ来店納品は iOS prod だけ不可', () {
    expect(enabled(isIos: true, envValid: true, isProdFlavor: false), isTrue);
    expect(enabled(isIos: true, envValid: true, isProdFlavor: true), isFalse);
    expect(enabled(isIos: false, envValid: true, isProdFlavor: false), isTrue);
    expect(enabled(isIos: false, envValid: true, isProdFlavor: true), isTrue);
  });

  test('環境設定が不正なときはプラットフォームに関わらず不可', () {
    expect(enabled(isIos: true, envValid: false, isProdFlavor: false), isFalse);
    expect(enabled(isIos: true, envValid: false, isProdFlavor: true), isFalse);
    expect(enabled(isIos: false, envValid: false, isProdFlavor: false), isFalse);
    expect(enabled(isIos: false, envValid: false, isProdFlavor: true), isFalse);
  });
}
