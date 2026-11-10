import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/user_store.dart';
import 'forgot_password_page.dart';

/// 登录 / 注册页
///
/// 一个页面两个模式，靠 _isRegister 切换。
/// 成功后直接返回上一页 —— 登录态由 UserStore 里的 authStateChanges 监听
/// 感知并触发云同步，页面自己不用处理。
class AuthPage extends StatefulWidget {
  /// 点「暂不登录」时的回调（由 AuthGate 传入，用于跳过登录直接进主界面）
  final VoidCallback? onSkip;

  const AuthPage({super.key, this.onSkip});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写邮箱和密码');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = _isRegister
        ? await AuthService.signUp(email: email, password: password)
        : await AuthService.signIn(email: email, password: password);

    if (!mounted) return;

    if (result.success) {
      // 登录成功；注册成功但后台开了邮箱确认时提示去验证
      if (_isRegister && !context.read<UserStore>().isSignedIn) {
        setState(() {
          _busy = false;
          _error = '注册成功，请先到邮箱点击验证链接，再回来登录';
        });
        return;
      }
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = result.error;
      });
    }
  }

  /// 忘记密码：跳到「邮箱验证码」找回密码页
  Future<void> _forgotPassword() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_isRegister ? '注册账号' : '登录'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.fitness_center,
            size: 56,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '登录后数据云端同步，换设备不丢',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),

          // 邮箱
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 密码
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: '密码',
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
                : Text(_isRegister ? '注册并登录' : '登录'),
          ),

          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _isRegister = !_isRegister;
                      _error = null;
                    }),
            child: Text(_isRegister ? '已有账号？去登录' : '没有账号？去注册'),
          ),
          // 登录模式才显示忘记密码
          if (!_isRegister)
            TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: const Text('忘记密码？'),
            ),
          if (widget.onSkip != null)
            TextButton(
              onPressed: _busy ? null : widget.onSkip,
              child: const Text(
                '暂不登录，随便看看',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
