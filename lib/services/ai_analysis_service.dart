import 'dart:convert';

import '../models/fitness_goal.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
import '../models/weight_log.dart';
import '../models/workout_log.dart';
import '../utils/health_utils.dart';
import '../utils/nutrition_utils.dart';
import 'ai_backend.dart';

/// AI 今日健身效果分析服务
///
/// 把用户今天真实的训练、饮食、体重数据汇总成一段 prompt，
/// 让 DeepSeek 输出一份结构化分析：
///   - 今天整体表现如何
///   - 训练效果怎么样
///   - 饮食吃得好不好（对照目标摄入）
///   - 给出 3 条建议 + 明天的安排
///
/// 和 AiPlanService 一样：纯文本模型 + JSON 结构化输出。
/// 这不是「智能体」，就是「数据组装 + 好 prompt + 解析」。
class AiAnalysisService {
  /// 分析今天的健身效果
  ///
  /// [dailyCalorieTarget] 是「每日热量目标」，内部用它推算宏量素目标，
  /// 再拿去和今天实际摄入对比。
  static Future<AiAnalysisResult> analyze({
    required UserProfile profile,
    required FitnessGoal goal,
    required ActivityLevel activityLevel,
    required int dailyCalorieTarget,
    required List<WorkoutLog> workoutLogs,
    required List<MealEntry> meals,
    required List<WeightLog> weightLogs,
  }) async {
    try {
      final prompt = _buildPrompt(
        profile: profile,
        goal: goal,
        activityLevel: activityLevel,
        dailyCalorieTarget: dailyCalorieTarget,
        workoutLogs: workoutLogs,
        meals: meals,
        weightLogs: weightLogs,
      );

      final content = await AiBackend.chat(
        systemPrompt: '你是一位经验丰富的健身教练兼营养师，'
            '擅长根据真实数据给出具体、可执行的健身建议。'
            '你只返回 JSON，不说任何多余的话。',
        userPrompt: prompt,
        // 分析类任务要稳，温度调低
        temperature: 0.4,
        maxTokens: 1500,
        jsonObject: true,
      );

      return AiAnalysisResult.success(_parse(content));
    } on AiBackendException catch (e) {
      return AiAnalysisResult.failure(e.message);
    } on FormatException {
      return AiAnalysisResult.failure('AI 返回的格式不对，请重试一次');
    } catch (e) {
      return AiAnalysisResult.failure('分析失败：$e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  Prompt 构造
  // ═══════════════════════════════════════════════════════

  static String _buildPrompt({
    required UserProfile profile,
    required FitnessGoal goal,
    required ActivityLevel activityLevel,
    required int dailyCalorieTarget,
    required List<WorkoutLog> workoutLogs,
    required List<MealEntry> meals,
    required List<WeightLog> weightLogs,
  }) {
    final bmi = calculateBmi(profile.heightCm, profile.weightKg);
    final level = bmiLevelOf(bmi);
    final macros = calculateMacros(
      weightKg: profile.weightKg,
      dailyCalories: dailyCalorieTarget,
      goal: goal.type,
    );

    return '''
你是一位专业健身教练兼营养师，请根据下面的真实数据，做一份「今日健身效果分析」。

# 用户档案
- ${profile.gender.label}，${profile.age}岁，${profile.heightCm.toStringAsFixed(0)}cm / ${profile.weightKg.toStringAsFixed(1)}kg（BMI ${bmi.toStringAsFixed(1)}，${level.label}）
- 目标：${goal.type.label}，目标体重 ${goal.targetWeightKg.toStringAsFixed(1)}kg，每周计划练 ${goal.weeklyWorkouts} 次
- 活动强度：${activityLevel.label}（${activityLevel.description}）
- 每日热量目标：$dailyCalorieTarget 千卡（蛋白 ${macros.protein}g / 碳水 ${macros.carbs}g / 脂肪 ${macros.fat}g）

# 今日训练
${_workoutToday(workoutLogs)}

# 今日饮食
${_dietToday(meals, dailyCalorieTarget, macros)}

# 近期体重
${_weightTrend(weightLogs)}

# 你的任务
1. summary：用一两句话总结今天的整体表现，语气像真人教练，别端着
2. workoutReview：评价今天的训练效果（练没练、量够不够、强度合不合适）
3. dietReview：评价今天的饮食（热量达标没、蛋白够不够、和目标的差距）
4. suggestions：给 3 条最具体的建议，每条一句，可执行
5. tomorrowPlan：给出明天训练 + 饮食的简要安排

要求：
- 数据里「没有训练记录」或「没有饮食记录」就如实说，不要编造
- 建议要具体到「做什么、吃多少、几点做」，不要空话
- 如果用户没达标，先肯定再指出差距，别打击人

严格按下面的 JSON 结构返回，不要加任何额外文字或 markdown 代码块标记：

{
  "summary": "今日总体评价",
  "workoutReview": "训练效果分析",
  "dietReview": "饮食分析",
  "suggestions": ["建议1", "建议2", "建议3"],
  "tomorrowPlan": "明天的训练和饮食安排"
}

只返回 JSON。
''';
  }

  /// 今天的训练情况摘要
  static String _workoutToday(List<WorkoutLog> logs) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final todays = logs
        .where((l) =>
            DateTime(l.completedAt.year, l.completedAt.month, l.completedAt.day) ==
            todayOnly)
        .toList();

    if (todays.isEmpty) {
      return '今天还没有训练记录。';
    }

    final totalMinutes = todays.fold(0, (s, l) => s + l.durationMinutes);
    var totalSets = 0;
    var totalReps = 0;
    for (final l in todays) {
      for (final e in l.exercises) {
        totalSets += e.completedSets;
        totalReps += e.totalReps;
      }
    }

    // 感受评分（1-5 星），有就带一句
    final feelings = todays.map((l) => l.feeling).whereType<int>().toList();
    final feelingText = feelings.isEmpty
        ? '没记录感受'
        : '感受评分 ${(feelings.reduce((a, b) => a + b) / feelings.length).toStringAsFixed(1)}/5';

    final noteText = todays
        .map((l) => l.note)
        .whereType<String>()
        .where((n) => n.trim().isNotEmpty)
        .join('；');

    return '训练了 ${todays.length} 次，共 $totalMinutes 分钟，'
        '完成 $totalSets 组、$totalReps 次。$feelingText。'
        '${noteText.isEmpty ? '' : '备注：$noteText'}';
  }

  /// 今天的饮食情况摘要（对照目标）
  static String _dietToday(
    List<MealEntry> meals,
    int dailyCalorieTarget,
    MacroTargets macros,
  ) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final todays = meals
        .where((m) =>
            DateTime(m.eatenAt.year, m.eatenAt.month, m.eatenAt.day) ==
            todayOnly)
        .toList();

    if (todays.isEmpty) {
      return '今天还没有饮食记录。目标摄入 $dailyCalorieTarget 千卡。';
    }

    final summary = NutritionSummary.from(todays);
    final foods = todays.map((m) => m.foodName).toList();

    return '吃了 ${todays.length} 条：${foods.join('、')}\n'
        '实际摄入：${summary.calories.toStringAsFixed(0)} 千卡'
        '（目标 $dailyCalorieTarget），'
        '蛋白 ${summary.protein.toStringAsFixed(0)}g（目标 ${macros.protein}g）、'
        '碳水 ${summary.carbs.toStringAsFixed(0)}g（目标 ${macros.carbs}g）、'
        '脂肪 ${summary.fat.toStringAsFixed(0)}g（目标 ${macros.fat}g）';
  }

  /// 近期体重变化趋势
  static String _weightTrend(List<WeightLog> logs) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recent = logs.where((l) => l.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (recent.length < 2) {
      return recent.isEmpty
          ? '近期没有体重记录。'
          : '只有一条体重记录：${recent.first.weightKg.toStringAsFixed(1)}kg（${recent.first.date.month}月${recent.first.date.day}日）';
    }

    final first = recent.first.weightKg;
    final last = recent.last.weightKg;
    final diff = last - first;
    final direction = diff > 0.1 ? '上涨' : (diff < -0.1 ? '下降' : '基本持平');

    return '近 ${recent.length} 天，体重从 ${first.toStringAsFixed(1)}kg '
        '到 ${last.toStringAsFixed(1)}kg，$direction ${diff.abs().toStringAsFixed(1)}kg。';
  }

  // ═══════════════════════════════════════════════════════
  //  解析
  // ═══════════════════════════════════════════════════════

  static AiDailyAnalysis _parse(String jsonText) {
    final cleaned = _stripCodeFence(jsonText);
    final map = jsonDecode(cleaned) as Map<String, dynamic>;

    return AiDailyAnalysis(
      summary: map['summary'] as String? ?? '',
      workoutReview: map['workoutReview'] as String? ?? '',
      dietReview: map['dietReview'] as String? ?? '',
      suggestions: (map['suggestions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      tomorrowPlan: map['tomorrowPlan'] as String? ?? '',
    );
  }

  static String _stripCodeFence(String text) {
    var s = text.trim();
    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) s = s.substring(firstNewline + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }
}

/// 今日分析结果
class AiDailyAnalysis {
  final String summary;
  final String workoutReview;
  final String dietReview;
  final List<String> suggestions;
  final String tomorrowPlan;

  const AiDailyAnalysis({
    required this.summary,
    required this.workoutReview,
    required this.dietReview,
    required this.suggestions,
    required this.tomorrowPlan,
  });
}

/// 分析结果（成功/失败二合一）
class AiAnalysisResult {
  final bool success;
  final AiDailyAnalysis? analysis;
  final String? error;

  const AiAnalysisResult._({
    required this.success,
    this.analysis,
    this.error,
  });

  factory AiAnalysisResult.success(AiDailyAnalysis analysis) =>
      AiAnalysisResult._(success: true, analysis: analysis);

  factory AiAnalysisResult.failure(String error) =>
      AiAnalysisResult._(success: false, error: error);
}
