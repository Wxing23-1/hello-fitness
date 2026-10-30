// 训练打卡记录测试
//
// 覆盖 WorkoutLog 的序列化、store 的增删、以及卡路里估算。
// 运行命令：flutter test test/workout_log_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/models/training_plan.dart';
import 'package:hello_fitness/models/workout_log.dart';
import 'package:hello_fitness/services/user_store.dart';
import 'package:hello_fitness/utils/health_utils.dart';

void main() {
  // ══════════════════════════════════════════
  //  卡路里估算
  // ══════════════════════════════════════════
  group('estimateCalories', () {
    test('按 MET 公式计算：MET × 体重 × 小时', () {
      // 7.0 MET × 70kg × 0.5h = 245
      final cal = estimateCalories(
        durationMinutes: 30,
        weightKg: 70,
        met: 7.0,
      );
      expect(cal, 245);
    });

    test('时长为0时返回0', () {
      expect(
        estimateCalories(durationMinutes: 0, weightKg: 70, met: 7.0),
        0,
      );
    });

    test('体重非法时返回0，不会算出负数', () {
      expect(
        estimateCalories(durationMinutes: 30, weightKg: 0, met: 7.0),
        0,
      );
      expect(
        estimateCalories(durationMinutes: 30, weightKg: -70, met: 7.0),
        0,
      );
    });

    test('体重越大消耗越多', () {
      final light = estimateCalories(
        durationMinutes: 45,
        weightKg: 55,
        met: 7.0,
      );
      final heavy = estimateCalories(
        durationMinutes: 45,
        weightKg: 85,
        met: 7.0,
      );
      expect(heavy, greaterThan(light));
    });

    test('无氧的 MET 低于有氧，同样时长消耗更少', () {
      final aerobic = estimateCalories(
        durationMinutes: 40,
        weightKg: 70,
        met: TrainingCategory.aerobic.met,
      );
      final anaerobic = estimateCalories(
        durationMinutes: 40,
        weightKg: 70,
        met: TrainingCategory.anaerobic.met,
      );

      expect(aerobic, greaterThan(anaerobic));
    });

    test('混合类 MET 最高', () {
      expect(
        TrainingCategory.mixed.met,
        greaterThan(TrainingCategory.aerobic.met),
      );
      expect(
        TrainingCategory.mixed.met,
        greaterThan(TrainingCategory.anaerobic.met),
      );
    });
  });

  // ══════════════════════════════════════════
  //  WorkoutLog 序列化
  // ══════════════════════════════════════════
  group('WorkoutLog 序列化', () {
    /// 造一条完整的记录
    WorkoutLog buildLog() {
      return WorkoutLog(
        id: 'log_test',
        planId: 'plan_1',
        dayId: 'day_1',
        completedAt: DateTime(2026, 10, 22, 19, 30),
        durationMinutes: 45,
        exercises: const [
          ExerciseLog(
            exerciseId: 'ex_1',
            completedSets: 3,
            repsPerSet: [12, 10, 8],
            weight: 20.5,
          ),
          ExerciseLog(
            exerciseId: 'ex_2',
            completedSets: 2,
            repsPerSet: [30, 25],
            // 徒手动作没有重量
            weight: null,
          ),
        ],
        feeling: 4,
        note: '状态不错',
      );
    }

    test('往返后所有字段都不变', () {
      final original = buildLog();

      final restored = WorkoutLog.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      expect(restored.id, original.id);
      expect(restored.planId, original.planId);
      expect(restored.dayId, original.dayId);
      // DateTime 存的是毫秒时间戳，还原后应该完全相等
      expect(restored.completedAt, original.completedAt);
      expect(restored.durationMinutes, original.durationMinutes);
      expect(restored.feeling, original.feeling);
      expect(restored.note, original.note);
      expect(restored.exercises.length, 2);
    });

    test('动作明细能完整还原', () {
      final original = buildLog();
      final restored = WorkoutLog.fromMap(
        jsonDecode(jsonEncode(original.toMap())) as Map,
      );

      final ex1 = restored.exercises[0];
      expect(ex1.exerciseId, 'ex_1');
      expect(ex1.completedSets, 3);
      expect(ex1.repsPerSet, [12, 10, 8]);
      expect(ex1.weight, 20.5);

      // 徒手动作的 weight 应该还是 null
      expect(restored.exercises[1].weight, isNull);
    });

    test('totalReps 累加每组次数', () {
      final log = buildLog();

      // 12 + 10 + 8 = 30
      expect(log.exercises[0].totalReps, 30);
      // 30 + 25 = 55
      expect(log.exercises[1].totalReps, 55);
    });

    test('create 工厂方法生成唯一 id', () {
      final log1 = WorkoutLog.create(
        planId: 'p',
        dayId: 'd',
        durationMinutes: 30,
        exercises: const [],
      );

      expect(log1.id, startsWith('log_'));
      // completedAt 应该是当前时间附近
      expect(
        DateTime.now().difference(log1.completedAt).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('缺字段的脏数据不会崩', () {
      final log = WorkoutLog.fromMap({'id': 'only_id'});

      expect(log.id, 'only_id');
      expect(log.planId, '');
      expect(log.durationMinutes, 0);
      expect(log.exercises, isEmpty);
      expect(log.feeling, isNull);
      expect(log.note, isNull);
    });

    test('feeling 和 note 为 null 时也能正常往返', () {
      final log = WorkoutLog.create(
        planId: 'p',
        dayId: 'd',
        durationMinutes: 20,
        exercises: const [
          ExerciseLog(
            exerciseId: 'e',
            completedSets: 1,
            repsPerSet: [10],
          ),
        ],
      );

      final restored = WorkoutLog.fromMap(
        jsonDecode(jsonEncode(log.toMap())) as Map,
      );

      expect(restored.feeling, isNull);
      expect(restored.note, isNull);
      expect(restored.exercises.length, 1);
    });
  });

  // ══════════════════════════════════════════
  //  store 里的增删和统计
  // ══════════════════════════════════════════
  group('UserStore 训练打卡', () {
    late UserStore store;

    setUp(() {
      store = UserStore();
    });

    /// 造一条指定日期的记录
    WorkoutLog logAt(DateTime date, {String id = 'l1'}) {
      return WorkoutLog(
        id: id,
        planId: 'p1',
        dayId: 'd1',
        completedAt: date,
        durationMinutes: 40,
        exercises: const [
          ExerciseLog(
            exerciseId: 'e1',
            completedSets: 3,
            repsPerSet: [12, 12, 10],
          ),
        ],
      );
    }

    test('初始没有打卡记录', () {
      expect(store.workoutLogs, isEmpty);
      expect(store.totalPlanWorkouts, 0);
    });

    test('新增一条后数量变化', () {
      store.addWorkoutLog(logAt(DateTime.now()));

      expect(store.workoutLogs.length, 1);
      expect(store.totalPlanWorkouts, 1);
    });

    test('新增会通知监听者', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.addWorkoutLog(logAt(DateTime.now()));

      expect(notified, true);
    });

    test('按 id 删除', () {
      store.addWorkoutLog(logAt(DateTime.now(), id: 'a'));
      store.addWorkoutLog(logAt(DateTime.now(), id: 'b'));
      expect(store.workoutLogs.length, 2);

      store.deleteWorkoutLog('a');

      expect(store.workoutLogs.length, 1);
      expect(store.workoutLogs.first.id, 'b');
    });

    test('删除不存在的 id 不报错', () {
      store.addWorkoutLog(logAt(DateTime.now()));
      store.deleteWorkoutLog('不存在');

      expect(store.workoutLogs.length, 1);
    });

    test('workoutLogs 按时间从新到旧排序', () {
      final now = DateTime.now();

      // 故意乱序添加
      store.addWorkoutLog(logAt(now.subtract(const Duration(days: 5)), id: 'old'));
      store.addWorkoutLog(logAt(now, id: 'new'));
      store.addWorkoutLog(logAt(now.subtract(const Duration(days: 2)), id: 'mid'));

      final logs = store.workoutLogs;
      expect(logs[0].id, 'new');
      expect(logs[1].id, 'mid');
      expect(logs[2].id, 'old');
    });

    test('workoutLogs 返回的列表不可直接修改', () {
      store.addWorkoutLog(logAt(DateTime.now()));

      expect(
        () => store.workoutLogs.add(store.workoutLogs.first),
        throwsUnsupportedError,
      );
    });

    test('thisWeekPlanWorkouts 只统计本周', () {
      final now = DateTime.now();

      // 今天的，一定在本周
      store.addWorkoutLog(logAt(now, id: 'today'));
      // 30天前的，肯定不在本周
      store.addWorkoutLog(
        logAt(now.subtract(const Duration(days: 30)), id: 'old'),
      );

      expect(store.totalPlanWorkouts, 2);
      expect(store.thisWeekPlanWorkouts, 1);
    });

    test('resetAll 清空打卡记录', () {
      store.addWorkoutLog(logAt(DateTime.now()));
      expect(store.totalPlanWorkouts, 1);

      store.resetAll();

      expect(store.workoutLogs, isEmpty);
      expect(store.totalPlanWorkouts, 0);
    });
  });
}
