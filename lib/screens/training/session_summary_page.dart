import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training_plan.dart';
import '../../models/workout_log.dart';
import '../../models/workout_record.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';

/// 训练总结页
///
/// 显示本次训练的完成情况，可以打分和写备注，点保存后生成 WorkoutLog。
class SessionSummaryPage extends StatefulWidget {
  final TrainingPlan plan;
  final TrainingDay day;
  final List<List<SetLog>> completedSets;
  final Duration duration;
  final DateTime startTime;

  const SessionSummaryPage({
    super.key,
    required this.plan,
    required this.day,
    required this.completedSets,
    required this.duration,
    required this.startTime,
  });

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  /// 感受评分（1-5 星）
  int _feeling = 3;

  /// 备注
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// 保存记录
  void _save() {
    // 把 completedSets 转成 ExerciseLog
    final exerciseLogs = <ExerciseLog>[];
    for (var i = 0; i < widget.day.exercises.length; i++) {
      final exercise = widget.day.exercises[i];
      final sets = widget.completedSets[i];

      // 只记录完成的组
      final completedSetsData = sets.where((s) => s.completed).toList();
      if (completedSetsData.isEmpty) continue; // 一组都没做完就跳过

      exerciseLogs.add(ExerciseLog(
        exerciseId: exercise.id,
        completedSets: completedSetsData.length,
        repsPerSet: completedSetsData.map((s) => s.actualReps).toList(),
        weight: completedSetsData.first.weight == 0
            ? null
            : completedSetsData.first.weight,
      ));
    }

    final note = _noteController.text.trim();

    // 时长至少记 1 分钟 —— 练了但显示 0 分钟会很奇怪
    final minutes = widget.duration.inMinutes.clamp(1, 999);

    final log = WorkoutLog.create(
      planId: widget.plan.id,
      dayId: widget.day.id,
      durationMinutes: minutes,
      exercises: exerciseLogs,
      feeling: _feeling,
      note: note.isEmpty ? null : note,
    );

    final store = context.read<UserStore>();
    store.addWorkoutLog(log);

    // 同时生成一条 WorkoutRecord
    //
    // 为什么要存两份：
    // WorkoutLog 是详细记录（每个动作每组做了多少），用于回看训练细节；
    // WorkoutRecord 是概要记录，个人中心的「本周训练 X/4 次」、累计时长、
    // 累计消耗这些统计读的都是它。
    // 不同时存的话，练完一整天计划，统计数字还是 0。
    store.addRecord(_buildRecord(store, minutes, note));

    // 返回训练中心（清空整个返回栈）
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// 把本次训练转成一条概要记录
  WorkoutRecord _buildRecord(UserStore store, int minutes, String note) {
    final category = widget.day.category;

    return WorkoutRecord(
      // 用时间戳保证 id 唯一
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      type: _mapToWorkoutType(category),
      date: DateTime.now(),
      durationMinutes: minutes,
      // 按用户实际体重和训练类别估算消耗
      calories: estimateCalories(
        durationMinutes: minutes,
        weightKg: store.profile.weightKg,
        met: category.met,
      ),
      // 备注留空时自动写上练的是哪一天，方便在历史列表里认出来
      note: note.isEmpty ? '完成「${widget.day.name}」' : note,
    );
  }

  /// 训练类别映射到运动类型
  ///
  /// WorkoutRecord 的 type 是按运动项目分的（跑步/力量/HIIT…），
  /// 而计划里的训练日是按代谢类型分的（有氧/无氧/混合），
  /// 这里取每类最有代表性的项目
  WorkoutType _mapToWorkoutType(TrainingCategory category) {
    switch (category) {
      case TrainingCategory.aerobic:
        return WorkoutType.running;
      case TrainingCategory.anaerobic:
        return WorkoutType.strength;
      case TrainingCategory.mixed:
        return WorkoutType.hiit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = widget.completedSets
        .expand((sets) => sets)
        .where((s) => s.completed)
        .length;

    // 估算本次消耗，和保存时用的是同一套算法
    final calories = estimateCalories(
      durationMinutes: widget.duration.inMinutes.clamp(1, 999),
      weightKg: context.read<UserStore>().profile.weightKg,
      met: widget.day.category.met,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('训练完成'),
        // 左上角隐藏返回键，防止用户误返回到执行页
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 庆祝图标 ──
          const Icon(
            Icons.emoji_events,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),

          // ── 标题 ──
          const Text(
            '太棒了！',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            '完成了「${widget.day.name}」',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // ── 统计卡片 ──
          _buildStatsCard(totalSets, calories),

          const SizedBox(height: 20),

          // ── 感受评分 ──
          const Text(
            '今天感觉怎么样？',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildFeelingPicker(),

          const SizedBox(height: 20),

          // ── 备注 ──
          const Text(
            '备注（可选）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '记录今天的状态、感受或需要注意的地方',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          // ── 保存按钮 ──
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('保存记录'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 12),

          // ── 放弃保存 ──
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('不保存记录'),
                  content: const Text('确定不保存吗？训练数据会丢失。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // 返回训练中心
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        '放弃',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Text('不保存'),
          ),
        ],
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCard(int totalSets, int calories) {
    final minutes = widget.duration.inMinutes;
    final seconds = widget.duration.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _statRow(
            icon: Icons.timer,
            label: '用时',
            value: minutes > 0 ? '$minutes分$seconds秒' : '$seconds秒',
          ),
          const Divider(color: Colors.white54, height: 24),
          _statRow(
            icon: Icons.fitness_center,
            label: '完成动作',
            value: '${widget.day.exercises.length} 个',
          ),
          const Divider(color: Colors.white54, height: 24),
          _statRow(
            icon: Icons.repeat,
            label: '完成组数',
            value: '$totalSets 组',
          ),
          const Divider(color: Colors.white54, height: 24),
          _statRow(
            icon: Icons.local_fire_department,
            label: '估算消耗',
            value: '$calories 千卡',
          ),
        ],
      ),
    );
  }

  /// 统计行
  Widget _statRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 感受评分选择器
  Widget _buildFeelingPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        final star = i + 1;
        final selected = _feeling == star;

        return GestureDetector(
          onTap: () => setState(() => _feeling = star),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: selected ? Colors.amber.shade100 : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.amber : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: Icon(
              selected ? Icons.star : Icons.star_border,
              color: selected ? Colors.amber : Colors.grey.shade500,
              size: 28,
            ),
          ),
        );
      }),
    );
  }
}
