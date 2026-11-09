// 导入 ChangeNotifier（来自 foundation，比导整个 material 更轻）
import 'package:flutter/foundation.dart';
// hide LocalStorage：supabase_flutter 里也有个同名类，避免和我们的本地存储服务撞名
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import 'dart:convert';

import '../models/user_profile.dart';
import '../models/fitness_goal.dart';
import '../models/workout_record.dart';
import '../models/course.dart';
import '../models/training_plan.dart';
import '../data/food_database.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/session_draft.dart';
import '../models/weight_log.dart';
import '../utils/nutrition_utils.dart';
import '../models/workout_log.dart';
import '../data/preset_plans.dart';
import 'local_storage.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';

/// 全局数据仓库
///
/// 个人中心5个模块的数据都存在这里，由 provider 注入到组件树，
/// 任何页面都能读写，改完数据所有相关界面自动刷新。
///
/// 继承 ChangeNotifier 的意思是：这个类能对外「广播变化」。
/// 每个修改方法的最后都要调 notifyListeners()，
/// 否则数据变了但界面不会重建 —— 这是用 provider 最容易踩的坑。
///
/// 数据持久化：所有修改都会写进 Hive 本地存储，APP 重启后数据还在。
/// 构造时自动从存储加载，没有存过的项用默认值。
/// 等 Week 2 接上 Firestore 后，在 _persistXxx 方法里加云端写入即可。
class UserStore extends ChangeNotifier {
  /// 构造时立刻从本地存储恢复数据
  ///
  /// LocalStorage 没初始化时（比如单元测试）所有 load 都返回 null，
  /// 这时就用默认值，行为和以前一样
  UserStore() {
    _loadFromStorage();
    _watchAuth();
  }

