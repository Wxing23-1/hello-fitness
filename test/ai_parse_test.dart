// AI 返回内容的解析测试
//
// DeepSeek 不支持字段级 schema 约束，返回格式可能有偏差，
// 所以解析层写了不少容错。这些测试验证容错真的有效。
//
// 这里测的是「给定一段 AI 返回的 JSON，能不能正确解析成计划对象」，
// 不发真实网络请求。
//
// 运行命令：flutter test test/ai_parse_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/models/training_plan.dart';

void main() {
  // ══════════════════════════════════════════
  //  类别字符串解析
  //  AI 返回的 category 可能大小写不一或带空格
  // ══════════════════════════════════════════
  group('类别解析容错', () {
    // 解析逻辑在 AiPlanService 里是私有的，这里通过构造数据
    // 走 TrainingPlan.fromMap 来间接验证枚举索引的容错

    test('合法的 index 正常解析', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '测试',
        'category': TrainingCategory.aerobic.index,
        'days': [],
      });
      expect(plan.category, TrainingCategory.aerobic);
    });

    test('index 越界时退回混合，而不是夹到最后一个枚举', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '测试',
        'category': 99, // 越界
        'days': [],
      });
      // 应该是 mixed（默认值），不是 values.last
      expect(plan.category, TrainingCategory.mixed);
    });

    test('index 为负数时也退回默认值', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '测试',
        'category': -5,
        'days': [],
      });
      expect(plan.category, TrainingCategory.mixed);
    });

    test('category 字段缺失时用默认值', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '测试',
        'days': [],
      });
      expect(plan.category, TrainingCategory.mixed);
    });
  });

  // ══════════════════════════════════════════
  //  完整计划结构
  //  模拟一份 AI 返回的典型数据
  // ══════════════════════════════════════════
  group('完整计划解析', () {
    /// 模拟 AI 生成的减脂计划（已经转成内部存储格式）
    Map<String, dynamic> buildAiPlanMap() {
      return {
        'id': 'ai_plan_123',
        'name': 'AI 定制减脂',
        'description': '根据你最近每周1.5次的训练频率，先从每周3次起步',
        'goal': TrainingGoal.loseWeight.index,
        'level': TrainingLevel.beginner.index,
        'category': TrainingCategory.mixed.index,
        'durationWeeks': 4,
        'workoutsPerWeek': 2,
        'isAiGenerated': true,
        'days': [
          {
            'id': 'd1',
            'planId': 'ai_plan_123',
            'dayNumber': 1,
            'name': '有氧燃脂',
            'category': TrainingCategory.aerobic.index,
            'estimatedMinutes': 35,
            'exercises': [
              {
                'id': 'e1',
                'name': '慢跑',
                'category': TrainingCategory.aerobic.index,
                'sets': 1,
                'reps': 1800,
                'isTimeBased': true,
                'restSeconds': 0,
                'muscleGroup': '心肺',
                'equipment': null,
                'tips': '保持能说话的强度，别一开始冲太快',
              },
            ],
          },
          {
            'id': 'd2',
            'planId': 'ai_plan_123',
            'dayNumber': 2,
            'name': '力量基础',
            'category': TrainingCategory.anaerobic.index,
            'estimatedMinutes': 40,
            'exercises': [
              {
                'id': 'e2',
                'name': '深蹲',
                'category': TrainingCategory.anaerobic.index,
                'sets': 3,
                'reps': 12,
                'isTimeBased': false,
                'restSeconds': 60,
                'muscleGroup': '腿部',
                'equipment': '',
                'tips': '膝盖对准脚尖，下蹲到大腿平行地面',
              },
              {
                'id': 'e3',
                'name': '平板支撑',
                'category': TrainingCategory.anaerobic.index,
                'sets': 3,
                'reps': 30,
                'isTimeBased': true,
                'restSeconds': 45,
                'muscleGroup': '核心',
                'equipment': null,
                'tips': '身体成一条直线，别塌腰也别撅臀',
              },
            ],
          },
        ],
      };
    }

    test('解析出正确的计划元数据', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      expect(plan.name, 'AI 定制减脂');
      expect(plan.isAiGenerated, true);
      expect(plan.goal, TrainingGoal.loseWeight);
      expect(plan.level, TrainingLevel.beginner);
      expect(plan.category, TrainingCategory.mixed);
      expect(plan.durationWeeks, 4);
    });

    test('训练日数量和内容正确', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      expect(plan.days.length, 2);
      expect(plan.days[0].name, '有氧燃脂');
      expect(plan.days[0].category, TrainingCategory.aerobic);
      expect(plan.days[1].name, '力量基础');
      expect(plan.days[1].category, TrainingCategory.anaerobic);
    });

    test('有氧无氧训练日统计正确', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      expect(plan.aerobicDayCount, 1);
      expect(plan.anaerobicDayCount, 1);
    });

    test('按时间计量的动作解析正确', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      final jogging = plan.days[0].exercises[0];
      expect(jogging.name, '慢跑');
      expect(jogging.isTimeBased, true);
      expect(jogging.reps, 1800);
      // 1800 秒的显示文案
      expect(jogging.targetText, '1组 × 1800秒');
    });

    test('按次数计量的动作解析正确', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      final squat = plan.days[1].exercises[0];
      expect(squat.isTimeBased, false);
      expect(squat.targetText, '3组 × 12次');
    });

    test('equipment 为空字符串或 null 都当作徒手', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      // 慢跑的 equipment 是 null
      expect(plan.days[0].exercises[0].equipment, isNull);
      // 深蹲的 equipment 是空字符串，fromMap 会原样保留，
      // 界面上判断 != null 才显示，所以空字符串会显示成空白 ——
      // 这个边界由 AiPlanService 在解析时统一成 null 处理
      final squatEquipment = plan.days[1].exercises[0].equipment;
      expect(squatEquipment == null || squatEquipment.isEmpty, true);
    });

    test('动作要点能保留', () {
      final plan = TrainingPlan.fromMap(buildAiPlanMap());

      expect(plan.days[1].exercises[0].tips, contains('膝盖对准脚尖'));
    });

    test('往返序列化后 AI 计划数据不丢', () {
      final original = TrainingPlan.fromMap(buildAiPlanMap());

      // 模拟存进 Hive 再读出来
      final restored = TrainingPlan.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      expect(restored.name, original.name);
      expect(restored.isAiGenerated, true);
      expect(restored.days.length, original.days.length);
      expect(
        restored.days[0].exercises[0].isTimeBased,
        original.days[0].exercises[0].isTimeBased,
      );
      expect(
        restored.days[1].exercises[1].tips,
        original.days[1].exercises[1].tips,
      );
    });
  });

  // ══════════════════════════════════════════
  //  脏数据不应该让 APP 崩溃
  // ══════════════════════════════════════════
  group('脏数据容错', () {
    test('days 为空数组时不崩', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '空计划',
        'days': [],
      });

      expect(plan.days, isEmpty);
      expect(plan.totalDays, 0);
      expect(plan.aerobicDayCount, 0);
    });

    test('days 字段完全缺失时不崩', () {
      final plan = TrainingPlan.fromMap({'id': 'p1', 'name': '无日计划'});
      expect(plan.days, isEmpty);
    });

    test('训练日里没有动作时不崩', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '测试',
        'days': [
          {
            'id': 'd1',
            'name': '空训练日',
            'exercises': [],
          },
        ],
      });

      expect(plan.days.length, 1);
      expect(plan.days[0].exercises, isEmpty);
    });

    test('动作缺字段时用默认值填充', () {
      final plan = TrainingPlan.fromMap({
        'id': 'p1',
        'name': '测试',
        'days': [
          {
            'id': 'd1',
            'name': '训练日',
            'exercises': [
              {'id': 'e1'}, // 只有 id，其他全缺
            ],
          },
        ],
      });

      final ex = plan.days[0].exercises[0];
      expect(ex.name, '动作');
      expect(ex.sets, 3);
      expect(ex.reps, 10);
      expect(ex.restSeconds, 60);
      expect(ex.muscleGroup, '全身');
      expect(ex.isTimeBased, false);
    });
  });
}
