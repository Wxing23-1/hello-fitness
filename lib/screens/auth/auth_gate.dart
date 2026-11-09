import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/main_screen.dart';
import 'auth_page.dart';
import 'reset_password_page.dart';

/// 登录门卫
///
/// 决定启动时先显示什么：
///   - 已登录 → 直接进主界面
///   - 未登录 → 先进登录/注册页，登录成功后再进主界面
///
/// Supabase 未初始化（单元测试）时直接放行进主界面，
/// 这样既有测试不依赖云端就能跑。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// null = Supabase 不可用（测试环境），直接放行；true/false = 登录态
  bool? _signedIn;

  /// 用户是否点了「暂不登录，随便看看」
  bool _skipped = false;

  /// 是否处于「找回密码」流程（点了重置邮件里的链接）
  bool _recovering = false;

  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _signedIn = _initialSignedIn();
    _listen();
  }

  bool? _initialSignedIn() {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return null; // 未初始化
    }
  }

  void _listen() {
    try {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        setState(() {
          // 找回密码：点了重置邮件里的链接，先让用户设新密码，别直接进主界面
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _recovering = true;
            return;
          }
          final signedIn = state.session != null;
          _signedIn = signedIn;
          // 登录成功后清掉跳过标志，这样之后登出会正常回到登录页
          if (signedIn) _skipped = false;
        });
      });
    } catch (_) {
      // 未初始化，忽略
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 找回密码：优先显示设置新密码页，改完 onDone 里切回正常流程
    if (_recovering) {
      return ResetPasswordPage(
        onDone: () => setState(() {
          _recovering = false;
          _signedIn = _initialSignedIn();
        }),
      );
    }
    // Supabase 不可用（测试）直接进主界面
    if (_signedIn == null) return const MainScreen();
    // 已登录 → 主界面
    if (_signedIn!) return const MainScreen();
    // 未登录但点了跳过 → 也进主界面（本地功能可用，不云同步）
    if (_skipped) return const MainScreen();

    return AuthPage(onSkip: () => setState(() => _skipped = true));
  }
}
