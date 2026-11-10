import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_profile.dart';
import '../models/fitness_goal.dart';
import '../models/workout_record.dart';

/// 本地存储服务
///
/// 用 Hive 把用户数据存到设备上，APP 重启后数据还在。
///
/// 为什么用 Hive 而不是 SQLite：
/// 这些数据都是「整体读写」的（一份资料、一份目标、一个记录列表），
/// 不需要复杂查询和表关联，键值对存储更简单，也不用写 SQL。
///
/// 为什么不用 Hive 的 TypeAdapter 代码生成：
/// 那需要 build_runner 跑代码生成，多一道构建步骤。
/// 这里数据结构简单，手写 toMap/fromMap 更直观，也少一个依赖。
///
/// Week 3-4 接 Firebase 后，这一层会变成「本地缓存 + 云端同步」：
/// 写入时同时写本地和 Firestore，读取时优先读本地（快），后台拉云端更新。
class LocalStorage {
  /// Hive 的 box 名称，相当于数据库里的一张表
  static const String _boxName = 'fitness_data';

  /// 各项数据在 box 里的 key
  static const String _keyProfile = 'profile';
  static const String _keyGoal = 'goal';
  static const String _keyRecords = 'records';
  static const String _keyFavorites = 'favorites';
  static const String _keySettings = 'settings';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyAiPlans = 'ai_plans';
  static const String _keyWorkoutLogs = 'workout_logs';
  static const String _keyActivePlan = 'active_plan_id';
  static const String _keySessionDraft = 'session_draft';
  static const String _keyMeals = 'meal_entries';
  static const String _keyCustomFoods = 'custom_foods';
  static const String _keyWeightLogs = 'weight_logs';
  static const String _keyActivityLevel = 'activity_level';
  static const String _keyProfileUpdatedAt = 'profile_updated_at';

  /// 标记是否已经初始化过，防止重复 init
  static bool _initialized = false;

  /// 打开的 box，所有读写都通过它
  static Box? _box;

  /// 初始化 Hive
  ///
  /// 必须在 runApp 之前调用（main 函数里）。
  /// Web 平台 Hive 会自动用 IndexedDB，移动端用文件，这里不用区分。
  static Future<void> init() async {
    if (_initialized) return; // 已经初始化过就直接返回

    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _initialized = true;
  }

  /// 是否已初始化
  ///
  /// 单元测试里不初始化 Hive，所以 store 读写时要先检查，
  /// 没初始化就跳过存储，只在内存里操作
  static bool get isReady => _initialized && _box != null;

  // ═══════════════════════════════════════════════════
  //  用户资料
  // ═══════════════════════════════════════════════════

  /// 保存用户资料
  static Future<void> saveProfile(UserProfile profile) async {
    if (!isReady) return;
    await _box!.put(_keyProfile, profile.toMap());
  }

  /// 读取用户资料，没存过就返回 null
  static UserProfile? loadProfile() {
    if (!isReady) return null;

    final map = _box!.get(_keyProfile);
    if (map == null) return null;

    // 存储的数据可能因为版本升级而格式不符，解析失败就当作没有数据，
    // 让调用方退回默认值，而不是让整个 APP 崩在启动阶段
    try {
      return UserProfile.fromMap(map as Map);
    } catch (_) {
      return null;
    }
  }

  /// 保存「资料包」最后修改时间（云同步冲突判断用）
  ///
  /// 资料包 = profile + goal + settings + activityLevel，这些是一整行同步的。
  /// 每次本地修改或从云端拉取后都会更新，用于登录时判断「本地新还是云端新」。
  static Future<void> saveProfileUpdatedAt(String iso) async {
    if (!isReady) return;
    await _box!.put(_keyProfileUpdatedAt, iso);
  }

  /// 读取资料包最后修改时间，没存过返回 null
  static String? loadProfileUpdatedAt() {
    if (!isReady) return null;
    return _box!.get(_keyProfileUpdatedAt) as String?;
  }

  // ═══════════════════════════════════════════════════
  //  健身目标
  // ═══════════════════════════════════════════════════

  static Future<void> saveGoal(FitnessGoal goal) async {
    if (!isReady) return;
    await _box!.put(_keyGoal, goal.toMap());
  }

