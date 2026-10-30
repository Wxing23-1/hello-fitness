// 工具函数单元测试
//
// 这些测试不渲染界面，纯粹验证计算逻辑，所以跑得特别快。
// 运行命令：flutter test test/health_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/utils/health_utils.dart';

void main() {
  // ══════════════════════════════════════════
  //  BMI 计算
  // ══════════════════════════════════════════
  group('calculateBmi', () {
    test('正常身高体重能算出正确的BMI', () {
      // 70 ÷ 1.75² = 22.857...
      final bmi = calculateBmi(175, 70);
      // 浮点数比较不能用 ==，要用 closeTo 给一个误差范围
      expect(bmi, closeTo(22.86, 0.01));
    });

    test('身高为0时返回0，不能崩在除零上', () {
      expect(calculateBmi(0, 70), 0);
    });

    test('身高或体重为负数时返回0', () {
      expect(calculateBmi(-175, 70), 0);
      expect(calculateBmi(175, -70), 0);
    });
  });

  // ══════════════════════════════════════════
  //  BMI 分级
  // ══════════════════════════════════════════
  group('bmiLevelOf', () {
    test('各区间分级正确', () {
      expect(bmiLevelOf(17), BmiLevel.underweight); // 偏瘦
      expect(bmiLevelOf(22), BmiLevel.normal); // 正常
      expect(bmiLevelOf(26), BmiLevel.overweight); // 偏胖
      expect(bmiLevelOf(30), BmiLevel.obese); // 肥胖
    });

    test('边界值归入上一档', () {
      // 18.5 应该算「正常」而不是「偏瘦」
      expect(bmiLevelOf(18.5), BmiLevel.normal);
      // 24 应该算「偏胖」
      expect(bmiLevelOf(24), BmiLevel.overweight);
      // 28 应该算「肥胖」
      expect(bmiLevelOf(28), BmiLevel.obese);
    });
  });

  // ══════════════════════════════════════════
  //  健康体重区间
  // ══════════════════════════════════════════
  group('healthyWeightRange', () {
    test('175cm 的健康体重约为 56.7 - 73.5kg', () {
      final (min, max) = healthyWeightRange(175);
      // 18.5 × 1.75² = 56.65625
      expect(min, closeTo(56.66, 0.01));
      // 24 × 1.75² = 73.5
      expect(max, closeTo(73.5, 0.01));
    });

    test('身高非法时返回 (0, 0)', () {
      final (min, max) = healthyWeightRange(0);
      expect(min, 0);
      expect(max, 0);
    });
  });

  // ══════════════════════════════════════════
  //  时长格式化
  // ══════════════════════════════════════════
  group('formatDuration', () {
    test('不足1小时只显示分钟', () {
      expect(formatDuration(45), '45分钟');
    });

    test('整小时不显示多余的0分', () {
      expect(formatDuration(120), '2小时');
    });

    test('有零头时同时显示小时和分钟', () {
      expect(formatDuration(80), '1小时20分');
    });

    test('0分钟', () {
      expect(formatDuration(0), '0分钟');
    });
  });

  // ══════════════════════════════════════════
  //  相对日期格式化
  // ══════════════════════════════════════════
  group('formatRelativeDate', () {
    test('今天', () {
      expect(formatRelativeDate(DateTime.now()), '今天');
    });

    test('昨天', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(formatRelativeDate(yesterday), '昨天');
    });

    test('一周内显示「N天前」', () {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      expect(formatRelativeDate(threeDaysAgo), '3天前');
    });

    test('超过一周显示具体日期', () {
      final longAgo = DateTime(2026, 3, 15);
      expect(formatRelativeDate(longAgo), '3月15日');
    });
  });
}