  /// 监听登录态变化
  ///
  /// 用户登录（含启动时已登录）就拉云端数据合并进本地；
  /// 登出不动本地数据，切回纯本地模式。
  /// Supabase 未初始化（单元测试）时静默跳过。
  ///
  /// 注意三种事件都要处理：
  /// - signedIn：表单登录成功
  /// - initialSession：启动时恢复了已保存的会话（重开 APP 没重新登录）
  /// - passwordRecovery：点了重置邮件里的链接
  /// 三者都代表「已登录」，都要拉一次云端，否则重开后看不到云端资料。
  void _watchAuth() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.session == null) return;
        final e = state.event;
        if (e == AuthChangeEvent.signedIn ||
            e == AuthChangeEvent.initialSession ||
            e == AuthChangeEvent.passwordRecovery) {
          _pullFromCloud();
        }
      });
    } catch (_) {
      // 未初始化，忽略
    }
  }

  // ═══════════════════════════════════════════════════
  //  内部状态
  //  下划线开头表示私有，外部只能通过下面的 getter 读取，
  //  不能直接改，必须走修改方法，这样才能保证 notifyListeners 被调用
  // ═══════════════════════════════════════════════════

  UserProfile _profile = UserProfile.initial();
  FitnessGoal _goal = FitnessGoal.initial();
  List<WorkoutRecord> _records = WorkoutRecord.demoRecords();

  /// 所有课程库
  final List<Course> _allCourses = Course.demoCourses();

  /// 已收藏课程的id集合
  ///
  /// 用 Set 而不是 List：判断「有没有收藏过」是 O(1)，而且天然去重
  final Set<String> _favoriteIds = {'c1', 'c3', 'c5'};

  // ── 系统设置项 ──
  bool _darkMode = false; // 深色模式
  bool _workoutReminder = true; // 训练提醒
  bool _waterReminder = false; // 喝水提醒
  String _unitSystem = '公制'; // 单位制：公制(kg/cm) 或 英制(lb/inch)

  /// AI 服务的 API Key，用户在设置页自己填
  String _aiApiKey = '';

  /// AI 生成的训练计划列表
  List<TrainingPlan> _aiPlans = [];

  /// 训练完成记录（按计划训练生成的详细记录）
  List<WorkoutLog> _workoutLogs = [];

  /// 当前选中的计划 id，没选过是 null
  ///
  /// 只存 id：预置计划定义在代码里，AI 计划已经单独持久化了，
  /// 再存一份计划内容会在计划变更时产生两份不一致的数据
  String? _activePlanId;

  /// 预置计划副本的自增序号
  ///
  /// 和时间戳一起拼 id。光用毫秒时间戳，连续两次保存可能撞到同一毫秒，
  /// 导致第二份副本覆盖第一份
  int _planCopyCounter = 0;

  /// 饮食记录
  List<MealEntry> _meals = [];

  /// 用户自定义的食物（内置库里没有的）
  List<FoodItem> _customFoods = [];

  /// 体重记录
  List<WeightLog> _weightLogs = [];

  /// 活动强度，影响每日热量目标的计算
  ActivityLevel _activityLevel = ActivityLevel.light;

  // ═══════════════════════════════════════════════════
  //  持久化
  // ═══════════════════════════════════════════════════

  /// 从本地存储读取所有数据
  ///
  /// 每一项单独判断：某项没存过就保留字段声明时的默认值。
  /// 注意训练记录要区分 null（首次安装）和空列表（用户清空过）
  void _loadFromStorage() {
    final profile = LocalStorage.loadProfile();
    if (profile != null) _profile = profile;

    final goal = LocalStorage.loadGoal();
    if (goal != null) _goal = goal;

    // null 表示从没存过，保留演示数据；空列表表示用户主动清空了，要尊重
    final records = LocalStorage.loadRecords();
    if (records != null) _records = records;

    final favorites = LocalStorage.loadFavorites();
    if (favorites != null) {
      _favoriteIds
        ..clear()
        ..addAll(favorites);
    }

    final settings = LocalStorage.loadSettings();
    if (settings != null) {
      _darkMode = settings['darkMode'] as bool;
      _workoutReminder = settings['workoutReminder'] as bool;
      _waterReminder = settings['waterReminder'] as bool;
      _unitSystem = settings['unitSystem'] as String;
    }

    _aiApiKey = LocalStorage.loadApiKey();

    // AI 计划以 JSON 字符串存储,逐条解析
    // 某一条坏了就跳过它，不影响其他计划
    final plansJson = LocalStorage.loadAiPlans();
    _aiPlans = [];
    for (final json in plansJson) {
      try {
        _aiPlans.add(TrainingPlan.fromMap(jsonDecode(json) as Map));
      } catch (_) {
        // 解析失败的脏数据直接丢弃
      }
    }

    // WorkoutLog 同样以 JSON 存储
    final logsJson = LocalStorage.loadWorkoutLogs();
    _workoutLogs = [];
    for (final json in logsJson) {
      try {
        _workoutLogs.add(WorkoutLog.fromMap(jsonDecode(json) as Map));
      } catch (_) {
        // 解析失败的脏数据直接丢弃
      }
    }

    _activePlanId = LocalStorage.loadActivePlanId();

    // 饮食记录
    _meals = [];
    for (final json in LocalStorage.loadMeals()) {
      try {
        _meals.add(MealEntry.fromMap(jsonDecode(json) as Map));
      } catch (_) {
        // 解析失败的脏数据直接丢弃
      }
    }

    // 自定义食物
    _customFoods = [];
    for (final json in LocalStorage.loadCustomFoods()) {
      try {
        _customFoods.add(FoodItem.fromMap(jsonDecode(json) as Map));
      } catch (_) {
        // 同上
      }
    }

    // 体重记录
    _weightLogs = [];
    for (final json in LocalStorage.loadWeightLogs()) {
      try {
        _weightLogs.add(WeightLog.fromMap(jsonDecode(json) as Map));
      } catch (_) {
        // 同上
      }
    }

    // 活动强度，枚举按 index 存，越界退回默认值
    final levelIdx = LocalStorage.loadActivityLevel();
    if (levelIdx != null &&
        levelIdx >= 0 &&
        levelIdx < ActivityLevel.values.length) {
      _activityLevel = ActivityLevel.values[levelIdx];
    }
  }

  /// 把设置项写进存储
  ///
  /// 4 个开关共用一个存储 key，所以抽出来避免重复
  void _persistSettings() {
    LocalStorage.saveSettings(
      darkMode: _darkMode,
      workoutReminder: _workoutReminder,
      waterReminder: _waterReminder,
      unitSystem: _unitSystem,
    );
    _pushProfile();
  }

  // ═══════════════════════════════════════════════════════
  //  云同步（登录后把本地推到 Supabase，换设备拉回合并）
  // ═══════════════════════════════════════════════════════

  /// 把「资料 + 目标 + 设置 + 活动强度」整行推到云端
  void _pushProfile() {
    CloudSyncService.pushProfile(
      profile: _profile,
      goal: _goal,
      darkMode: _darkMode,
      workoutReminder: _workoutReminder,
      waterReminder: _waterReminder,
      unitSystem: _unitSystem,
      activityLevel: _activityLevel.index,
    );
  }

  /// 登录后从云端拉数据合并进本地
  ///
  /// 单份数据（资料/目标/设置）云端覆盖本地；日志列表按 id 取并集。
  Future<void> _pullFromCloud() async {
    final profile = await CloudSyncService.pullProfile();
    if (profile != null) {
      _applyCloudProfile(profile);
      LocalStorage.saveProfile(_profile);
      LocalStorage.saveGoal(_goal);
      _persistSettings();
      LocalStorage.saveActivityLevel(_activityLevel.index);
    }

    await _syncItems('workout_logs', 'workout_logs');
    await _syncItems('meal_entries', 'meal_entries');
    await _syncItems('weight_logs', 'weight_logs');
    await _syncItems('ai_plans', 'ai_plans');
    await _syncItems('custom_foods', 'custom_foods');

    notifyListeners();
  }

  /// 把云端 profile 行套用到内存（云端优先）
  ///
  /// 枚举（性别/目标/活动强度）在数据库里存的是 int（枚举的 index），
  /// 这里按 index 反查，越界就退回默认值，避免脏数据把界面搞崩。
  void _applyCloudProfile(Map<String, dynamic> p) {
    final genderIdx = p['gender'] as int? ?? 0;
    final gender = (genderIdx >= 0 && genderIdx < Gender.values.length)
        ? Gender.values[genderIdx]
        : Gender.male;
    _profile = UserProfile(
      name: p['name'] as String? ?? _profile.name,
      gender: gender,
      age: (p['age'] as num?)?.toInt() ?? _profile.age,
      heightCm: (p['height_cm'] as num?)?.toDouble() ?? _profile.heightCm,
      weightKg: (p['weight_kg'] as num?)?.toDouble() ?? _profile.weightKg,
      bio: p['bio'] as String? ?? _profile.bio,
      avatarUrl: p['avatar_url'] as String?,
    );

    final goalIdx = p['goal_type'] as int? ?? 0;
    final goalType = (goalIdx >= 0 && goalIdx < GoalType.values.length)
        ? GoalType.values[goalIdx]
        : GoalType.loseWeight;
    _goal = FitnessGoal(
      type: goalType,
      targetWeightKg: (p['target_weight_kg'] as num?)?.toDouble() ??
          _goal.targetWeightKg,
      weeklyWorkouts: (p['weekly_workouts'] as num?)?.toInt() ??
          _goal.weeklyWorkouts,
      dailyCalories:
          (p['daily_calories'] as num?)?.toInt() ?? _goal.dailyCalories,
      dailyWaterMl:
          (p['daily_water_ml'] as num?)?.toInt() ?? _goal.dailyWaterMl,
    );

    _darkMode = p['dark_mode'] as bool? ?? _darkMode;
    _workoutReminder = p['workout_reminder'] as bool? ?? _workoutReminder;
    _waterReminder = p['water_reminder'] as bool? ?? _waterReminder;
    _unitSystem = p['unit_system'] as String? ?? _unitSystem;

    final levelIdx = p['activity_level'] as int?;
    if (levelIdx != null &&
        levelIdx >= 0 &&
        levelIdx < ActivityLevel.values.length) {
      _activityLevel = ActivityLevel.values[levelIdx];
    }
  }

  /// 同步某一类日志：拉云端 + 本地取并集，再写回云端
  ///
  /// table 是 Supabase 表名，kind 标记本地模型类型
  Future<void> _syncItems(String table, String kind) async {
    final cloud = await CloudSyncService.pullItems(table);

    final local = switch (kind) {
      'workout_logs' => _workoutLogs.map((e) => e.toMap()).toList(),
      'meal_entries' => _meals.map((e) => e.toMap()).toList(),
      'weight_logs' => _weightLogs.map((e) => e.toMap()).toList(),
      'ai_plans' => _aiPlans.map((e) => e.toMap()).toList(),
      'custom_foods' => _customFoods.map((e) => e.toMap()).toList(),
      _ => <Map<String, dynamic>>[],
    };

    final merged = _mergeById(local, cloud);

    switch (kind) {
      case 'workout_logs':
        _workoutLogs = merged.map((m) => WorkoutLog.fromMap(m)).toList();
        _persistWorkoutLogs();
      case 'meal_entries':
        _meals = merged.map((m) => MealEntry.fromMap(m)).toList();
        _persistMeals();
      case 'weight_logs':
        _weightLogs = merged.map((m) => WeightLog.fromMap(m)).toList();
        _persistWeightLogs();
      case 'ai_plans':
        _aiPlans = merged.map((m) => TrainingPlan.fromMap(m)).toList();
        _persistAiPlans();
      case 'custom_foods':
        _customFoods = merged.map((m) => FoodItem.fromMap(m)).toList();
        _persistCustomFoods();
    }
  }

  /// 两份列表按 id 取并集（云端在前，本地补充云端没有的）
  List<Map<String, dynamic>> _mergeById(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> cloud,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final m in cloud) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) byId[id] = m;
    }
    for (final m in local) {
      final id = m['id'];
      if (id is String && id.isNotEmpty) byId.putIfAbsent(id, () => m);
    }
    return byId.values.toList();
  }

  // ═══════════════════════════════════════════════════
  //  对外只读访问
  // ═══════════════════════════════════════════════════

  UserProfile get profile => _profile;
  FitnessGoal get goal => _goal;

  /// 是否已登录（决定云同步是否生效、社区能否发帖）
  bool get isSignedIn => AuthService.isSignedIn;

  bool get darkMode => _darkMode;
  bool get workoutReminder => _workoutReminder;
  bool get waterReminder => _waterReminder;
  String get unitSystem => _unitSystem;

  /// AI 服务的 API Key
  String get aiApiKey => _aiApiKey;

  /// 是否已配置 API Key，界面上用它决定要不要显示「去设置」提示
  bool get hasApiKey => _aiApiKey.trim().isNotEmpty;

  /// AI 生成的计划，最新的在前
  List<TrainingPlan> get aiPlans => List.unmodifiable(_aiPlans.reversed);

  /// 训练完成记录，最新的在前
  List<WorkoutLog> get workoutLogs {
    final sorted = [..._workoutLogs]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List.unmodifiable(sorted);
  }

  /// 训练记录列表，按时间从新到旧排序
  ///
  /// 返回 unmodifiable 包装：外部拿到后没法偷偷 add/remove，
  /// 只能调用下面的 addRecord / deleteRecord，保证界面不会漏刷新
  List<WorkoutRecord> get records {
    // 先复制一份再排序，避免直接打乱内部列表的顺序
    final sorted = [..._records]
      ..sort((a, b) => b.date.compareTo(a.date)); // b比a表示降序（新的在前）
    return List.unmodifiable(sorted);
  }

  /// 已收藏的课程列表
  List<Course> get favoriteCourses {
    return List.unmodifiable(
      _allCourses.where((c) => _favoriteIds.contains(c.id)),
    );
  }

  /// 全部课程（收藏页里「添加课程」时要列出所有课程供选择）
  List<Course> get allCourses => List.unmodifiable(_allCourses);

  /// 判断某门课是否已收藏
  bool isFavorite(String courseId) => _favoriteIds.contains(courseId);

  // ═══════════════════════════════════════════════════
  //  派生数据（根据现有数据算出来的，不单独存储）
  // ═══════════════════════════════════════════════════

  /// 累计训练次数
  int get totalWorkouts => _records.length;

  /// 累计训练时长，单位分钟
  int get totalMinutes {
    // fold 是累加：从0开始，把每条记录的时长依次加上去
    return _records.fold(0, (sum, r) => sum + r.durationMinutes);
  }

  /// 累计消耗卡路里
  int get totalCalories {
    return _records.fold(0, (sum, r) => sum + r.calories);
  }

  /// 本周训练次数，用来和目标里的「每周训练次数」做对比
  int get thisWeekWorkouts {
    final now = DateTime.now();
    // weekday：周一=1，周日=7。减掉 (weekday-1) 天就回到本周一
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    // 用 !isBefore 而不是 isAfter：isAfter 是严格大于，
    // 会把周一零点整的记录排除在本周之外
    return _records.where((r) => !r.date.isBefore(monday)).length;
  }

  /// 当前体重距离目标体重还差多少公斤
  ///
  /// 返回绝对值，方向由调用方根据目标类型自己判断
  double get weightGap => (_profile.weightKg - _goal.targetWeightKg).abs();

  // ═══════════════════════════════════════════════════
  //  修改方法 —— 每个都必须以 notifyListeners() 结尾
  // ═══════════════════════════════════════════════════

  /// 更新用户资料
  ///
  /// 参数全是可选的，只传想改的字段，其余保持不变
  void updateProfile({
    String? name,
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? bio,
  }) {
    _profile = _profile.copyWith(
      name: name,
      gender: gender,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      bio: bio,
    );
    LocalStorage.saveProfile(_profile); // 写进本地存储
    _pushProfile();
    notifyListeners(); // 广播变化，所有监听这个 store 的界面都会重建
  }

  /// 更新头像地址（上传完成后写入，或删除时传 null 清空）
  void setAvatarUrl(String? url) {
    _profile = _profile.copyWith(avatarUrl: url);
    LocalStorage.saveProfile(_profile);
    _pushProfile();
    notifyListeners();
  }

  /// 更新健身目标
  void updateGoal({
    GoalType? type,
    double? targetWeightKg,
    int? weeklyWorkouts,
    int? dailyCalories,
    int? dailyWaterMl,
  }) {
    _goal = _goal.copyWith(
      type: type,
      targetWeightKg: targetWeightKg,
      weeklyWorkouts: weeklyWorkouts,
      dailyCalories: dailyCalories,
      dailyWaterMl: dailyWaterMl,
    );
    LocalStorage.saveGoal(_goal);
    _pushProfile();
    notifyListeners();
  }

  /// 新增一条训练记录
  void addRecord(WorkoutRecord record) {
    _records = [..._records, record]; // 建新列表而不是 add，配合不可变风格
    LocalStorage.saveRecords(_records);
    notifyListeners();
  }

  /// 按id删除一条训练记录
  void deleteRecord(String id) {
    _records = _records.where((r) => r.id != id).toList();
    LocalStorage.saveRecords(_records);
    notifyListeners();
  }

  /// 切换收藏状态：已收藏则取消，未收藏则加上
  void toggleFavorite(String courseId) {
    if (_favoriteIds.contains(courseId)) {
      _favoriteIds.remove(courseId);
    } else {
      _favoriteIds.add(courseId);
    }
    LocalStorage.saveFavorites(_favoriteIds);
    notifyListeners();
  }

  /// 切换深色模式
  void setDarkMode(bool value) {
    _darkMode = value;
    _persistSettings();
    notifyListeners();
  }

  /// 切换训练提醒
  void setWorkoutReminder(bool value) {
    _workoutReminder = value;
    _persistSettings();
    notifyListeners();
  }

  /// 切换喝水提醒
  void setWaterReminder(bool value) {
    _waterReminder = value;
    _persistSettings();
    notifyListeners();
  }

  /// 切换单位制
  void setUnitSystem(String value) {
    _unitSystem = value;
    _persistSettings();
    notifyListeners();
  }

  /// 设置 AI API Key
  void setAiApiKey(String key) {
    _aiApiKey = key.trim();
    LocalStorage.saveApiKey(_aiApiKey);
    notifyListeners();
  }

  /// 保存一份 AI 生成的计划
  void addAiPlan(TrainingPlan plan) {
    _aiPlans = [..._aiPlans, plan];
    _persistAiPlans();
    notifyListeners();
  }

  /// 保存对计划的修改
  ///
  /// 自定义／AI 计划原地覆盖；预置计划是 const 常量改不了，
  /// 所以存成一份新的可编辑副本，原预置保持不动。
  /// 返回实际保存的计划（预置的情况下 id 和传入的不一样）。
  TrainingPlan savePlan(TrainingPlan plan) {
    final isPreset = PresetPlans.getById(plan.id) != null;

    var saved = plan;

    if (isPreset) {
      // 换新 id，并把每个训练日的 planId 指向新计划，
      // 否则训练日还挂在原预置上，记录和草稿会对不上。
      //
      // 时间戳后面挂一个自增序号：毫秒精度在快速连续保存时会撞车，
      // 撞了就会把上一份副本覆盖掉
      final newId = 'plan_custom_'
          '${DateTime.now().millisecondsSinceEpoch}_${_planCopyCounter++}';
      saved = plan.copyWith(
        id: newId,
        name: '${plan.name}（我的版本）',
        days: plan.days.map((d) => d.copyWith(planId: newId)).toList(),
      );
    }

    final i = _aiPlans.indexWhere((p) => p.id == saved.id);
    if (i >= 0) {
      final next = [..._aiPlans];
      next[i] = saved;
      _aiPlans = next;
    } else {
      _aiPlans = [..._aiPlans, saved];
    }

    _persistAiPlans();

    // 原来用的是预置计划，改完自动切到副本上，
    // 不然用户以为改了却还在练原版
    if (isPreset && _activePlanId == plan.id) {
      _activePlanId = saved.id;
      LocalStorage.saveActivePlanId(saved.id);
    }

    notifyListeners();
    return saved;
  }

  /// 删除一份 AI 计划
  void deleteAiPlan(String planId) {
    _aiPlans = _aiPlans.where((p) => p.id != planId).toList();
    _persistAiPlans();

    // 删掉的正好是当前计划，顺手清掉选中状态，
    // 否则会留一个指向已删除计划的 id
    if (_activePlanId == planId) {
      _activePlanId = null;
      LocalStorage.saveActivePlanId(null);
    }

    notifyListeners();
  }

  /// 保存一条训练完成记录
  void addWorkoutLog(WorkoutLog log) {
    _workoutLogs = [..._workoutLogs, log];
    _persistWorkoutLogs();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════
  //  饮食记录
  // ═══════════════════════════════════════════════════

  /// 全部饮食记录，按时间倒序（最近的在前）
  List<MealEntry> get meals {
    final sorted = [..._meals];
    sorted.sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    return List.unmodifiable(sorted);
  }

  /// 某一天的饮食记录，按时间正序（早餐在前）
  List<MealEntry> mealsOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);

    final list = _meals.where((m) {
      final d = DateTime(m.eatenAt.year, m.eatenAt.month, m.eatenAt.day);
      return d == target;
    }).toList();

    list.sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    return list;
  }

  /// 今天的饮食记录
  List<MealEntry> get todayMeals => mealsOn(DateTime.now());

  /// 某一天某一餐的记录
  List<MealEntry> mealsOfType(DateTime day, MealType type) {
    return mealsOn(day).where((m) => m.mealType == type).toList();
  }

  /// 某一天的营养汇总
  NutritionSummary summaryOn(DateTime day) {
    return NutritionSummary.from(mealsOn(day));
  }

  /// 今天的营养汇总
  NutritionSummary get todaySummary => summaryOn(DateTime.now());

  /// 添加一条饮食记录
  void addMeal(MealEntry entry) {
    _meals = [..._meals, entry];
    _persistMeals();
    notifyListeners();
  }

  /// 按 id 删除一条饮食记录
  void deleteMeal(String id) {
    _meals = _meals.where((m) => m.id != id).toList();
    _persistMeals();
    notifyListeners();
  }

  /// 清空所有饮食记录
  void clearMeals() {
    _meals = [];
    _persistMeals();
    notifyListeners();
  }

  void _persistMeals() {
    LocalStorage.saveMeals(
      _meals.map((m) => jsonEncode(m.toMap())).toList(),
    );
    CloudSyncService.pushItems(
      'meal_entries',
      _meals.map((m) => m.toMap()).toList(),
    );
  }

  // ═══════════════════════════════════════════════════
  //  自定义食物
  // ═══════════════════════════════════════════════════

  /// 用户自己加的食物
  List<FoodItem> get customFoods => List.unmodifiable(_customFoods);

  /// 内置库 + 自定义，供搜索和选择用
  ///
  /// 自定义的放前面：用户自己加的通常是常吃的
  List<FoodItem> get allFoods => [..._customFoods, ...FoodDatabase.getAll()];

  /// 在全部食物里搜索
  List<FoodItem> searchFoods(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return allFoods;

    return allFoods.where((f) => f.name.contains(k)).toList();
  }

  /// 按分类取食物
  List<FoodItem> foodsByCategory(FoodCategory category) {
    return allFoods.where((f) => f.category == category).toList();
  }

  /// 按 id 查食物，内置和自定义都找
  FoodItem? findFood(String id) {
    for (final f in allFoods) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// 添加一个自定义食物
  void addCustomFood(FoodItem food) {
    _customFoods = [..._customFoods, food];
    _persistCustomFoods();
    notifyListeners();
  }

  /// 删除一个自定义食物
  ///
  /// 已经记录的饮食不受影响 —— MealEntry 存的是营养快照不是引用
  void deleteCustomFood(String id) {
    _customFoods = _customFoods.where((f) => f.id != id).toList();
    _persistCustomFoods();
    notifyListeners();
  }

  void _persistCustomFoods() {
    LocalStorage.saveCustomFoods(
      _customFoods.map((f) => jsonEncode(f.toMap())).toList(),
    );
    CloudSyncService.pushItems(
      'custom_foods',
      _customFoods.map((f) => f.toMap()).toList(),
    );
  }

  // ═══════════════════════════════════════════════════
  //  体重记录
  // ═══════════════════════════════════════════════════

  /// 体重记录，按日期正序（早的在前，画曲线用）
  List<WeightLog> get weightLogs {
    final sorted = [..._weightLogs];
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(sorted);
  }

  /// 最近 n 天的体重记录
  List<WeightLog> recentWeightLogs(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return weightLogs.where((w) => w.date.isAfter(cutoff)).toList();
  }

  /// 添加一条体重记录
  ///
  /// 同一天重复记录会覆盖，不是追加 —— 一天称好几次只保留最后一次，
  /// 否则曲线上同一天会有多个点
  void addWeightLog(WeightLog log) {
    final others =
        _weightLogs.where((w) => w.dayOnly != log.dayOnly).toList();
    _weightLogs = [...others, log];
    _persistWeightLogs();

    // 顺手把当前体重同步到个人资料，省得用户改两处
    updateProfile(weightKg: log.weightKg);
  }

  /// 按 id 删除一条体重记录
  void deleteWeightLog(String id) {
    _weightLogs = _weightLogs.where((w) => w.id != id).toList();
    _persistWeightLogs();
    notifyListeners();
  }

  void _persistWeightLogs() {
    LocalStorage.saveWeightLogs(
      _weightLogs.map((w) => jsonEncode(w.toMap())).toList(),
    );
    CloudSyncService.pushItems(
      'weight_logs',
      _weightLogs.map((w) => w.toMap()).toList(),
    );
  }

  // ═══════════════════════════════════════════════════
  //  营养目标
  // ═══════════════════════════════════════════════════

  /// 当前活动强度
  ActivityLevel get activityLevel => _activityLevel;

  /// 设置活动强度
  void setActivityLevel(ActivityLevel level) {
    if (_activityLevel == level) return;

    _activityLevel = level;
    LocalStorage.saveActivityLevel(level.index);
    _pushProfile();
    notifyListeners();
  }

  /// 基础代谢（千卡/天）
  int get bmr => calculateBmr(_profile);

  /// 每日总消耗（千卡/天）
  int get tdee => calculateTdee(_profile, _activityLevel);

  /// 每日热量目标（千卡/天）
  ///
  /// 优先用户在目标设置里手填的值；没填（为 0）就按 TDEE 和目标推算
  int get dailyCalorieTarget {
    if (_goal.dailyCalories > 0) return _goal.dailyCalories;
    return recommendedCalories(_profile, _activityLevel, _goal.type);
  }

  /// 三大宏量素的每日目标
  MacroTargets get macroTargets => calculateMacros(
        weightKg: _profile.weightKg,
        dailyCalories: dailyCalorieTarget,
        goal: _goal.type,
      );

  // ═══════════════════════════════════════════════════
  //  训练中断草稿
  // ═══════════════════════════════════════════════════

  /// 读取未完成的训练草稿
  ///
  /// 过期的草稿直接当不存在，并顺手清掉 —— 避免越积越多
  SessionDraft? loadDraft() {
    final json = LocalStorage.loadSessionDraft();
    if (json == null) return null;

    try {
      final draft = SessionDraft.fromMap(jsonDecode(json) as Map);
      if (draft.isExpired) {
        clearDraft();
        return null;
      }
      return draft;
    } catch (_) {
      // 脏数据直接丢弃，不要因为一条草稿卡住训练流程
      clearDraft();
      return null;
    }
  }

  /// 保存训练草稿
  ///
  /// 不调 notifyListeners：训练页自己管状态，通知反而会多余重建
  void saveDraft(SessionDraft draft) {
    LocalStorage.saveSessionDraft(jsonEncode(draft.toMap()));
  }

  /// 清掉草稿（训练完成或用户放弃时）
  void clearDraft() {
    LocalStorage.saveSessionDraft(null);
  }

  // ═══════════════════════════════════════════════════
  //  当前计划
  // ═══════════════════════════════════════════════════

  /// 当前选中的计划 id，没选过是 null
  String? get activePlanId => _activePlanId;

  /// 当前选中的计划对象，没选过或计划已被删除时是 null
  ///
  /// 每次都重新查找而不是缓存对象：AI 计划可能被删掉，
  /// 缓存会留下一个指向已删除计划的悬空引用
  TrainingPlan? get activePlan {
    final id = _activePlanId;
    if (id == null) return null;

    final preset = PresetPlans.getById(id);
    if (preset != null) return preset;

    for (final p in _aiPlans) {
      if (p.id == id) return p;
    }

    // id 存着但计划找不到了（AI 计划被删除），当作没选
    return null;
  }

  /// 把某个计划设为当前计划
  void setActivePlan(String? planId) {
    if (_activePlanId == planId) return;

    _activePlanId = planId;
    LocalStorage.saveActivePlanId(planId);
    notifyListeners();
  }

  /// 按 id 删除一条训练完成记录
  void deleteWorkoutLog(String id) {
    _workoutLogs = _workoutLogs.where((l) => l.id != id).toList();
    _persistWorkoutLogs();
    notifyListeners();
  }

  /// 本周按计划完成的训练次数
  ///
  /// 和 thisWeekWorkouts 的区别：那个统计所有运动记录（含手动添加的），
  /// 这个只算跟着训练计划练完的
  int get thisWeekPlanWorkouts {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    // 用 !isBefore 而不是 isAfter：isAfter 是严格大于，
    // 会把周一零点整的记录排除在本周之外
    return _workoutLogs
        .where((l) => !l.completedAt.isBefore(monday))
        .length;
  }

  /// 累计按计划完成的训练次数
  int get totalPlanWorkouts => _workoutLogs.length;

  /// 今天按计划完成的训练总时长（分钟）
  ///
  /// 发帖附「今日训练效果」时用。
  int get todayWorkoutMinutes {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _workoutLogs
        .where((l) =>
            DateTime(l.completedAt.year, l.completedAt.month, l.completedAt.day) ==
            today)
        .fold(0, (sum, l) => sum + l.durationMinutes);
  }

  /// 把 AI 计划列表写进存储
  void _persistAiPlans() {
    LocalStorage.saveAiPlans(
      _aiPlans.map((p) => jsonEncode(p.toMap())).toList(),
    );
    CloudSyncService.pushItems(
      'ai_plans',
      _aiPlans.map((p) => p.toMap()).toList(),
    );
  }

  /// 把训练记录列表写进存储
  void _persistWorkoutLogs() {
    LocalStorage.saveWorkoutLogs(
      _workoutLogs.map((log) => jsonEncode(log.toMap())).toList(),
    );
    CloudSyncService.pushItems(
      'workout_logs',
      _workoutLogs.map((log) => log.toMap()).toList(),
    );
  }

  /// 清空所有训练记录（设置页的「清除数据」用）
  void clearAllRecords() {
    _records = [];
    // 存空列表而不是删 key：这样重启后知道「用户主动清空过」，
    // 不会又把演示数据填回去
    LocalStorage.saveRecords(_records);
    notifyListeners();
  }

  /// 把所有数据恢复成初始状态（设置页的「重置」用）
  void resetAll() {
    _profile = UserProfile.initial();
    _goal = FitnessGoal.initial();
    _records = WorkoutRecord.demoRecords();
    _favoriteIds
      ..clear()
      ..addAll({'c1', 'c3', 'c5'});
    _darkMode = false;
    _workoutReminder = true;
    _waterReminder = false;
    _unitSystem = '公制';
    _aiPlans = [];
    _workoutLogs = [];
    _activePlanId = null;
    _meals = [];
    _customFoods = [];
    _weightLogs = [];
    _persistMeals();
    _persistCustomFoods();
    _persistWeightLogs();
    clearDraft();

    // 把本地存储整个清掉，而不是逐项写回默认值。
    // 这样下次启动时所有 load 都返回 null，自然用默认值，
    // 也不会留下旧版本格式的脏数据
    LocalStorage.clearAll();

    // API Key 不属于「数据」，重置后要留着 —— 用户重置是想清掉训练记录，
    // 不是想重新去申请一次 key
    if (_aiApiKey.isNotEmpty) {
      LocalStorage.saveApiKey(_aiApiKey);
    }

    notifyListeners();
  }
}
