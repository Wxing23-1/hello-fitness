// 计划编辑测试
//
// 重点测 savePlan 的两条路径：AI 计划原地覆盖、预置计划另存副本。
// 预置计划是 const 常量改不了，副本的 id 和 days.planId 都要重映射，
// 漏一处就会让训练记录挂到错误的计划上。
//
// 运行命令：flutter test test/plan_edit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/data/preset_plans.dart';
import 'package:hello_fitness/models/training_plan.dart';
import 'package:hello_fitness/services/user_store.dart';

void main() {
  /// 造一份 AI 计划
  TrainingPlan aiPlan({String id = 'ai_1', String name = 'AI 计划'}) {
    return TrainingPlan(
      id: id,
      name: name,
      description: '测试用',
      goal: TrainingGoal.gainMuscle,
      level: TrainingLevel.intermediate,
      category: TrainingCategory.anaerobic,
      durationWeeks: 4,
      workoutsPerWeek: 2,
      isAiGenerated: true,
      days: [
        TrainingDay(
          id: '${id}_d1',
          planId: id,
          dayNumber: 1,
          name: '练胸',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 40,
          exercises: const [
            Exercise(
              id: 'e1',
              name: '卧推',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 10,
              restSeconds: 90,
              muscleGroup: '胸肌',
              equipment: '杠铃',
              targetWeightKg: 50,
            ),
            Exercise(
              id: 'e2',
              name: '飞鸟',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '胸肌',
              equipment: '哑铃',
              targetWeightKg: 12,
            ),
          ],
        ),
      ],
    );
  }

  group('Exercise.copyWith', () {
    const base = Exercise(
      id: 'e1',
      name: '卧推',
      category: TrainingCategory.anaerobic,
      sets: 4,
      reps: 10,
      restSeconds: 90,
      muscleGroup: '胸肌',
      equipment: '杠铃',
      tips: '注意沉肩',
      targetWeightKg: 50,
    );

    test('只改指定字段，其余保持', () {
      final updated = base.copyWith(sets: 5);

      expect(updated.sets, 5);
      expect(updated.reps, 10);
      expect(updated.name, '卧推');
      expect(updated.targetWeightKg, 50);
      // id 不能变，否则训练记录会对不上
      expect(updated.id, 'e1');
    });

    test('改重量', () {
      expect(base.copyWith(targetWeightKg: 60).targetWeightKg, 60);
    });

    test('clearTargetWeight 能把重量清成 null', () {
      final updated = base.copyWith(clearTargetWeight: true);

      // 普通 copyWith(targetWeightKg: null) 会被当成「不改」，
      // 所以需要单独的开关来表达「改成 null」
      expect(updated.targetWeightKg, isNull);
      expect(updated.sets, 4);
    });

    test('clearEquipment 和 clearTips 同理', () {
      expect(base.copyWith(clearEquipment: true).equipment, isNull);
      expect(base.copyWith(clearTips: true).tips, isNull);
    });

    test('不传任何参数等于原样复制', () {
      final copy = base.copyWith();

      expect(copy.sets, base.sets);
      expect(copy.equipment, base.equipment);
      expect(copy.targetWeightKg, base.targetWeightKg);
      expect(copy.tips, base.tips);
    });
  });

  group('weightText', () {
    test('整数不带小数点', () {
      const ex = Exercise(
        id: 'e',
        name: 'x',
        category: TrainingCategory.anaerobic,
        sets: 3,
        reps: 10,
        restSeconds: 60,
        muscleGroup: 'x',
        targetWeightKg: 20,
      );

      expect(ex.weightText, '20kg');
    });

    test('小数保留', () {
      const ex = Exercise(
        id: 'e',
        name: 'x',
        category: TrainingCategory.anaerobic,
        sets: 3,
        reps: 10,
        restSeconds: 60,
        muscleGroup: 'x',
        targetWeightKg: 12.5,
      );

      expect(ex.weightText, '12.5kg');
    });

    test('没有重量或为 0 时返回 null', () {
      const noWeight = Exercise(
        id: 'e',
        name: 'x',
        category: TrainingCategory.aerobic,
        sets: 3,
        reps: 10,
        restSeconds: 60,
        muscleGroup: 'x',
      );
      const zero = Exercise(
        id: 'e',
        name: 'x',
        category: TrainingCategory.aerobic,
        sets: 3,
        reps: 10,
        restSeconds: 60,
        muscleGroup: 'x',
        targetWeightKg: 0,
      );

      expect(noWeight.weightText, isNull);
      expect(zero.weightText, isNull);
    });
  });

  group('savePlan - AI 计划', () {
    test('原地覆盖，不新增一份', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);

      final edited = plan.copyWith(name: '改过的名字');
      final saved = store.savePlan(edited);

      expect(store.aiPlans.length, 1);
      expect(saved.id, plan.id);
      expect(store.aiPlans.first.name, '改过的名字');
    });

    test('改动作参数能存下来', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);

      // 把第一个动作的组数从 4 改成 6
      final day = plan.days.first;
      final newEx = day.exercises.first.copyWith(sets: 6);
      final newDay = day.copyWith(exercises: [newEx, day.exercises[1]]);

      store.savePlan(plan.copyWith(days: [newDay]));

      expect(store.aiPlans.first.days.first.exercises.first.sets, 6);
    });

    test('删动作后只剩一个', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);

      final day = plan.days.first;
      final newDay = day.copyWith(exercises: [day.exercises.first]);

      store.savePlan(plan.copyWith(days: [newDay]));

      expect(store.aiPlans.first.days.first.exercises.length, 1);
      expect(store.aiPlans.first.days.first.exercises.first.name, '卧推');
    });

    test('调顺序后次序改变', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);

      final day = plan.days.first;
      // 把两个动作对调
      final newDay = day.copyWith(
        exercises: [day.exercises[1], day.exercises[0]],
      );

      store.savePlan(plan.copyWith(days: [newDay]));

      expect(store.aiPlans.first.days.first.exercises.first.name, '飞鸟');
    });

    test('会通知监听者', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);

      var notified = 0;
      store.addListener(() => notified++);

      store.savePlan(plan.copyWith(name: '新名字'));

      expect(notified, 1);
    });
  });

  group('savePlan - 预置计划', () {
    test('另存为副本，不动原预置', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;

      final saved = store.savePlan(preset.copyWith(name: '随便改个名'));

      // 副本是新 id
      expect(saved.id, isNot(preset.id));
      expect(saved.id, startsWith('plan_custom_'));
      // 原预置还在，没被改动
      expect(PresetPlans.getById(preset.id)?.name, preset.name);
    });

    test('副本名字带「我的版本」后缀', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;

      final saved = store.savePlan(preset);

      expect(saved.name, contains('我的版本'));
    });

    test('副本进入 aiPlans 列表，能在训练页看到', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;

      expect(store.aiPlans, isEmpty);

      store.savePlan(preset);

      expect(store.aiPlans.length, 1);
    });

    test('每个训练日的 planId 指向副本而不是原预置', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;

      final saved = store.savePlan(preset);

      // 不重映射的话，训练记录会挂到原预置上，
      // 首页「今天练哪天」的推进也会算错
      for (final day in saved.days) {
        expect(day.planId, saved.id);
      }
    });

    test('改了两次会产生两份副本', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;

      store.savePlan(preset);
      store.savePlan(preset);

      // 每次都是基于原预置新建，所以是两份。
      // 用户应该改副本而不是反复改原预置
      expect(store.aiPlans.length, 2);
    });

    test('原来选用的是这个预置，改完自动切到副本', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;
      store.setActivePlan(preset.id);

      final saved = store.savePlan(preset);

      // 不切的话用户以为改了，其实还在练原版
      expect(store.activePlanId, saved.id);
      expect(store.activePlan?.name, contains('我的版本'));
    });

    test('选用的是别的计划，改完不动当前选择', () {
      final store = UserStore();
      final other = PresetPlans.getAll()[1];
      store.setActivePlan(other.id);

      store.savePlan(PresetPlans.getAll().first);

      expect(store.activePlanId, other.id);
    });
  });

  group('TrainingDay.copyWith', () {
    test('改名和时长', () {
      final day = aiPlan().days.first;

      final updated = day.copyWith(name: '新名字', estimatedMinutes: 55);

      expect(updated.name, '新名字');
      expect(updated.estimatedMinutes, 55);
      expect(updated.id, day.id);
      expect(updated.exercises.length, day.exercises.length);
    });

    test('改 planId（另存副本时用）', () {
      final day = aiPlan().days.first;

      expect(day.copyWith(planId: 'new_plan').planId, 'new_plan');
    });
  });
}
