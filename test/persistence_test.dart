// 持久化序列化测试
//
// 验证用户资料、健身目标能正确存取 —— 这是「改完重启数据还在」的基础。
// 注意这里只测序列化逻辑，不测 Hive 本身（那需要真实文件系统）。
//
// 运行命令：flutter test test/persistence_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/models/fitness_goal.dart';
import 'package:hello_fitness/models/user_profile.dart';

void main() {
  // ══════════════════════════════════════════
  //  用户资料
  // ══════════════════════════════════════════
  group('UserProfile 序列化', () {
    test('往返后所有字段都不变', () {
      const original = UserProfile(
        name: '李四',
        gender: Gender.female,
        age: 28,
        heightCm: 165.5,
        weightKg: 55.3,
        bio: '每天都要动一动',
      );

      // 走一遍真实存储路径：对象 → Map → JSON → Map → 对象
      final restored = UserProfile.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      expect(restored.name, '李四');
      expect(restored.gender, Gender.female);
      expect(restored.age, 28);
      expect(restored.heightCm, 165.5);
      expect(restored.weightKg, 55.3);
      expect(restored.bio, '每天都要动一动');
    });

    test('身高体重存成整数时也能正确读回 double', () {
      // JSON 里 175.0 会被序列化成 175（int），读的时候要能转回 double
      final map = {
        'name': '张三',
        'gender': 0,
        'age': 22,
        'heightCm': 175, // 整数
        'weightKg': 70, // 整数
        'bio': '',
      };

      final profile = UserProfile.fromMap(map);

      expect(profile.heightCm, 175.0);
      expect(profile.weightKg, 70.0);
      // 确认类型真的是 double，不是 int
      expect(profile.heightCm, isA<double>());
    });

    test('缺字段时用默认值兜底，不抛异常', () {
      final profile = UserProfile.fromMap({'name': '只有名字'});

      expect(profile.name, '只有名字');
      expect(profile.gender, Gender.male); // 默认男
      expect(profile.age, 22);
      expect(profile.heightCm, 175);
      expect(profile.weightKg, 70);
      expect(profile.bio, '');
    });

    test('性别 index 越界时不崩溃', () {
      // 模拟数据损坏：gender 存了个 99
      final profile = UserProfile.fromMap({
        'name': '测试',
        'gender': 99,
      });

      // clamp 会把它夹到合法范围，退回第一个枚举值
      expect(profile.gender, Gender.male);
    });

    test('空 Map 返回全默认值', () {
      final profile = UserProfile.fromMap({});

      expect(profile.name, '张三');
      expect(profile.heightCm, 175);
    });

    test('initial() 和序列化往返结果一致', () {
      final original = UserProfile.initial();
      final restored = UserProfile.fromMap(original.toMap());

      expect(restored.name, original.name);
      expect(restored.gender, original.gender);
      expect(restored.age, original.age);
      expect(restored.heightCm, original.heightCm);
      expect(restored.weightKg, original.weightKg);
      expect(restored.bio, original.bio);
    });
  });

  // ══════════════════════════════════════════
  //  健身目标
  // ══════════════════════════════════════════
  group('FitnessGoal 序列化', () {
    test('往返后所有字段都不变', () {
      const original = FitnessGoal(
        type: GoalType.gainMuscle,
        targetWeightKg: 78.5,
        weeklyWorkouts: 5,
        dailyCalories: 2600,
        dailyWaterMl: 3000,
      );

      final restored = FitnessGoal.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      expect(restored.type, GoalType.gainMuscle);
      expect(restored.targetWeightKg, 78.5);
      expect(restored.weeklyWorkouts, 5);
      expect(restored.dailyCalories, 2600);
      expect(restored.dailyWaterMl, 3000);
    });

    test('目标体重存成整数时能读回 double', () {
      final goal = FitnessGoal.fromMap({
        'type': 0,
        'targetWeightKg': 65, // 整数
        'weeklyWorkouts': 4,
        'dailyCalories': 1800,
        'dailyWaterMl': 2000,
      });

      expect(goal.targetWeightKg, 65.0);
    });

    test('缺字段时用默认值', () {
      final goal = FitnessGoal.fromMap({});

      expect(goal.type, GoalType.loseWeight);
      expect(goal.targetWeightKg, 65);
      expect(goal.weeklyWorkouts, 4);
      expect(goal.dailyCalories, 1800);
      expect(goal.dailyWaterMl, 2000);
    });

    test('三种目标类型都能正确往返', () {
      for (final type in GoalType.values) {
        final original = FitnessGoal.initial().copyWith(type: type);
        final restored = FitnessGoal.fromMap(original.toMap());

        expect(restored.type, type, reason: '$type 往返失败');
      }
    });
  });

  // ══════════════════════════════════════════
  //  修改后再存储的场景
  //  这是用户实际遇到的流程：改资料 → 存 → 重启 → 读
  // ══════════════════════════════════════════
  group('改完再存的完整流程', () {
    test('改体重后存储，读回来是新值', () {
      // 第一步：初始资料
      final original = UserProfile.initial();
      expect(original.weightKg, 70);

      // 第二步：用户改成 68
      final modified = original.copyWith(weightKg: 68);

      // 第三步：存起来（模拟 LocalStorage.saveProfile）
      final stored = jsonEncode(modified.toMap());

      // 第四步：重启后读回来（模拟 LocalStorage.loadProfile）
      final loaded = UserProfile.fromMap(jsonDecode(stored) as Map);

      // 必须是改过的值，不是初始值
      expect(loaded.weightKg, 68);
      // 其他字段没动
      expect(loaded.name, '张三');
      expect(loaded.heightCm, 175);
    });

    test('连续改多次，存的是最后一次的结果', () {
      var profile = UserProfile.initial();

      profile = profile.copyWith(name: '第一次改');
      profile = profile.copyWith(name: '第二次改', age: 25);
      profile = profile.copyWith(weightKg: 72);

      final loaded = UserProfile.fromMap(
        jsonDecode(jsonEncode(profile.toMap())) as Map,
      );

      expect(loaded.name, '第二次改');
      expect(loaded.age, 25);
      expect(loaded.weightKg, 72);
    });

    test('改目标后存储，读回来是新值', () {
      final original = FitnessGoal.initial();
      final modified = original.copyWith(
        type: GoalType.gainMuscle,
        targetWeightKg: 80,
        weeklyWorkouts: 6,
      );

      final loaded = FitnessGoal.fromMap(
        jsonDecode(jsonEncode(modified.toMap())) as Map,
      );

      expect(loaded.type, GoalType.gainMuscle);
      expect(loaded.targetWeightKg, 80);
      expect(loaded.weeklyWorkouts, 6);
      // 没改的字段保持原值
      expect(loaded.dailyCalories, 1800);
    });
  });
}