  static FitnessGoal? loadGoal() {
    if (!isReady) return null;

    final map = _box!.get(_keyGoal);
    if (map == null) return null;

    try {
      return FitnessGoal.fromMap(map as Map);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  //  训练记录
  // ═══════════════════════════════════════════════════

  /// 保存训练记录列表
  ///
  /// 整个列表一起存。记录数量在几百条以内时这样最简单，
  /// 真要上千条再改成按 id 单独存
  static Future<void> saveRecords(List<WorkoutRecord> records) async {
    if (!isReady) return;
    await _box!.put(_keyRecords, records.map((r) => r.toMap()).toList());
  }

  /// 读取训练记录列表，没存过就返回 null
  ///
  /// 注意区分 null 和空列表：
  /// null = 从没存过（首次安装），应该填充演示数据
  /// 空列表 = 用户主动清空了，要尊重这个选择，不能又塞演示数据回去
  static List<WorkoutRecord>? loadRecords() {
    if (!isReady) return null;

    final list = _box!.get(_keyRecords);
    if (list == null) return null;

    try {
      return (list as List)
          .map((m) => WorkoutRecord.fromMap(m as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  //  收藏课程
  // ═══════════════════════════════════════════════════

  /// 保存收藏的课程 id 集合
  ///
  /// Set 不能直接存，转成 List
  static Future<void> saveFavorites(Set<String> ids) async {
    if (!isReady) return;
    await _box!.put(_keyFavorites, ids.toList());
  }

  static Set<String>? loadFavorites() {
    if (!isReady) return null;

    final list = _box!.get(_keyFavorites);
    if (list == null) return null;

    try {
      return (list as List).map((e) => e as String).toSet();
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  //  系统设置
  // ═══════════════════════════════════════════════════

  /// 保存所有设置项
  ///
  /// 设置项都是简单类型，打包成一个 Map 一起存
  static Future<void> saveSettings({
    required bool darkMode,
    required bool workoutReminder,
    required bool waterReminder,
    required String unitSystem,
  }) async {
    if (!isReady) return;
    await _box!.put(_keySettings, {
      'darkMode': darkMode,
      'workoutReminder': workoutReminder,
      'waterReminder': waterReminder,
      'unitSystem': unitSystem,
    });
  }

  /// 读取设置项，没存过就返回 null
  static Map<String, dynamic>? loadSettings() {
    if (!isReady) return null;

    final map = _box!.get(_keySettings);
    if (map == null) return null;

    try {
      final m = map as Map;
      return {
        'darkMode': m['darkMode'] as bool? ?? false,
        'workoutReminder': m['workoutReminder'] as bool? ?? true,
        'waterReminder': m['waterReminder'] as bool? ?? false,
        'unitSystem': m['unitSystem'] as String? ?? '公制',
      };
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  //  AI API Key
  // ═══════════════════════════════════════════════════

  /// 保存 API Key
  ///
  /// 注意：Hive 的数据在设备上是明文存储的，不适合存高价值密钥。
  /// 这里是用户自己的个人 key，泄露风险由用户自己承担，可以接受。
  /// 如果以后要存服务端密钥，得换 flutter_secure_storage。
  static Future<void> saveApiKey(String key) async {
    if (!isReady) return;
    await _box!.put(_keyApiKey, key);
  }

  /// 读取 API Key，没存过返回空字符串
  static String loadApiKey() {
    if (!isReady) return '';
    return _box!.get(_keyApiKey) as String? ?? '';
  }

  // ═══════════════════════════════════════════════════
  //  AI 生成的计划
  // ═══════════════════════════════════════════════════

  /// 保存 AI 生成的计划列表（存 JSON 字符串）
  static Future<void> saveAiPlans(List<String> plansJson) async {
    if (!isReady) return;
    await _box!.put(_keyAiPlans, plansJson);
  }

  /// 读取 AI 生成的计划
  static List<String> loadAiPlans() {
    if (!isReady) return [];

    final list = _box!.get(_keyAiPlans);
    if (list == null) return [];

    try {
      return (list as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  //  当前选中的计划
  // ═══════════════════════════════════════════════════

  /// 保存当前计划的 id
  ///
  /// 只存 id 不存整个计划：预置计划在代码里，AI 计划已经单独存了，
  /// 存两份会在计划被修改时产生不一致
  static Future<void> saveActivePlanId(String? id) async {
    if (!isReady) return;

    // 传 null 表示取消选中，直接删掉这个 key
    if (id == null) {
      await _box!.delete(_keyActivePlan);
    } else {
      await _box!.put(_keyActivePlan, id);
    }
  }

  /// 读取当前计划 id，没选过返回 null
  static String? loadActivePlanId() {
    if (!isReady) return null;
    return _box!.get(_keyActivePlan) as String?;
  }

  // ═══════════════════════════════════════════════════
  //  饮食记录
  // ═══════════════════════════════════════════════════

  /// 保存饮食记录列表（存 JSON 字符串）
  static Future<void> saveMeals(List<String> mealsJson) async {
    if (!isReady) return;
    await _box!.put(_keyMeals, mealsJson);
  }

  /// 读取饮食记录
  static List<String> loadMeals() {
    if (!isReady) return [];

    final list = _box!.get(_keyMeals);
    if (list == null) return [];

    try {
      return (list as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  //  用户自定义食物
  // ═══════════════════════════════════════════════════

  /// 保存自定义食物（内置库里没有的，用户自己加的）
  static Future<void> saveCustomFoods(List<String> foodsJson) async {
    if (!isReady) return;
    await _box!.put(_keyCustomFoods, foodsJson);
  }

  /// 读取自定义食物
  static List<String> loadCustomFoods() {
    if (!isReady) return [];

    final list = _box!.get(_keyCustomFoods);
    if (list == null) return [];

    try {
      return (list as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  //  体重记录
  // ═══════════════════════════════════════════════════

  /// 保存体重记录（画体重曲线用）
  static Future<void> saveWeightLogs(List<String> logsJson) async {
    if (!isReady) return;
    await _box!.put(_keyWeightLogs, logsJson);
  }

  /// 读取体重记录
  static List<String> loadWeightLogs() {
    if (!isReady) return [];

    final list = _box!.get(_keyWeightLogs);
    if (list == null) return [];

    try {
      return (list as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  //  活动强度
  // ═══════════════════════════════════════════════════

  /// 保存活动强度等级（存枚举 index）
  static Future<void> saveActivityLevel(int index) async {
    if (!isReady) return;
    await _box!.put(_keyActivityLevel, index);
  }

  /// 读取活动强度，没设过返回 null
  static int? loadActivityLevel() {
    if (!isReady) return null;
    return _box!.get(_keyActivityLevel) as int?;
  }

  // ═══════════════════════════════════════════════════
  //  训练中断草稿
  // ═══════════════════════════════════════════════════

  /// 保存训练草稿（JSON 字符串）
  ///
  /// 每完成一组调一次，所以要够快 —— 只写一个 key，不动别的数据
  static Future<void> saveSessionDraft(String? json) async {
    if (!isReady) return;

    if (json == null) {
      await _box!.delete(_keySessionDraft);
    } else {
      await _box!.put(_keySessionDraft, json);
    }
  }

  /// 读取训练草稿，没有返回 null
  static String? loadSessionDraft() {
    if (!isReady) return null;
    return _box!.get(_keySessionDraft) as String?;
  }

  // ═══════════════════════════════════════════════════
  //  训练完成记录（WorkoutLog）
  // ═══════════════════════════════════════════════════

  /// 保存训练记录列表（存 JSON 字符串）
  static Future<void> saveWorkoutLogs(List<String> logsJson) async {
    if (!isReady) return;
    await _box!.put(_keyWorkoutLogs, logsJson);
  }

  /// 读取训练记录
  static List<String> loadWorkoutLogs() {
    if (!isReady) return [];

    final list = _box!.get(_keyWorkoutLogs);
    if (list == null) return [];

    try {
      return (list as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════
  //  清理
  // ═══════════════════════════════════════════════════

  /// 清空所有本地数据
  ///
  /// 设置页的「恢复默认数据」会调用，连带把存储也清掉，
  /// 否则重启后又会读回旧数据
  static Future<void> clearAll() async {
    if (!isReady) return;
    await _box!.clear();
  }
}
