import 'package:supabase_flutter/supabase_flutter.dart';

/// 一次认证操作的结果
///
/// 和 AI 服务的返回风格一致：不抛异常，用 error 字段告诉调用方出了什么问题。
class AuthResult {
  final bool success;
  final String? error;

  const AuthResult.ok() : success = true, error = null;
  const AuthResult.fail(this.error) : success = false;
}

/// Supabase 账号服务
///
/// 封装注册 / 登录 / 登出 / 登录态查询。
/// 全部走静态方法，页面用 `context.read<UserStore>()` 触发后，
/// 由 UserStore 里的 authStateChanges 监听更新登录态。
class AuthService {
  AuthService._();

  /// 当前登录用户，没登录是 null
  static User? get currentUser {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      // Supabase 未初始化（单元测试场景）时返回 null
      return null;
    }
  }

  /// 当前用户 id，没登录是 null
  static String? get currentUserId => currentUser?.id;

  /// 是否已登录
  static bool get isSignedIn => currentUser != null;

  /// 邮箱注册
  ///
  /// 返回结果；成功不代表已登录 —— 若后台开了「确认邮箱」，
  /// 需要用户点邮件里的链接后才算登录成功。
  static Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (res.user == null) {
        return const AuthResult.fail('注册失败，请稍后再试');
      }
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_friendly(e.message));
    } catch (_) {
      return const AuthResult.fail('网络错误，请检查连接');
    }
  }

  /// 邮箱登录
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_friendly(e.message));
    } catch (_) {
      return const AuthResult.fail('网络错误，请检查连接');
    }
  }

  /// 登出
  static Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // 登出失败不致命，忽略即可
    }
  }

  /// 用新密码更新当前用户密码（找回密码流程的最后一步）
  ///
  /// 调用前提：当前是密码重置会话（用户点了重置邮件里的链接后）。
  /// 成功后不用重新登录，当前会话仍然有效。
  static Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_friendly(e.message));
    } catch (_) {
      return const AuthResult.fail('网络错误，请检查连接');
    }
  }

  /// 发送找回密码邮件
  ///
  /// 成功后 Supabase 会往这个邮箱发一封带重置链接的邮件，
  /// 用户点链接即可设置新密码。
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
      return const AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(_friendly(e.message));
    } catch (_) {
      return const AuthResult.fail('网络错误，请检查连接');
    }
  }

  /// 把 Supabase 返回的英文错误转成中文提示
  static String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) return '邮箱或密码错误';
    if (m.contains('already registered')) return '该邮箱已注册';
    if (m.contains('email not confirmed')) return '邮箱未验证，请先点击邮件里的链接';
    if (m.contains('password should be at least')) return '密码太短，至少 6 位';
    if (m.contains('valid email')) return '邮箱格式不正确';
    return message;
  }
}
