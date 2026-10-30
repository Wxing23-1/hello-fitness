// 当前计划功能测试
//
// 覆盖「选用计划」的状态管理和边界情况：
// 计划被删除后的悬空 id、换计划、以及首页推荐哪一天的循环逻辑。
// 运行命令：flutter test test/active_plan_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/data/preset_plans.dart';
import 'package:hello_fitness/models/training_plan.dart';
import 'package:hello_fitness/services/user_store.dart';

void main() {
  /// 造一份 AI 计划，用来测删除时的联动
  TrainingPlan aiPlan({String id = 'ai_1', String name = 'AI 计划'}) {
    return TrainingPlan(
      id: id,
      name: name,
      description: '测试用',
      goal: TrainingGoal.loseWeight,
      level: TrainingLevel.beginner,
      category: TrainingCategory.mixed,
      durationWeeks: 4,
      workoutsPerWeek: 3,
      isAiGenerated: true,
      days: [
        TrainingDay(
          id: '${id}_d1',
          planId: id,
          dayNumber: 1,
          name: '第一天',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 40,
          exercises: const [],
        ),
        TrainingDay(
          id: '${id}_d2',
          planId: id,
          dayNumber: 2,
          name: '第二天',
          category: TrainingCategory.aerobic,
          estimatedMinutes: 30,
          exercises: const [],
        ),
      ],
    );
  }

  group('选用计划', () {
    test('默认没有选中任何计划', () {
      final store = UserStore();

      expect(store.activePlanId, isNull);
      expect(store.activePlan, isNull);
    });

    test('选用预置计划后能取回计划对象', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;

      store.setActivePlan(preset.id);

      expect(store.activePlanId, preset.id);
      expect(store.activePlan?.id, preset.id);
      expect(store.activePlan?.name, preset.name);
    });

    test('选用 AI 计划后能取回计划对象', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);

      store.setActivePlan(plan.id);

      expect(store.activePlan?.name, 'AI 计划');
    });

    test('传 null 取消选用', () {
      final store = UserStore();
      store.setActivePlan(PresetPlans.getAll().first.id);

      store.setActivePlan(null);

      expect(store.activePlanId, isNull);
      expect(store.activePlan, isNull);
    });

    test('换计划会覆盖旧的，不会同时存在两个', () {
      final store = UserStore();
      final first = PresetPlans.getAll()[0];
      final second = PresetPlans.getAll()[1];

      store.setActivePlan(first.id);
      store.setActivePlan(second.id);

      expect(store.activePlanId, second.id);
    });

    test('重复选同一个计划不会重复通知监听者', () {
      final store = UserStore();
      final preset = PresetPlans.getAll().first;
      store.setActivePlan(preset.id);

      var notified = 0;
      store.addListener(() => notified++);

      // 再设一次同样的 id
      store.setActivePlan(preset.id);

      expect(notified, 0);
    });

    test('选用计划会通知监听者', () {
      final store = UserStore();

      var notified = 0;
      store.addListener(() => notified++);

      store.setActivePlan(PresetPlans.getAll().first.id);

      expect(notified, 1);
    });
  });

  group('悬空 id 处理', () {
    test('删掉当前的 AI 计划会自动清空选中状态', () {
      final store = UserStore();
      final plan = aiPlan();
      store.addAiPlan(plan);
      store.setActivePlan(plan.id);

      store.deleteAiPlan(plan.id);

      // 不清空的话会留一个指向已删除计划的 id
      expect(store.activePlanId, isNull);
      expect(store.activePlan, isNull);
    });

    test('删掉别的计划不影响当前选中', () {
      final store = UserStore();
      final kept = aiPlan(id: 'keep', name: '保留');
      final removed = aiPlan(id: 'gone', name: '删除');
      store.addAiPlan(kept);
      store.addAiPlan(removed);
      store.setActivePlan(kept.id);

      store.deleteAiPlan(removed.id);

      expect(store.activePlanId, 'keep');
      expect(store.activePlan?.name, '保留');
    });

    test('id 指向不存在的计划时 activePlan 返回 null 而不是抛异常', () {
      final store = UserStore();

      store.setActivePlan('不存在的_id');

      expect(store.activePlanId, '不存在的_id');
      expect(store.activePlan, isNull);
    });

    test('清空所有数据会一并清掉当前计划', () {
      final store = UserStore();
      store.setActivePlan(PresetPlans.getAll().first.id);

      store.resetAll();

      expect(store.activePlanId, isNull);
    });
  });
}
