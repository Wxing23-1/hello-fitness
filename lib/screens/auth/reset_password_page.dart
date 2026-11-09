import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// 设置新密码页
///
/// 找回密码流程的最后一步：用户点了重置邮件里的链接后，
/// AuthGate 检测到 passwordRecovery 事件就显示本页，
/// 让用户输入新密码，调 AuthService.updatePassword 完成重置。
class ResetPasswordPage extends StatefulWidget {
  /// 重置成功后回调（AuthGate 用来切回正常流程）
  final VoidCallback onDone;

  const ResetPasswordPage({super.key, required this.onDone});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (password.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }
    if (password != confirm) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await AuthService.updatePassword(password);

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已更新')),
      );
      widget.onDone();
    } else {
      setState(() {
        _busy = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('设置新密码'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Icon(Icons.lock_reset, size: 56, color: Colors.blue.shade300),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '为你的账号设置一个新密码',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),

          // 新密码
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '新密码',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 确认密码
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: '确认新密码',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],

          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('确认修改'),
          ),
        ],
      ),
    );
  }
}
