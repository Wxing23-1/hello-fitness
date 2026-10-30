// 训练中断草稿测试
//
// 重点测序列化往返和过期判断。恢复时的索引越界保护在
// WorkoutSessionPage.initState 里，那部分由 widget 测试覆盖。
// 运行命令：flutter test test/session_draft_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/models/session_draft.dart';
import 'package:hello_fitness/models/workout_log.dart';

void main() {
  /// 造一份草稿，默认两个动作各两组、第一组已完成
  SessionDraft draft({
    DateTime? savedAt,
    int exerciseIndex = 0,
    int setIndex = 1,
  }) {
    return SessionDraft(
      planId: 'p1',
      dayId: 'd1',
      startTime: DateTime(2026, 10, 26, 9, 0),
      savedAt: savedAt ?? DateTime.now(),
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      completedSets: [
        [
          SetLog(
            targetReps: 12,
            actualReps: 10,
            weight: 40,
            completed: true,
          ),
          SetLog(targetReps: 12, actualReps: 12, weight: 40),
        ],
        [
          SetLog(targetReps: 15, actualReps: 15, weight: 0),
          SetLog(targetReps: 15, actualReps: 15, weight: 0),
        ],
      ],
    );
  }

  group('序列化', () {
    test('往返后数据不变', () {
      final original = draft();

      final restored = SessionDraft.fromMap(original.toMap());

      expect(restored.planId, 'p1');
      expect(restored.dayId, 'd1');
      expect(restored.exerciseIndex, 0);
      expect(restored.setIndex, 1);
      expect(restored.startTime, original.startTime);
    });

    test('每组的实际次数和重量都保留', () {
      final restored = SessionDraft.fromMap(draft().toMap());

      final firstSet = restored.completedSets[0][0];
      expect(firstSet.targetReps, 12);
      // 实际只做了 10 次，不能被目标值覆盖
      expect(firstSet.actualReps, 10);
      expect(firstSet.weight, 40);
      expect(firstSet.completed, isTrue);

      // 没完成的组要保持未完成
      expect(restored.completedSets[0][1].completed, isFalse);
    });

    test('徒手动作的重量 0 能正确还原', () {
      final restored = SessionDraft.fromMap(draft().toMap());

      expect(restored.completedSets[1][0].weight, 0);
    });

    test('重量存成整数也能读回来', () {
      // 手写一份 weight 是 int 的数据，模拟 JSON 解码后的情况。
      // jsonDecode 会把 40.0 读成 int，直接 as double 会抛异常
      final map = {
        'planId': 'p1',
        'dayId': 'd1',
        'startTime': 0,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'exerciseIndex': 0,
        'setIndex': 0,
        'completedSets': [
          [
            {
              'targetReps': 10,
              'actualReps': 10,
              'weight': 50, // int，不是 double
              'completed': true,
            },
          ],
        ],
      };

      final restored = SessionDraft.fromMap(map);

      expect(restored.completedSets[0][0].weight, 50.0);
    });

    test('字段缺失时用默认值兜住，不抛异常', () {
      final restored = SessionDraft.fromMap({});

      expect(restored.planId, '');
      expect(restored.exerciseIndex, 0);
      expect(restored.completedSets, isEmpty);
    });
  });

  group('过期判断', () {
    test('刚保存的草稿没过期', () {
      expect(draft().isExpired, isFalse);
    });

    test('11 小时前的草稿还能用', () {
      final d = draft(
        savedAt: DateTime.now().subtract(const Duration(hours: 11)),
      );

      expect(d.isExpired, isFalse);
    });

    test('超过 12 小时就算过期', () {
      final d = draft(
        savedAt: DateTime.now().subtract(const Duration(hours: 13)),
      );

      // 隔夜的半场训练接着练没意义，时长统计也会把睡觉算进去
      expect(d.isExpired, isTrue);
    });
  });

  group('已完成组数统计', () {
    test('只数标记为完成的组', () {
      // 默认草稿里只有第一组完成
      expect(draft().completedSetCount, 1);
    });

    test('全部完成时等于总组数', () {
      final d = SessionDraft(
        planId: 'p1',
        dayId: 'd1',
        startTime: DateTime.now(),
        savedAt: DateTime.now(),
        exerciseIndex: 0,
        setIndex: 0,
        completedSets: [
          [
            SetLog(
              targetReps: 10,
              actualReps: 10,
              weight: 0,
              completed: true,
            ),
            SetLog(
              targetReps: 10,
              actualReps: 10,
              weight: 0,
              completed: true,
            ),
          ],
        ],
      );

      expect(d.completedSetCount, 2);
    });

    test('一组都没完成时是 0', () {
      final d = SessionDraft(
        planId: 'p1',
        dayId: 'd1',
        startTime: DateTime.now(),
        savedAt: DateTime.now(),
        exerciseIndex: 0,
        setIndex: 0,
        completedSets: [
          [SetLog(targetReps: 10, actualReps: 10, weight: 0)],
        ],
      );

      expect(d.completedSetCount, 0);
    });
  });
}
