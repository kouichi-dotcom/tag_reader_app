import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../services/employee_cache.dart';
import '../services/employee_storage.dart';
import '../theme/app_design.dart';

/// 従業員コード入力画面
/// コード入力後、対応する従業員名を保存しホームで表示する
class EmployeeCodeScreen extends StatefulWidget {
  const EmployeeCodeScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<EmployeeCodeScreen> createState() => _EmployeeCodeScreenState();
}

class _EmployeeCodeScreenState extends State<EmployeeCodeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _errorMessage = null;
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = '担当者コードを入力してください。');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ApiClient(baseUrl: kApiBaseUrl);
      await EmployeeCache.instance.ensureInitialLoaded(api);
      if (!mounted) return;
      final name = await EmployeeCache.instance.resolveName(api, code);
      if (!mounted) return;
      if (name == null) {
        setState(() {
          _saving = false;
          _errorMessage = '該当する担当者が見つかりません。（コード: $code）';
        });
        return;
      }
      await EmployeeStorage.save(code, name);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = '通信エラー: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.scaffoldBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDesign.deviceWidth),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppDesign.navBarBackground,
                    border: Border(bottom: BorderSide(color: AppDesign.navBarBorder, width: 1)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        if (widget.showBackButton)
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppDesign.primaryLink,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('← 戻る', style: TextStyle(fontSize: 16)),
                          )
                        else
                          const SizedBox(width: 52),
                        const Expanded(
                          child: Text(
                            '担当者コード入力',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 52),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '担当者コードを入力してください。\n入力後、ホーム画面に担当者氏名が表示され、伝票・商品更新時に誰が記録したかとして送信されます。',
                            style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: '担当者コード（必須）',
                              hintText: '例: 1 または 001',
                              border: OutlineInputBorder(),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _save(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return '担当者コードを入力してください。';
                              return null;
                            },
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 13, color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppDesign.primaryButton,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(_saving ? '保存中…' : '保存してホームに戻る'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
