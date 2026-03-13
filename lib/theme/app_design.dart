import 'package:flutter/material.dart';

/// design/ のワイヤーフレーム（iPhone SE 375px）に合わせたデザイン定数
class AppDesign {
  AppDesign._();

  /// スマホ画面幅（iPhone SE 想定）
  static const double deviceWidth = 375;

  /// 外側の背景色（デバイスフレーム外）
  static const Color scaffoldBackground = Color(0xFF1A1A1A);

  /// ナビゲーションバー背景
  static const Color navBarBackground = Color(0xFFF8F8F8);

  /// ナビゲーションバー下線
  static const Color navBarBorder = Color(0xFFE0E0E0);

  /// 戻るボタン・プライマリリンク色（iOS Blue）
  static const Color primaryLink = Color(0xFF007AFF);

  /// プライマリボタン背景
  static const Color primaryButton = Color(0xFF007AFF);

  /// 読取停止・危険ボタン
  static const Color stopButton = Color(0xFFFF3B30);

  /// 送信・成功ボタン
  static const Color sendButton = Color(0xFF34C759);

  /// 無効ボタン
  static const Color disabledButton = Color(0xFF999999);

  /// 読取コントロール・取得バー背景
  static const Color controlBarBackground = Color(0xFFF0F4F8);

  /// 送信待ちバー背景
  static const Color pendingBarBackground = Color(0xFFFFF8E6);

  static const Color pendingBarBorder = Color(0xFFE8DCA0);

  /// 選択中・送信選択の左ボーダー
  static const Color selectedBorder = Color(0xFF1976D2);

  static const Color selectedBackground = Color(0xFFE3F2FD);

  /// 送信選択した商品の背景（薄い緑）
  static const Color selectedForSendBackground = Color(0xFFD4EDDA);

  /// 紐付け済・成功系
  static const Color linkedBackground = Color(0xFFE8F5E9);

  static const Color linkedBorder = Color(0xFFC8E6C9);

  /// ステータスバッジ色
  static const Color statusOk = Color(0xFF2E7D32);
  static const Color statusOkBg = Color(0xFFE8F5E9);
  static const Color statusUnknown = Color(0xFFC62828);
  static const Color statusUnknownBg = Color(0xFFFFEBEE);
  static const Color statusLent = Color(0xFF1565C0);
  static const Color statusLentBg = Color(0xFFE3F2FD);
  static const Color statusCleaning = Color(0xFFE65100);
  static const Color statusCleaningBg = Color(0xFFFFF3E0);
  static const Color statusMaintenance = Color(0xFFC2185B);
  static const Color statusMaintenanceBg = Color(0xFFFCE4EC);
  static const Color statusRepair = Color(0xFFC62828);
  static const Color statusRepairBg = Color(0xFFFFEBEE);
  static const Color statusDisposed = Color(0xFF546E7A);
  static const Color statusDisposedBg = Color(0xFFECEFF1);

  /// ノッチ高さ（デバイス上部の黒い部分）
  static const double notchHeight = 34;

  /// 電波強度メーター・ボタン用（緑）
  static const Color radioPowerMeterGreen = Color(0xFF8BC34A);
}
