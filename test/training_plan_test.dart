// 训练计划相关的单元测试
//
// 覆盖：有氧无氧分类、预置计划数据完整性、序列化往返。
// 运行命令：flutter test test/training_plan_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/data/preset_plans.dart';
import 'package:hello_fitness/models/training_plan.dart';
import 'package:hello_fitness/models/workout_record.dart';

void main() {
  // ══════════════════════════════════════════
  //  预置计划数据完整性
  // ══════════════════════════════════════════
  group('预置计划', () {
    test('一共有 4 套计划', () {
      expect(PresetPlans.getAll().length, 4);
    });

    test('每套计划的 id 都不重复', () {
      final ids = PresetPlans.getAll().map((p) => p.id).toList();
      // 转成 Set 后长度不变，说明没有重复
      expect(ids.toSet().length, ids.length);
    });

    test('每套计划的训练日数量等于每周训练次数', () {
      for (final plan in PresetPlans.getAll()) {
        expect(
          plan.totalDays,
          plan.workoutsPerWeek,
          reason: '${plan.name} 的训练日数量应该等于每周次数',
        );
      }
    });

    test('每个训练日都至少有一个动作', () {
      for (final plan in PresetPlans.getAll()) {
        for (final day in plan.days) {
          expect(
            day.exercises,
            isNotEmpty,
            reason: '${plan.name} 的「${day.name}」没有动作',
          );
        }
      }
    });

    test('所有动作 id 全局唯一', () {
      final allIds = <String>[];
      for (final plan in PresetPlans.getAll()) {
        for (final day in plan.days) {
          allIds.addAll(day.exercises.map((e) => e.id));
        }
      }
      expect(allIds.toSet().length, allIds.length);
    });

    test('训练日的 planId 和所属计划一致', () {
      for (final plan in PresetPlans.getAll()) {
        for (final day in plan.days) {
          expect(day.planId, plan.id, reason: '${day.name} 的 planId 不对');
        }
      }
    });

    test('组数和休息时间都是合理的正数', () {
      for (final plan in PresetPlans.getAll()) {
        for (final day in plan.days) {
          for (final ex in day.exercises) {
            expect(ex.sets, greaterThan(0), reason: '${ex.name} 组数应大于0');
            expect(ex.restSeconds, greaterThanOrEqualTo(0));
            // reps 要么是正数，要么是 -1（力竭）
            expect(ex.reps == -1 || ex.reps > 0, true,
                reason: '${ex.name} 的 reps 不合法');
          }
        }
      }
    });

    test('getById 能找到计划，找不到返回 null', () {
      expect(PresetPlans.getById('plan_pure_cardio'), isNotNull);
      expect(PresetPlans.getById('不存在的id'), isNull);
    });
  });

  // ══════════════════════════════════════════
  //  有氧 / 无氧分类
  // ══════════════════════════════════════════
  group('有氧无氧分类', () {
    test('纯有氧计划的整体类别是 aerobic', () {
      final cardio = PresetPlans.getById('plan_pure_cardio')!;
      expect(cardio.category, TrainingCategory.aerobic);
    });

    test('增肌计划的整体类别是 anaerobic', () {
      final muscle = PresetPlans.getById('plan_intermediate_muscle')!;
      expect(muscle.category, TrainingCategory.anaerobic);
    });

    test('增肌计划的所有训练日都是无氧', () {
      final muscle = PresetPlans.getById('plan_intermediate_muscle')!;
      for (final day in muscle.days) {
        expect(day.category, TrainingCategory.anaerobic);
      }
    });

    test('有氧计划里不应该出现纯无氧的训练日', () {
      final cardio = PresetPlans.getById('plan_pure_cardio')!;
      for (final day in cardio.days) {
        expect(day.category, isNot(TrainingCategory.anaerobic));
      }
    });

    test('getByCategory 按类别筛选', () {
      final aerobic = PresetPlans.getByCategory(TrainingCategory.aerobic);
      expect(aerobic.length, 1);
      expect(aerobic.first.id, 'plan_pure_cardio');

      final anaerobic = PresetPlans.getByCategory(TrainingCategory.anaerobic);
      expect(anaerobic.length, 1);

      // 混合类有 2 套：新手减脂和体能维持
      final mixed = PresetPlans.getByCategory(TrainingCategory.mixed);
      expect(mixed.length, 2);
    });

    test('混合计划能正确统计有氧和无氧训练日数量', () {
      final fatLoss = PresetPlans.getById('plan_beginner_fat_loss')!;

      // 新手减脂：第1天混合、第2天有氧、第3天无氧
      expect(fatLoss.aerobicDayCount, 1);
      expect(fatLoss.anaerobicDayCount, 1);
    });

    test('WorkoutType 都有对应的代谢类型', () {
      // 跑步、骑行、游泳、瑜伽是有氧
      expect(WorkoutType.running.energySystem, EnergySystem.aerobic);
      expect(WorkoutType.cycling.energySystem, EnergySystem.aerobic);
      expect(WorkoutType.swimming.energySystem, EnergySystem.aerobic);

      // 力量训练是无氧
      expect(WorkoutType.strength.energySystem, EnergySystem.anaerobic);

      // HIIT 是混合
      expect(WorkoutType.hiit.energySystem, EnergySystem.mixed);
    });
  });

  // ══════════════════════════════════════════
  //  动作目标文案
  // ══════════════════════════════════════════
  group('Exercise.targetText', () {
    test('按次数计量', () {
      const ex = Exercise(
        id: 'e1',
        name: '深蹲',
        category: TrainingCategory.anaerobic,
        sets: 4,
        reps: 12,
        restSeconds: 60,
        muscleGroup: '腿部',
      );
      expect(ex.targetText, '4组 × 12次');
    });

    test('按时间计量时显示秒', () {
      const ex = Exercise(
        id: 'e2',
        name: '平板支撑',
        category: TrainingCategory.anaerobic,
        sets: 3,
        reps: 30,
        isTimeBased: true,
        restSeconds: 60,
        muscleGroup: '核心',
      );
      expect(ex.targetText, '3组 × 30秒');
    });

    test('reps 为 -1 时显示力竭', () {
      const ex = Exercise(
        id: 'e3',
        name: '引体向上',
        category: TrainingCategory.anaerobic,
        sets: 4,
        reps: -1,
        restSeconds: 90,
        muscleGroup: '背阔肌',
      );
      expect(ex.targetText, '4组 × 力竭');
    });
  });

  // ══════════════════════════════════════════
  //  序列化往返
  //  AI 生成的计划要存到本地，存进去再读出来必须一模一样
  // ══════════════════════════════════════════
  group('序列化', () {
    test('计划 toMap/fromMap 往返后数据不变', () {
      final original = PresetPlans.getById('plan_intermediate_muscle')!;

      // 模拟真实存储流程：对象 → Map → JSON 字符串 → Map → 对象
      final json = jsonEncode(original.toMap());
      final restored = TrainingPlan.fromMap(jsonDecode(json) as Map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.goal, original.goal);
      expect(restored.level, original.level);
      expect(restored.category, original.category);
      expect(restored.durationWeeks, original.durationWeeks);
      expect(restored.workoutsPerWeek, original.workoutsPerWeek);
      expect(restored.days.length, original.days.length);
    });

    test('训练日和动作的嵌套结构能完整还原', () {
      final original = PresetPlans.getById('plan_beginner_fat_loss')!;
      final restored = TrainingPlan.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      // 逐个训练日比对
      for (var i = 0; i < original.days.length; i++) {
        final od = original.days[i];
        final rd = restored.days[i];

        expect(rd.name, od.name);
        expect(rd.category, od.category);
        expect(rd.dayNumber, od.dayNumber);
        expect(rd.exercises.length, od.exercises.length);

        // 逐个动作比对
        for (var j = 0; j < od.exercises.length; j++) {
          final oe = od.exercises[j];
          final re = rd.exercises[j];

          expect(re.name, oe.name);
          expect(re.category, oe.category);
          expect(re.sets, oe.sets);
          expect(re.reps, oe.reps);
          expect(re.isTimeBased, oe.isTimeBased);
          expect(re.restSeconds, oe.restSeconds);
          expect(re.muscleGroup, oe.muscleGroup);
          expect(re.equipment, oe.equipment);
          expect(re.tips, oe.tips);
        }
      }
    });

    test('isAiGenerated 标记能保留', () {
      const aiPlan = TrainingPlan(
        id: 'ai_test',
        name: 'AI 测试计划',
        description: '测试用',
        goal: TrainingGoal.loseWeight,
        level: TrainingLevel.beginner,
        category: TrainingCategory.mixed,
        durationWeeks: 4,
        workoutsPerWeek: 1,
        isAiGenerated: true,
        days: [
          TrainingDay(
            id: 'd1',
            planId: 'ai_test',
            dayNumber: 1,
            name: '测试日',
            category: TrainingCategory.mixed,
            estimatedMinutes: 30,
            exercises: [
              Exercise(
                id: 'e1',
                name: '测试动作',
                category: TrainingCategory.aerobic,
                sets: 3,
                reps: 10,
                restSeconds: 60,
                muscleGroup: '全身',
              ),
            ],
          ),
        ],
      );

      final restored = TrainingPlan.fromMap(
        jsonDecode(jsonEncode(aiPlan.toMap())) as Map,
      );

      expect(restored.isAiGenerated, true);
    });

    test('缺字段的脏数据不会崩，用默认值兜底', () {
      // 模拟旧版本存的数据，少了很多字段
      final incomplete = {
        'id': 'old_plan',
        'name': '旧计划',
      };

      final restored = TrainingPlan.fromMap(incomplete);

      expect(restored.id, 'old_plan');
      expect(restored.name, '旧计划');
      // 这些都退回默认值
      expect(restored.durationWeeks, 4);
      expect(restored.workoutsPerWeek, 3);
      expect(restored.days, isEmpty);
      expect(restored.isAiGenerated, false);
    });
  });

  // ══════════════════════════════════════════
  //  训练记录序列化
  // ══════════════════════════════════════════
  group('WorkoutRecord 序列化', () {
    test('往返后数据不变', () {
      final original = WorkoutRecord(
        id: 'w_test',
        type: WorkoutType.hiit,
        date: DateTime(2026, 10, 19, 15, 30),
        durationMinutes: 25,
        calories: 310,
        note: '测试备注',
      );

      final restored = WorkoutRecord.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      // DateTime 存的是毫秒时间戳，还原后应该完全相等
      expect(restored.date, original.date);
      expect(restored.durationMinutes, original.durationMinutes);
      expect(restored.calories, original.calories);
      expect(restored.note, original.note);
    });

    test('演示数据能全部序列化', () {
      for (final record in WorkoutRecord.demoRecords()) {
        final restored = WorkoutRecord.fromMap(
          jsonDecode(jsonEncode(record.toMap())) as Map,
        );
        expect(restored.id, record.id);
        expect(restored.type, record.type);
      }
    });
  });
}
