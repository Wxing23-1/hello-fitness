// 数据仓库单元测试
//
// 验证 UserStore 的读写逻辑和派生数据计算，不涉及界面。
// 运行命令：flutter test test/user_store_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/models/fitness_goal.dart';
import 'package:hello_fitness/models/user_profile.dart';
import 'package:hello_fitness/models/workout_record.dart';
import 'package:hello_fitness/services/user_store.dart';

void main() {
  // 每个测试都用全新的 store，避免测试之间相互污染
  late UserStore store;

  setUp(() {
    store = UserStore();
  });

  // ══════════════════════════════════════════
  //  资料更新
  // ══════════════════════════════════════════
  group('updateProfile', () {
    test('只改体重，其他字段保持不变', () {
      final oldName = store.profile.name;
      final oldHeight = store.profile.heightCm;

      store.updateProfile(weightKg: 68);

      expect(store.profile.weightKg, 68);
      expect(store.profile.name, oldName); // 名字没动
      expect(store.profile.heightCm, oldHeight); // 身高没动
    });

    test('修改数据会通知监听者', () {
      var notified = false;
      // 注册一个监听器，store 调 notifyListeners 时会执行
      store.addListener(() => notified = true);

      store.updateProfile(name: '李四');

      // 这一步是在验证界面能不能自动刷新 —— 忘了调 notifyListeners 就会在这挂掉
      expect(notified, true);
    });

    test('能改性别', () {
      store.updateProfile(gender: Gender.female);
      expect(store.profile.gender, Gender.female);
    });
  });

  // ══════════════════════════════════════════
  //  目标更新
  // ══════════════════════════════════════════
  group('updateGoal', () {
    test('能改目标类型和目标体重', () {
      store.updateGoal(type: GoalType.gainMuscle, targetWeightKg: 75);

      expect(store.goal.type, GoalType.gainMuscle);
      expect(store.goal.targetWeightKg, 75);
    });

    test('weightGap 算出当前体重和目标的差距', () {
      store.updateProfile(weightKg: 70);
      store.updateGoal(targetWeightKg: 65);

      // 返回绝对值，所以是 5 而不是 -5
      expect(store.weightGap, 5);
    });
  });

  // ══════════════════════════════════════════
  //  训练记录
  // ══════════════════════════════════════════
  group('训练记录', () {
    test('初始有7条演示数据', () {
      expect(store.totalWorkouts, 7);
    });

    test('新增记录后数量+1', () {
      final before = store.totalWorkouts;

      store.addRecord(
        WorkoutRecord(
          id: 'test1',
          type: WorkoutType.running,
          date: DateTime.now(),
          durationMinutes: 30,
          calories: 250,
        ),
      );

      expect(store.totalWorkouts, before + 1);
    });

    test('按id删除记录', () {
      final before = store.totalWorkouts;

      store.deleteRecord('w1'); // 演示数据里的第一条

      expect(store.totalWorkouts, before - 1);
      // 确认这条真的没了
      expect(store.records.any((r) => r.id == 'w1'), false);
    });

    test('删除不存在的id不会报错，数量也不变', () {
      final before = store.totalWorkouts;
      store.deleteRecord('不存在的id');
      expect(store.totalWorkouts, before);
    });

    test('records 按时间从新到旧排序', () {
      final records = store.records;

      // 逐个比较相邻两条，前一条的日期必须不早于后一条
      for (var i = 0; i < records.length - 1; i++) {
        final current = records[i].date;
        final next = records[i + 1].date;
        expect(current.isAfter(next) || current.isAtSameMomentAs(next), true);
      }
    });

    test('records 返回的列表不可直接修改', () {
      // 外部拿到列表后不能偷偷 add，否则界面不会刷新
      expect(() => store.records.add(store.records.first), throwsUnsupportedError);
    });

    test('totalMinutes 和 totalCalories 正确累加', () {
      // 先清空，避免演示数据干扰
      store.clearAllRecords();

      store.addRecord(WorkoutRecord(
        id: 't1',
        type: WorkoutType.running,
        date: DateTime.now(),
        durationMinutes: 30,
        calories: 200,
      ));
      store.addRecord(WorkoutRecord(
        id: 't2',
        type: WorkoutType.yoga,
        date: DateTime.now(),
        durationMinutes: 45,
        calories: 150,
      ));

      expect(store.totalMinutes, 75);
      expect(store.totalCalories, 350);
    });

    test('clearAllRecords 清空所有记录', () {
      store.clearAllRecords();

      expect(store.totalWorkouts, 0);
      expect(store.totalMinutes, 0);
      expect(store.totalCalories, 0);
    });

    test('thisWeekWorkouts 只统计本周的记录', () {
      store.clearAllRecords();

      // 今天的记录，一定在本周内
      store.addRecord(WorkoutRecord(
        id: 'today',
        type: WorkoutType.running,
        date: DateTime.now(),
        durationMinutes: 30,
        calories: 200,
      ));

      // 30天前的记录，肯定不在本周
      store.addRecord(WorkoutRecord(
        id: 'old',
        type: WorkoutType.running,
        date: DateTime.now().subtract(const Duration(days: 30)),
        durationMinutes: 30,
        calories: 200,
      ));

      // 总共2条，但本周只有1条
      expect(store.totalWorkouts, 2);
      expect(store.thisWeekWorkouts, 1);
    });
  });

  // ══════════════════════════════════════════
  //  收藏
  // ══════════════════════════════════════════
  group('收藏课程', () {
    test('初始收藏了3门课', () {
      expect(store.favoriteCourses.length, 3);
    });

    test('toggleFavorite 对已收藏的课是取消', () {
      expect(store.isFavorite('c1'), true);

      store.toggleFavorite('c1');

      expect(store.isFavorite('c1'), false);
      expect(store.favoriteCourses.length, 2);
    });

    test('toggleFavorite 对未收藏的课是添加', () {
      expect(store.isFavorite('c2'), false);

      store.toggleFavorite('c2');

      expect(store.isFavorite('c2'), true);
      expect(store.favoriteCourses.length, 4);
    });

    test('连点两次回到原状态（撤销功能靠这个）', () {
      final before = store.isFavorite('c1');

      store.toggleFavorite('c1');
      store.toggleFavorite('c1');

      expect(store.isFavorite('c1'), before);
    });
  });

  // ══════════════════════════════════════════
  //  设置项
  // ══════════════════════════════════════════
  group('系统设置', () {
    test('深色模式默认关闭，可以打开', () {
      expect(store.darkMode, false);

      store.setDarkMode(true);

      expect(store.darkMode, true);
    });

    test('训练提醒默认开启', () {
      expect(store.workoutReminder, true);
    });

    test('单位制默认公制，可以切英制', () {
      expect(store.unitSystem, '公制');

      store.setUnitSystem('英制');

      expect(store.unitSystem, '英制');
    });
  });

  // ══════════════════════════════════════════
  //  重置
  // ══════════════════════════════════════════
  group('resetAll', () {
    test('把所有数据恢复到初始状态', () {
      // 先把各项数据都改一遍
      store.updateProfile(name: '改过的名字', weightKg: 99);
      store.updateGoal(targetWeightKg: 50);
      store.clearAllRecords();
      store.toggleFavorite('c1'); // 取消一个收藏
      store.setDarkMode(true);
      store.setUnitSystem('英制');

      // 一键重置
      store.resetAll();

      // 逐项确认回到了初始值
      expect(store.profile.name, '张三');
      expect(store.profile.weightKg, 70);
      expect(store.goal.targetWeightKg, 65);
      expect(store.totalWorkouts, 7);
      expect(store.favoriteCourses.length, 3);
      expect(store.isFavorite('c1'), true);
      expect(store.darkMode, false);
      expect(store.unitSystem, '公制');
    });
  });
}
