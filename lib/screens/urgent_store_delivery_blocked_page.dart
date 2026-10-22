import 'package:flutter/material.dart';

/// iOS prod など、急ぎ来店納品を開けないときの案内。
class UrgentStoreDeliveryBlockedPage extends StatelessWidget {
  const UrgentStoreDeliveryBlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) navigator.pop();
                  },
                  child: const Text('戻る'),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'この環境では急ぎ来店納品を使用できません。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
