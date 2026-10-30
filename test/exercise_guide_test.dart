// 动作详解测试
//
// 验证 steps/mistakes 的默认值、序列化、以及预置数据的完整性。
// 运行命令：flutter test test/exercise_guide_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/data/preset_plans.dart';
import 'package:hello_fitness/models/training_plan.dart';

void main() {
  group('hasGuide', () {
    const noGuide = Exercise(
      id: 'e1',
      name: '开合跳',
      category: TrainingCategory.aerobic,
      sets: 3,
      reps: 40,
      restSeconds: 30,
      muscleGroup: '全身',
    );

    test('没有 steps 和 mistakes 时为 false', () {
      expect(noGuide.hasGuide, isFalse);
      // 默认值要是空列表而不是 null，省得每处都判空
      expect(noGuide.steps, isEmpty);
      expect(noGuide.mistakes, isEmpty);
    });

    test('只有 steps 也算有详解', () {
      final ex = noGuide.copyWith(steps: ['第一步']);
      expect(ex.hasGuide, isTrue);
    });

    test('只有 mistakes 也算有详解', () {
      final ex = noGuide.copyWith(mistakes: ['别塌腰']);
      expect(ex.hasGuide, isTrue);
    });
  });

  group('copyWith 保留详解', () {
    const base = Exercise(
      id: 'e1',
      name: '深蹲',
      category: TrainingCategory.anaerobic,
      sets: 4,
      reps: 12,
      restSeconds: 75,
      muscleGroup: '腿部',
      steps: ['下蹲', '起身'],
      mistakes: ['膝盖内扣'],
    );

    test('改组数不会把详解清空', () {
      // 编辑页改参数时如果 copyWith 漏了这两个字段，
      // 用户一改组数详解就没了
      final updated = base.copyWith(sets: 5);

      expect(updated.steps, ['下蹲', '起身']);
      expect(updated.mistakes, ['膝盖内扣']);
    });

    test('能单独替换 steps', () {
      final updated = base.copyWith(steps: ['新步骤']);

      expect(updated.steps, ['新步骤']);
      // mistakes 不受影响
      expect(updated.mistakes, ['膝盖内扣']);
    });

    test('清空重量不影响详解', () {
      final updated = base.copyWith(clearTargetWeight: true);

      expect(updated.steps.length, 2);
      expect(updated.mistakes.length, 1);
    });
  });

  group('序列化', () {
    test('往返后详解不丢', () {
      const original = Exercise(
        id: 'e1',
        name: '卧推',
        category: TrainingCategory.anaerobic,
        sets: 4,
        reps: 10,
        restSeconds: 90,
        muscleGroup: '胸肌',
        equipment: '杠铃',
        targetWeightKg: 50,
        tips: '注意沉肩',
        steps: ['躺平', '下放', '推起'],
        mistakes: ['耸肩', '压脖子'],
      );

      final restored = Exercise.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      expect(restored.steps, ['躺平', '下放', '推起']);
      expect(restored.mistakes, ['耸肩', '压脖子']);
      expect(restored.targetWeightKg, 50);
      expect(restored.tips, '注意沉肩');
    });

    test('旧记录没这两个字段时读成空列表', () {
      // 模拟加字段之前存的数据
      final oldData = {
        'id': 'e1',
        'name': '深蹲',
        'category': TrainingCategory.anaerobic.index,
        'sets': 4,
        'reps': 12,
        'restSeconds': 75,
        'muscleGroup': '腿部',
      };

      final ex = Exercise.fromMap(oldData);

      // 不能抛异常，也不能是 null
      expect(ex.steps, isEmpty);
      expect(ex.mistakes, isEmpty);
      expect(ex.hasGuide, isFalse);
    });

    test('空列表往返后还是空列表', () {
      const ex = Exercise(
        id: 'e1',
        name: '慢跑',
        category: TrainingCategory.aerobic,
        sets: 1,
        reps: 1800,
        isTimeBased: true,
        restSeconds: 0,
        muscleGroup: '心肺',
      );

      final restored = Exercise.fromMap(
        jsonDecode(jsonEncode(ex.toMap())) as Map,
      );

      expect(restored.steps, isEmpty);
      expect(restored.mistakes, isEmpty);
    });
  });

  group('预置数据完整性', () {
    /// 取出所有预置动作
    List<Exercise> allExercises() {
      final list = <Exercise>[];
      for (final plan in PresetPlans.getAll()) {
        for (final day in plan.days) {
          list.addAll(day.exercises);
        }
      }
      return list;
    }

    test('器械类动作都有详解', () {
      // 器械动作做错最容易受伤，这些必须有分解和常见错误
      final withEquipment =
          allExercises().where((e) => e.equipment != null).toList();

      expect(withEquipment, isNotEmpty);

      for (final ex in withEquipment) {
        expect(
          ex.hasGuide,
          isTrue,
          reason: '器械动作「${ex.name}」缺少详解',
        );
      }
    });

    test('有详解的动作，steps 和 mistakes 都不为空', () {
      for (final ex in allExercises()) {
        if (!ex.hasGuide) continue;

        expect(
          ex.steps,
          isNotEmpty,
          reason: '「${ex.name}」有 mistakes 但缺 steps',
        );
        expect(
          ex.mistakes,
          isNotEmpty,
          reason: '「${ex.name}」有 steps 但缺 mistakes',
        );
      }
    });

    test('详解条目不是空字符串', () {
      for (final ex in allExercises()) {
        for (final s in ex.steps) {
          expect(s.trim(), isNotEmpty, reason: '「${ex.name}」有空的 step');
        }
        for (final m in ex.mistakes) {
          expect(m.trim(), isNotEmpty, reason: '「${ex.name}」有空的 mistake');
        }
      }
    });

    test('器械动作都有建议重量', () {
      // 自重器械（单杠、双杠）除外 —— 用的是体重，不需要建议重量
      const bodyweightGear = {'单杠', '双杠'};

      for (final ex in allExercises()) {
        if (ex.equipment == null) continue;
        if (bodyweightGear.contains(ex.equipment)) continue;

        expect(
          ex.targetWeightKg,
          isNotNull,
          reason: '器械动作「${ex.name}」缺少建议重量',
        );
      }
    });

    test('徒手和有氧动作不该有建议重量', () {
      for (final ex in allExercises()) {
        if (ex.equipment != null) continue;

        expect(
          ex.targetWeightKg,
          isNull,
          reason: '徒手动作「${ex.name}」不该有建议重量',
        );
      }
    });
  });
}
