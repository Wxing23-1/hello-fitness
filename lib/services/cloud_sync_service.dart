import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../models/user_profile.dart';
import '../models/fitness_goal.dart';
import 'auth_service.dart';

/// 云同步服务
///
/// 登录后把本地数据推到 Supabase，换设备时拉回来。
/// 策略：
///   - profile/goal/settings 是「单份」，整行 upsert，登录时云端覆盖本地
///   - workout_logs / meal_entries / weight_logs 是「日志列表」，按 id 合并取并集
///
/// 所有方法都 try-catch：Supabase 未初始化（单元测试）或网络失败时
/// 静默跳过，本地功能照常工作，不影响离线使用。
class CloudSyncService {
  CloudSyncService._();

  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// 当前是否具备云同步条件（已初始化 + 已登录）
  static bool get available =>
      _client != null && AuthService.currentUserId != null;

  // ═══════════════════════════════════════════════════════
  //  用户资料 + 目标 + 设置（单份 upsert）
  // ═══════════════════════════════════════════════════════

  /// 把本地资料整行推到云端
  static Future<void> pushProfile({
    required UserProfile profile,
    required FitnessGoal goal,
    required bool darkMode,
    required bool workoutReminder,
    required bool waterReminder,
    required String unitSystem,
    required int activityLevel,
  }) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return;

    try {
      await client.from('profiles').upsert({
        'id': uid,
        'name': profile.name,
        'gender': profile.gender.index,
        'age': profile.age,
        'height_cm': profile.heightCm,
        'weight_kg': profile.weightKg,
        'bio': profile.bio,
        'avatar_url': profile.avatarUrl,
        'goal_type': goal.type.index,
        'target_weight_kg': goal.targetWeightKg,
        'weekly_workouts': goal.weeklyWorkouts,
        'daily_calories': goal.dailyCalories,
        'daily_water_ml': goal.dailyWaterMl,
        'activity_level': activityLevel,
        'dark_mode': darkMode,
        'workout_reminder': workoutReminder,
        'water_reminder': waterReminder,
        'unit_system': unitSystem,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // 网络失败静默跳过
    }
  }

  /// 从云端拉取资料，没有记录返回 null
  static Future<Map<String, dynamic>?> pullProfile() async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return null;

    try {
      final rows = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (rows == null) return null;
      return (rows as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// 只更新头像地址（上传完成后写回，避免整行重复 upsert）
  static Future<void> updateAvatarUrl(String? url) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return;

    try {
      await client
          .from('profiles')
          .update({'avatar_url': url, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', uid);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  //  日志列表（workout_logs / meal_entries / weight_logs）
  // ═══════════════════════════════════════════════════════

  /// 把一整批条目 upsert 到云端（按 id 去重合并）
  static Future<void> pushItems(
    String table,
    List<Map<String, dynamic>> items, {
    DateTime? eatenAt,
  }) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null || items.isEmpty) return;

    try {
      final rows = items.map((data) {
        final row = <String, dynamic>{
          'id': data['id'],
          'user_id': uid,
          'data': data,
        };
        if (eatenAt != null) {
          row['eaten_at'] = eatenAt.toUtc().toIso8601String();
        }
        return row;
      }).toList();

      await client.from(table).upsert(rows);
    } catch (_) {}
  }

  /// 拉取云端全部条目，返回 data 字段列表
  static Future<List<Map<String, dynamic>>> pullItems(String table) async {
    final client = _client;
    if (client == null) return [];

    try {
      final rows = await client.from(table).select('data');
      return (rows as List)
          .map((r) => (r['data'] as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  //  头像上传 / 删除
  // ═══════════════════════════════════════════════════════

  /// 上传头像图片，返回公开访问 URL
  ///
  /// 路径固定为 `{userId}/avatar`，重复上传会覆盖旧图。
  static Future<String?> uploadAvatar(Uint8List bytes) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return null;

    try {
      final path = '$uid/avatar';
      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return client.storage.from('avatars').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// 删除头像（回到默认占位图标）
  static Future<void> deleteAvatar() async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return;

    try {
      await client.storage.from('avatars').remove(['$uid/avatar']);
    } catch (_) {}
  }
}
