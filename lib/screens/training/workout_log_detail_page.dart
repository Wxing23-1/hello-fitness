import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/preset_plans.dart';
import '../../models/training_plan.dart';
import '../../models/workout_log.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';

/// 训练记录详情页
///
/// 展示某次训练的完整数据：每个动作做了几组、每组多少次、用了多重。
/// 这是训练历史的下一层 —— 列表看概要，这里看细节。
class WorkoutLogDetailPage extends StatelessWidget {
  final WorkoutLog log;

  const WorkoutLogDetailPage({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    // 找出这条记录对应的计划和训练日
    //
    // 可能找不到：AI 计划被删了、或者预置计划在版本更新后改了 id。
    // 这种情况下动作名显示成「动作 1」这样的占位，而不是让页面崩掉
    final plan = _findPlan(store);
    final day = _findDay(plan);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(day?.name ?? '训练记录'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 概要卡
          _buildSummaryCard(plan, day),
          const SizedBox(height: 16),

          // 感受和备注
          if (log.feeling != null || log.note != null) ...[
            _buildFeelingCard(),
            const SizedBox(height: 16),
          ],

          // 动作明细
          Text(
            '动作明细',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),

          if (log.exercises.isEmpty)
            _buildNoExercises()
          else
            ...log.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exerciseLog = entry.value;

              // 从计划里查这个动作的详细信息（名称、目标值）
              final exercise = _findExercise(day, exerciseLog.exerciseId);

              return _ExerciseLogCard(
                number: index + 1,
                exerciseLog: exerciseLog,
                exercise: exercise,
              );
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 查找记录对应的计划
  ///
  /// 先在预置计划里找，找不到再去 AI 计划里找
  TrainingPlan? _findPlan(UserStore store) {
    final preset = PresetPlans.getById(log.planId);
    if (preset != null) return preset;

    for (final p in store.aiPlans) {
      if (p.id == log.planId) return p;
    }
    return null;
  }

  /// 查找记录对应的训练日
  TrainingDay? _findDay(TrainingPlan? plan) {
    if (plan == null) return null;

    for (final d in plan.days) {
      if (d.id == log.dayId) return d;
    }
    return null;
  }

  /// 按 id 查找动作
  Exercise? _findExercise(TrainingDay? day, String exerciseId) {
    if (day == null) return null;

    for (final e in day.exercises) {
      if (e.id == exerciseId) return e;
    }
    return null;
  }

  /// 概要卡：时间、用时、总组数、总次数
  Widget _buildSummaryCard(TrainingPlan? plan, TrainingDay? day) {
    // 总组数和总次数
    final totalSets = log.exercises.fold(0, (s, e) => s + e.completedSets);
    final totalReps = log.exercises.fold(0, (s, e) => s + e.totalReps);

    // 类别决定配色，和计划列表页保持一致
    final category = day?.category ?? TrainingCategory.mixed;
    final colors = _categoryGradient(category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 完成时间
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _formatFullTime(log.completedAt),
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              const Spacer(),
              // 所属计划
              if (plan != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    plan.name,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 三个关键数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bigStat(formatDuration(log.durationMinutes), '用时'),
              _bigStat('$totalSets', '总组数'),
              _bigStat('$totalReps', '总次数'),
            ],
          ),
        ],
      ),
    );
  }

  /// 大号数据块
  Widget _bigStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  /// 感受评分和备注
  Widget _buildFeelingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 星级评分
          if (log.feeling != null)
            Row(
              children: [
                Text(
                  '训练感受',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(width: 10),
                // 画 5 颗星，已评分的填实心
                ...List.generate(5, (i) {
                  final filled = i < log.feeling!;
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 16,
                    color: filled ? Colors.amber.shade700 : Colors.grey.shade400,
                  );
                }),
              ],
            ),

          // 备注
          if (log.note != null && log.note!.isNotEmpty) ...[
            if (log.feeling != null) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 15,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    log.note!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 没有动作记录时的提示
  ///
  /// 理论上不该出现（一组都没做完就不会存记录），
  /// 但万一数据异常，给个明确提示比空白好
  Widget _buildNoExercises() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        '这条记录没有动作明细',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
    );
  }

  /// 类别对应的渐变色
  List<Color> _categoryGradient(TrainingCategory category) {
    switch (category) {
      case TrainingCategory.aerobic:
        return [Colors.teal.shade400, Colors.teal.shade300];
      case TrainingCategory.anaerobic:
        return [Colors.deepPurple.shade400, Colors.deepPurple.shade300];
      case TrainingCategory.mixed:
        return [Colors.orange.shade400, Colors.deepOrange.shade300];
    }
  }

  /// 格式化完整时间：10月22日 19:30
  String _formatFullTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${formatDateCn(dt)} $h:$m';
  }
}

/// 单个动作的完成记录卡片
class _ExerciseLogCard extends StatelessWidget {
  /// 序号（从 1 开始）
  final int number;

  /// 这个动作的完成数据
  final ExerciseLog exerciseLog;

  /// 计划里的动作定义，可能为 null（计划已删除）
  final Exercise? exercise;

  const _ExerciseLogCard({
    required this.number,
    required this.exerciseLog,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 序号
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 动作名
              Expanded(
                child: Text(
                  // 计划被删了就显示占位名
                  exercise?.name ?? '动作 $number',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 完成组数
              Text(
                '${exerciseLog.completedSets} 组',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 每组的实际数据
          _buildSetChips(),

          // 目标对比：实际做的和计划要求的差多少
          if (exercise != null) ...[
            const SizedBox(height: 8),
            _buildTargetCompare(),
          ],
        ],
      ),
    );
  }

  /// 每组数据做成小标签横排
  Widget _buildSetChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: exerciseLog.repsPerSet.asMap().entries.map((entry) {
        final setIndex = entry.key + 1;
        final reps = entry.value;

        // 按时间计量的动作显示「秒」
        final unit = exercise?.isTimeBased == true ? '秒' : '次';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            // 第N组：12次
            '$setIndex组 · $reps$unit',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade800,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 目标对比行
  Widget _buildTargetCompare() {
    final ex = exercise!;

    // 计划要求的总次数 vs 实际完成
    final targetTotal = ex.sets * (ex.reps > 0 ? ex.reps : 0);
    final actualTotal = exerciseLog.totalReps;

    // 没有明确目标次数（力竭）就不做对比
    final hasTarget = ex.reps > 0;

    return Row(
      children: [
        Icon(Icons.flag_outlined, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(
          '目标 ${ex.targetText}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),

        if (hasTarget) ...[
          const Spacer(),
          // 完成率标签
          _buildCompletionTag(actualTotal, targetTotal),
        ],

        // 用了重量就显示
        if (exerciseLog.weight != null && exerciseLog.weight! > 0) ...[
          const SizedBox(width: 8),
          Icon(Icons.fitness_center, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 3),
          Text(
            '${exerciseLog.weight!.toStringAsFixed(1)}kg',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  /// 完成率标签：达标绿色、未达标橙色、超额蓝色
  Widget _buildCompletionTag(int actual, int target) {
    if (target == 0) return const SizedBox.shrink();

    final ratio = actual / target;

    final (color, text) = switch (ratio) {
      // 超出 5% 以上算超额
      > 1.05 => (Colors.blue, '超额完成'),
      // 达到 95% 算达标
      >= 0.95 => (Colors.green, '达标'),
      // 80% 以上算基本完成
      >= 0.8 => (Colors.orange, '${(ratio * 100).round()}%'),
      // 低于 80%
      _ => (Colors.deepOrange, '${(ratio * 100).round()}%'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
