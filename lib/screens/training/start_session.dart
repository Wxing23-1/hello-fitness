import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training_plan.dart';
import '../../services/user_store.dart';
import 'workout_session_page.dart';

/// 启动训练，有未完成的草稿时先问要不要接着练
///
/// 抽成共用函数：详情页和首页都要开训练，恢复逻辑写两遍容易不一致。
Future<void> startWorkout(
  BuildContext context, {
  required TrainingPlan plan,
  required TrainingDay day,
}) async {
  final store = context.read<UserStore>();
  final draft = store.loadDraft();

  // 草稿得是同一个训练日的才有意义 —— 练胸的半场进度套不到腿上
  final canResume =
      draft != null && draft.planId == plan.id && draft.dayId == day.id;

  if (!canResume) {
    // 有草稿但对不上这个训练日，说明用户换了内容，旧草稿留着只会误导
    if (draft != null) store.clearDraft();

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionPage(day: day, plan: plan),
      ),
    );
    return;
  }

  final resume = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('继续上次训练'),
      content: Text(
        '上次练到第 ${draft.exerciseIndex + 1} 个动作，'
        '已完成 ${draft.completedSetCount} 组。\n\n'
        '要接着练，还是从头开始？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('从头开始'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('接着练'),
        ),
      ],
    ),
  );

  // 对话框被划掉，什么都不做
  if (resume == null || !context.mounted) return;

  // 选了从头开始就把草稿清掉，否则下次又会问一遍
  if (!resume) store.clearDraft();

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WorkoutSessionPage(
        day: day,
        plan: plan,
        resumeFrom: resume ? draft : null,
      ),
    ),
  );
}
