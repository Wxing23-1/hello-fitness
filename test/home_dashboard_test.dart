// 首页看板测试
//
// 重点测「今日建议」的分支选择 —— 这套判断依赖当前时间和打卡记录，
// 分支多且容易互相覆盖，是最该上测试的地方。
// 运行命令：flutter test test/home_dashboard_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/models/workout_log.dart';
import 'package:hello_fitness/screens/home/home_dashboard_page.dart';
import 'package:hello_fitness/services/user_store.dart';
import 'package:provider/provider.dart';

void main() {
  /// 造一条指定日期的打卡记录
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

  /// 把看板挂起来，视口用竖屏避免内容被挤出屏幕
  Future<void> pumpDashboard(WidgetTester tester, UserStore store) async {
    await tester.binding.setSurfaceSize(const Size(450, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: HomeDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ══════════════════════════════════════════
  //  今日建议的分支
  // ══════════════════════════════════════════
  group('今日建议', () {
    testWidgets('没有任何记录时提示开始第一次训练', (tester) async {
      final store = UserStore();

      await pumpDashboard(tester, store);

      expect(find.text('开始第一次训练'), findsOneWidget);
    });

    testWidgets('今天练过就提示已完成', (tester) async {
      final store = UserStore();
      store.addWorkoutLog(logAt(DateTime.now()));

      await pumpDashboard(tester, store);

      expect(find.text('今天已完成训练'), findsOneWidget);
    });

    testWidgets('昨天练过建议换部位', (tester) async {
      final store = UserStore();
      store.addWorkoutLog(
        logAt(DateTime.now().subtract(const Duration(days: 1))),
      );

      await pumpDashboard(tester, store);

      expect(find.text('今天适合换个部位'), findsOneWidget);
    });

    testWidgets('超过4天没练会提醒间隔太久', (tester) async {
      final store = UserStore();
      store.addWorkoutLog(
        logAt(DateTime.now().subtract(const Duration(days: 6))),
      );

      await pumpDashboard(tester, store);

      // 文案里带天数，用 textContaining 匹配
      expect(find.textContaining('天没训练了'), findsOneWidget);
    });

    testWidgets('本周达标且不是今天/昨天练的，显示目标达成', (tester) async {
      final store = UserStore();

      // 目标设成每周 2 次
      store.updateGoal(weeklyWorkouts: 2);

      // 本周一和周二各练一次，凑满 2 次。
      // 同时要保证「最近一次」距今 2~3 天，避开今天/昨天和「超过4天」两个分支
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      // 周三及以后才跑这个断言，否则本周凑不出两天历史记录
      if (now.weekday < 4) {
        return;
      }

      store.addWorkoutLog(logAt(monday, id: 'a'));
      store.addWorkoutLog(
        logAt(now.subtract(const Duration(days: 2)), id: 'b'),
      );

      await pumpDashboard(tester, store);

      expect(find.text('本周目标已达成'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  数据卡显示
  // ══════════════════════════════════════════
  group('看板数据卡', () {
    testWidgets('显示全部六个区块', (tester) async {
      final store = UserStore();

      await pumpDashboard(tester, store);

      // 问候语按时段变化（早上好/下午好…），只断言名字部分。
      // 默认资料的昵称是「张三」
      expect(find.textContaining('张三'), findsOneWidget);
      expect(find.text('本周训练'), findsOneWidget);
      expect(find.text('体重目标'), findsOneWidget);
      expect(find.text('累计数据'), findsOneWidget);
      expect(find.text('AI 定制计划'), findsOneWidget);
      expect(find.text('训练打卡'), findsOneWidget);
    });

    testWidgets('BMI 显示默认资料算出的值', (tester) async {
      final store = UserStore();

      await pumpDashboard(tester, store);

      // 默认 175cm / 70kg，BMI = 22.9，属于正常
      expect(find.text('22.9'), findsOneWidget);
      expect(find.text('正常'), findsOneWidget);
    });

    testWidgets('填了昵称就显示昵称', (tester) async {
      final store = UserStore();
      store.updateProfile(name: '小李');

      await pumpDashboard(tester, store);

      expect(find.textContaining('小李'), findsOneWidget);
    });

    testWidgets('本周进度随打卡数变化', (tester) async {
      final store = UserStore();
      store.updateGoal(weeklyWorkouts: 4);

      await pumpDashboard(tester, store);
      expect(find.text('0 / 4 次'), findsOneWidget);

      // 加一条今天的记录，进度应该跟着动
      store.addWorkoutLog(logAt(DateTime.now()));
      await tester.pumpAndSettle();

      expect(find.text('1 / 4 次'), findsOneWidget);
    });

    testWidgets('体重达标时显示「达成」而不是差值', (tester) async {
      final store = UserStore();

      // 把目标体重设成和当前一样
      store.updateGoal(targetWeightKg: store.profile.weightKg);

      await pumpDashboard(tester, store);

      expect(find.text('达成'), findsOneWidget);
    });

    testWidgets('本周打卡圆点标出已练的天', (tester) async {
      final store = UserStore();
      store.addWorkoutLog(logAt(DateTime.now()));

      await pumpDashboard(tester, store);

      // 练过的那天圆点换成对勾图标
      expect(find.byIcon(Icons.check), findsWidgets);
    });
  });

  // ══════════════════════════════════════════
  //  布局安全
  // ══════════════════════════════════════════
  group('布局', () {
    testWidgets('小屏下不溢出', (tester) async {
      final store = UserStore();
      store.addWorkoutLog(logAt(DateTime.now()));

      // 用较窄的视口模拟小屏手机
      await tester.binding.setSurfaceSize(const Size(360, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: store,
          child: const MaterialApp(home: HomeDashboardPage()),
        ),
      );
      await tester.pumpAndSettle();

      // 有溢出的话 pumpAndSettle 阶段就会抛异常，能走到这里说明没问题
      expect(tester.takeException(), isNull);
    });

    testWidgets('超长昵称不会把布局挤坏', (tester) async {
      final store = UserStore();
      store.updateProfile(name: '这是一个非常非常非常长的昵称用来测试布局');

      await pumpDashboard(tester, store);

      expect(tester.takeException(), isNull);
    });
  });
}
