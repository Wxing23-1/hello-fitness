import 'dart:convert';

import '../models/training_plan.dart';
import '../models/user_profile.dart';
import '../models/fitness_goal.dart';
import '../models/workout_record.dart';
import '../utils/health_utils.dart';
import 'ai_backend.dart';

/// AI 训练计划生成服务
///
/// 用 DeepSeek 生成个性化训练计划。
///
/// 为什么用 DeepSeek：国内直连不需要代理，接口是 OpenAI 兼容格式，
/// 用 http 包直接发请求就行，不用额外装 SDK。
///
/// 关键设计：
/// 1. 用 response_format: json_object 让模型只返回 JSON，
///    不然它会在外面套一层「好的，这是你的计划：```json ... ```」
/// 2. DeepSeek 不像 Gemini 那样支持字段级 schema 约束，
///    所以把完整的 JSON 结构写进 prompt，再在解析时做容错
/// 3. 喂给它真实的近期训练数据，而不是只给目标 —— 这样它能判断出
///    「你说想每周练5次，但过去两周平均只练了1.5次」，给出渐进方案
class AiPlanService {
  /// 生成训练计划
  ///
  /// 返回结果要么成功带回计划，要么失败带回原因，
  /// 调用方根据 success 分支处理
  static Future<AiPlanResult> generate({
    required UserProfile profile,
    required FitnessGoal goal,
    required List<WorkoutRecord> recentRecords,
    required String userThoughts,
    required int weeklyWorkouts,
    required TrainingCategory? preferredCategory,
    required String equipment,
  }) async {
    try {
      final prompt = _buildPrompt(
        profile: profile,
        goal: goal,
        recentRecords: recentRecords,
        userThoughts: userThoughts,
        weeklyWorkouts: weeklyWorkouts,
        preferredCategory: preferredCategory,
        equipment: equipment,
      );

      final content = await AiBackend.chat(
        systemPrompt: '你是一位有十年经验的健身教练，擅长根据学员的实际情况'
            '制定循序渐进的训练计划。你只返回 JSON，不说任何多余的话。',
        userPrompt: prompt,
        // 温度调低一点：训练计划要稳妥，不需要天马行空
        temperature: 0.7,
        maxTokens: 4000,
        jsonObject: true,
      );

      // 解析 JSON 并转成 TrainingPlan
      final plan = _parsePlan(content, goal);
      return AiPlanResult.success(plan);
    } on AiBackendException catch (e) {
      return AiPlanResult.failure(e.message);
    } on FormatException {
      // AI 返回的不是合法 JSON
      return AiPlanResult.failure('AI 返回的格式不对，请重试一次');
    } catch (e) {
      // 解析字段缺失等
      return AiPlanResult.failure('生成失败：$e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  Prompt 构造
  // ═══════════════════════════════════════════════════════

  /// 拼接发给 DeepSeek 的 prompt
  ///
  /// 分成几块：用户档案 → 实际运动量 → 用户想法 → 硬性要求 → JSON 结构
  static String _buildPrompt({
    required UserProfile profile,
    required FitnessGoal goal,
    required List<WorkoutRecord> recentRecords,
    required String userThoughts,
    required int weeklyWorkouts,
    required TrainingCategory? preferredCategory,
    required String equipment,
  }) {
    final bmi = calculateBmi(profile.heightCm, profile.weightKg);
    final level = bmiLevelOf(bmi);
    final stats = _analyzeRecords(recentRecords);

    // 偏好类别：用户没选就让 AI 自己根据目标判断
    final categoryHint = preferredCategory == null
        ? '用户没有指定偏好，请根据他的目标自行决定有氧和无氧的配比，并在 description 里说明理由'
        : '用户希望以${preferredCategory.label}为主（${preferredCategory.description}）';

    return '''
你是一位经验丰富的健身教练，要为学员定制一份 4 周训练计划。

# ⚠️ 最重要：学员的想法和诉求
${userThoughts.trim().isEmpty ? '（学员没有特别说明，请根据他的档案和目标自行设计）' : '"""${userThoughts.trim()}"""'}

**这是整个计划的核心**。如果学员明确提到了：
- 具体部位（腹肌、臀腿、胸肌等）→ 至少 60% 的动作必须针对该部位
- 特定训练类型（HIIT、瑜伽、力量等）→ 必须以该类型为主
- 时间限制（只有半小时、早上练等）→ 严格控制训练时长和时段
- 身体限制（膝盖受伤、不能跳跃等）→ 绝对避开这些动作
- 场地限制（在家、没器械等）→ 只用徒手或指定器械

不要用"综合性更好"之类的理由偏离学员的明确诉求。

# 学员档案
- 性别：${profile.gender.label}，${profile.age}岁
- 身高体重：${profile.heightCm.toStringAsFixed(0)}cm / ${profile.weightKg.toStringAsFixed(1)}kg（BMI ${bmi.toStringAsFixed(1)}，${level.label}）
- 健身目标：${goal.type.label}
- 目标体重：${goal.targetWeightKg.toStringAsFixed(1)}kg（需要${profile.weightKg > goal.targetWeightKg ? '减' : '增'}${(profile.weightKg - goal.targetWeightKg).abs().toStringAsFixed(1)}kg）

# 最近 30 天的真实运动数据
$stats

# 可用器械
$equipment

# 训练频率和偏好
- 希望每周训练：$weeklyWorkouts 次
- $categoryHint

# 你的任务
制定一份 4 周训练计划，要求：

1. **必须基于真实运动量来定强度**。如果学员最近几乎没运动，但想每周练5次，
   不要直接给5次的高强度计划 —— 从他能承受的量开始，在计划里体现渐进。
   如果他本来就练得不少，可以适当提高强度。

2. **明确区分有氧和无氧**。每个训练日和每个动作都要标注 category：
   - "aerobic"（有氧）：中低强度持续运动，靠氧气供能，燃脂和心肺，如慢跑、骑行、跳绳
   - "anaerobic"（无氧）：高强度短时运动，靠肌糖原供能，增肌和力量，如举铁、深蹲、俯卧撑
   - "mixed"（混合）：有氧无氧交替，如 HIIT、波比跳、登山跑

3. **配比要符合目标**：
   - 减脂：有氧为主但必须保留无氧（防止掉肌肉），建议有氧:无氧 约 6:4
   - 增肌：无氧为主，有氧只做少量（避免影响增肌），建议 2:8
   - 保持：均衡，约 5:5

4. **动作要具体可执行**：写清组数、次数（或秒数）、组间休息秒数、目标肌群、器械。
   - 按时间计量的动作（平板支撑、开合跳、慢跑）把 isTimeBased 设为 true，reps 填秒数
   - 做到力竭的动作 reps 填 -1
   - 徒手动作 equipment 填空字符串 ""
   - 器械类动作给出适合该学员水平的建议重量 targetWeightKg（公斤，可带小数）；
     徒手动作、有氧动作、以及按时间计的动作填 null

5. **每个动作都要给要点提示**（tips），说清容易做错的地方，像真人教练那样讲，20-50字。
   另外给两份结构化说明：
   - steps：3-4 条分解步骤，按顺序讲怎么做（起始姿势 → 发力 → 还原）
   - mistakes：2-3 条新手常见错误，练错比不练更容易受伤，这块要具体

6. 训练日数量必须正好等于 $weeklyWorkouts 天，代表一周的循环，学员会重复 4 周。

7. description 里简要说明你这样安排的理由。如果学员的想法和他的实际运动量
   有冲突（比如想练很多但基础薄弱），要点出来并解释你怎么处理的。

# 返回格式
严格按下面的 JSON 结构返回，不要加任何额外文字或 markdown 代码块标记：

{
  "name": "计划名称，不超过12个字",
  "description": "计划说明含安排理由，50-120字",
  "category": "aerobic 或 anaerobic 或 mixed，整个计划的主类别",
  "level": "beginner 或 intermediate 或 advanced",
  "days": [
    {
      "name": "训练日名称，如「胸背力量」「有氧燃脂」",
      "category": "aerobic 或 anaerobic 或 mixed",
      "estimatedMinutes": 45,
      "exercises": [
        {
          "name": "动作名称",
          "category": "aerobic 或 anaerobic 或 mixed",
          "sets": 4,
          "reps": 12,
          "isTimeBased": false,
          "restSeconds": 60,
          "muscleGroup": "目标肌群",
          "equipment": "需要的器械，徒手填空字符串",
          "targetWeightKg": 20,
          "tips": "动作要点，20-50字",
          "steps": ["分解步骤1", "分解步骤2", "分解步骤3"],
          "mistakes": ["常见错误1", "常见错误2"]
        }
      ]
    }
  ]
}

每个训练日 3-6 个动作。只返回 JSON。
''';
  }

  /// 分析最近的训练记录，生成给 AI 看的统计摘要
  ///
  /// 这是「根据当前运动量给合理计划」的关键 —— 不是把原始记录一条条丢给 AI，
  /// 而是先算出频率、时长、有氧无氧配比这些它真正需要的指标
  static String _analyzeRecords(List<WorkoutRecord> records) {
    // 只看最近 30 天
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = records.where((r) => r.date.isAfter(cutoff)).toList();

    if (recent.isEmpty) {
      return '最近 30 天没有任何训练记录 —— 这是一个零基础或长期停训的学员，'
          '制定计划时要特别注意强度不能太高，先建立运动习惯。';
    }

    final totalMinutes = recent.fold(0, (s, r) => s + r.durationMinutes);
    final totalCalories = recent.fold(0, (s, r) => s + r.calories);

    // 按有氧/无氧分组统计，让 AI 知道学员现在偏哪一边
    final aerobicCount = recent
        .where((r) => r.type.energySystem == EnergySystem.aerobic)
        .length;
    final anaerobicCount = recent
        .where((r) => r.type.energySystem == EnergySystem.anaerobic)
        .length;
    final mixedCount =
        recent.where((r) => r.type.energySystem == EnergySystem.mixed).length;

    // 按运动类型统计次数，看他平时都练什么
    final typeCount = <WorkoutType, int>{};
    for (final r in recent) {
      typeCount[r.type] = (typeCount[r.type] ?? 0) + 1;
    }
    final typeSummary = typeCount.entries
        .map((e) => '${e.key.label} ${e.value}次')
        .join('、');

    // 平均每周次数：30天约 4.3 周
    final weeklyAvg = (recent.length / 4.3).toStringAsFixed(1);
    final avgDuration = (totalMinutes / recent.length).round();

    return '''
- 总训练次数：${recent.length} 次（平均每周 $weeklyAvg 次）
- 总时长：$totalMinutes 分钟（平均每次 $avgDuration 分钟）
- 总消耗：$totalCalories 千卡
- 有氧 $aerobicCount 次 / 无氧 $anaerobicCount 次 / 混合 $mixedCount 次
- 项目分布：$typeSummary''';
  }

  // ═══════════════════════════════════════════════════════
  //  解析
  // ═══════════════════════════════════════════════════════

  /// 把 AI 返回的 JSON 转成 TrainingPlan 对象
  ///
  /// [userGoal] 是用户自己设的目标，AI 不返回这个字段，由这里填上
  static TrainingPlan _parsePlan(String jsonText, FitnessGoal userGoal) {
    // 虽然要求了只返回 JSON，但模型偶尔还是会套一层 markdown 代码块，
    // 所以先清理一下再解析
    final cleaned = _stripCodeFence(jsonText);

    final map = jsonDecode(cleaned) as Map<String, dynamic>;

    // 用时间戳生成唯一 id
    final planId = 'ai_plan_${DateTime.now().millisecondsSinceEpoch}';

    final daysJson = map['days'] as List<dynamic>? ?? [];
    if (daysJson.isEmpty) {
      throw const FormatException('AI 返回的计划里没有训练日');
    }

    final days = <TrainingDay>[];
    for (var i = 0; i < daysJson.length; i++) {
      final dayMap = daysJson[i] as Map<String, dynamic>;
      final exercisesJson = dayMap['exercises'] as List<dynamic>? ?? [];

      final exercises = <Exercise>[];
      for (var j = 0; j < exercisesJson.length; j++) {
        final exMap = exercisesJson[j] as Map<String, dynamic>;

        // 器械字段可能是 null 或空字符串，统一成 null
        final equipment = (exMap['equipment'] as String?)?.trim();

        exercises.add(Exercise(
          id: '${planId}_d${i + 1}_e${j + 1}',
          name: exMap['name'] as String? ?? '动作${j + 1}',
          category: _parseCategory(exMap['category'] as String?),
          // 模型有时会把数字返回成字符串，用 _toInt 兜一下
          sets: _toInt(exMap['sets'], 3),
          reps: _toInt(exMap['reps'], 10),
          isTimeBased: exMap['isTimeBased'] as bool? ?? false,
          restSeconds: _toInt(exMap['restSeconds'], 60),
          muscleGroup: exMap['muscleGroup'] as String? ?? '全身',
          equipment: (equipment == null || equipment.isEmpty) ? null : equipment,
          // 模型可能返回 null、整数或小数，统一用 num 兜住再转 double
          targetWeightKg: (exMap['targetWeightKg'] as num?)?.toDouble(),
          tips: exMap['tips'] as String?,
          // 模型可能不返回这两个字段，缺了就是空列表
          steps: (exMap['steps'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          mistakes: (exMap['mistakes'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        ));
      }

      days.add(TrainingDay(
        id: '${planId}_day${i + 1}',
        planId: planId,
        dayNumber: i + 1,
        name: dayMap['name'] as String? ?? '第${i + 1}天',
        category: _parseCategory(dayMap['category'] as String?),
        exercises: exercises,
        estimatedMinutes: _toInt(dayMap['estimatedMinutes'], 40),
      ));
    }

    return TrainingPlan(
      id: planId,
      name: map['name'] as String? ?? 'AI 定制计划',
      description: map['description'] as String? ?? '',
      // AI 不返回 goal，用用户自己设的目标
      goal: userGoal.type.toTrainingGoal(),
      level: _parseLevel(map['level'] as String?),
      category: _parseCategory(map['category'] as String?),
      durationWeeks: 4,
      workoutsPerWeek: days.length,
      days: days,
      isAiGenerated: true,
    );
  }

  /// 去掉 markdown 代码块包裹
  ///
  /// 有时模型会返回 ```json\n{...}\n``` 这种格式，
  /// 直接 jsonDecode 会失败，所以先剥掉外层
  static String _stripCodeFence(String text) {
    var s = text.trim();

    if (s.startsWith('```')) {
      // 去掉开头的 ```json 或 ```
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) {
        s = s.substring(firstNewline + 1);
      }
      // 去掉结尾的 ```
      if (s.endsWith('```')) {
        s = s.substring(0, s.length - 3);
      }
    }

    return s.trim();
  }

  /// 宽松地转成 int
  ///
  /// 模型偶尔会把数字返回成 "12" 或 12.0，这里统一处理
  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// 字符串转类别枚举，无法识别时按混合处理
  static TrainingCategory _parseCategory(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'aerobic':
        return TrainingCategory.aerobic;
      case 'anaerobic':
        return TrainingCategory.anaerobic;
      default:
        return TrainingCategory.mixed;
    }
  }

  /// 字符串转难度枚举
  static TrainingLevel _parseLevel(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'beginner':
        return TrainingLevel.beginner;
      case 'advanced':
        return TrainingLevel.advanced;
      default:
        return TrainingLevel.intermediate;
    }
  }
}

/// 把用户设的健身目标转成训练计划的目标枚举
///
/// 两个枚举是分开定义的（一个属于个人中心，一个属于训练模块），
/// 这里做个映射，避免模块之间强耦合
extension _GoalTypeMapping on GoalType {
  TrainingGoal toTrainingGoal() {
    switch (this) {
      case GoalType.loseWeight:
        return TrainingGoal.loseWeight;
      case GoalType.gainMuscle:
        return TrainingGoal.gainMuscle;
      case GoalType.keepFit:
        return TrainingGoal.keepFit;
    }
  }
}

/// AI 生成结果
///
/// 用一个类同时表示成功和失败两种情况，调用方先判断 success，
/// 比抛异常更好处理（界面上要显示具体错误文案）
class AiPlanResult {
  /// 是否成功
  final bool success;

  /// 成功时的计划，失败时为 null
  final TrainingPlan? plan;

  /// 失败时的原因，成功时为 null
  final String? error;

  const AiPlanResult._({required this.success, this.plan, this.error});

  factory AiPlanResult.success(TrainingPlan plan) =>
      AiPlanResult._(success: true, plan: plan);

  factory AiPlanResult.failure(String error) =>
      AiPlanResult._(success: false, error: error);
}
