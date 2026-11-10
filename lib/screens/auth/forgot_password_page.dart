import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// 找回密码页（邮箱验证码流程）
///
/// 三步走，全程在本页完成，不依赖邮件链接：
///   1. 填邮箱 → 发送验证码
///   2. 填验证码 → 校验（通过后进入重置会话）
///   3. 填新密码 → 确认修改
///
/// 改完自动返回上一页（登录页），此时已登录，AuthGate 会切到主界面。
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// 0=填邮箱，1=填验证码，2=填新密码
  int _step = 0;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// 第一步：发送验证码
  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final result = await AuthService.sendPasswordResetCode(email);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result.success) {
        _step = 1;
        _info = '验证码已发送到 $email，请查收';
      } else {
        _error = result.error;
      }
    });
  }

  /// 第二步：校验验证码
  Future<void> _verifyCode() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入验证码');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await AuthService.verifyPasswordResetCode(email, code);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result.success) {
        _step = 2;
        _error = null;
        _info = null;
      } else {
        _error = result.error;
      }
    });
  }

  /// 第三步：设置新密码
  Future<void> _submitPassword() async {
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
      Navigator.of(context).pop();
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
        title: const Text('找回密码'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Icon(Icons.lock_reset, size: 56, color: Colors.blue.shade300),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '通过邮箱验证码重置密码',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),

          // ── 邮箱（一直显示）──
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            enabled: _step == 0, // 发完码就锁定，避免中途改邮箱
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          if (_info != null) ...[
            Text(
              _info!,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],

          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],

          // ── 第一步：发送验证码 ──
          if (_step == 0)
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('发送验证码'),
            ),

          // ── 第二步：填验证码 ──
          if (_step >= 1) ...[
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '验证码',
                prefixIcon: Icon(Icons.pin_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _verifyCode,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('验证'),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('重新发送'),
                ),
              ],
            ),
          ],

          // ── 第三步：设置新密码 ──
          if (_step == 2) ...[
            const SizedBox(height: 16),
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
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              onSubmitted: (_) => _busy ? null : _submitPassword(),
              decoration: const InputDecoration(
                labelText: '确认新密码',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submitPassword,
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
        ],
      ),
    );
  }
}
