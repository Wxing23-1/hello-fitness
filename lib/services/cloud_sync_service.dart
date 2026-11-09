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
      // from('profiles') 选表，upsert = 有这条(id 相同)就更新、没有就插入。
      // 字段名是建表 SQL 里的 snake_case（height_cm），和 Dart 的驼峰不一样。
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
      // 链式查询：from 选表 → select 取全部列 → eq 按 id 过滤 → maybeSingle 取一行（没有返回 null，不报错）
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
      // 每条日志整份存进 jsonb 的 data 列，省得为每个字段建列。
      // 行结构：{ id, user_id, data }，id 是本地生成的那串，跨设备也唯一。
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

      // upsert 按主键 id 冲突时覆盖，所以同一批推多次也不会重复
      await client.from(table).upsert(rows);
    } catch (_) {}
  }

  /// 拉取云端全部条目，返回 data 字段列表
  static Future<List<Map<String, dynamic>>> pullItems(String table) async {
    final client = _client;
    if (client == null) return [];

    try {
      // select('data') 只取 data 这一列，返回 [{data: {...}}, ...]，比取整行省流量
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
      final path = '$uid/avatar'; // 路径带 uid，天然隔离：每人只存自己那一份
      // storage.from('avatars') 选桶 → uploadBinary 传字节流。
      // upsert:true 表示同名就覆盖，所以换头像不用先删旧的。
      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      // 桶是 public 的，拿到公开 URL 就能直接放进 Image 组件显示
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
