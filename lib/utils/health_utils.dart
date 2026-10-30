// 导入Material库，这里只用到 Color 和 Colors
import 'package:flutter/material.dart';

/// 健康计算与格式化工具
///
/// 把「算BMI」「格式化日期」这类纯逻辑从页面里抽出来放这，
/// 好处是页面代码只管画界面，这些函数还能单独写测试。

// ═══════════════════════════════════════════════════════
//  BMI 相关
// ═══════════════════════════════════════════════════════

/// BMI 健康等级
///
/// 分级标准参考《中国成人超重和肥胖症预防控制指南》：
/// 偏瘦 < 18.5 ≤ 正常 < 24 ≤ 偏胖 < 28 ≤ 肥胖
enum BmiLevel {
  underweight('偏瘦', Colors.orange),
  normal('正常', Colors.green),
  overweight('偏胖', Colors.orange),
  obese('肥胖', Colors.red);

  /// 显示给用户看的中文名
  final String label;

  /// 对应的提示颜色，正常用绿色，异常用橙色/红色
  final Color color;

  // 枚举的构造函数必须是 const
  const BmiLevel(this.label, this.color);
}

/// 根据身高体重计算BMI
///
/// [heightCm] 身高，单位厘米
/// [weightKg] 体重，单位公斤
/// 返回BMI值；参数不合法时返回 0
double calculateBmi(double heightCm, double weightKg) {
  // 身高为0或负数会导致除零错误，直接挡掉
  if (heightCm <= 0 || weightKg <= 0) return 0;

  // BMI公式：体重(kg) ÷ 身高²(m)，身高要从厘米换成米
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

/// 把BMI数值转换成健康等级
BmiLevel bmiLevelOf(double bmi) {
  if (bmi < 18.5) return BmiLevel.underweight;
  if (bmi < 24) return BmiLevel.normal;
  if (bmi < 28) return BmiLevel.overweight;
  return BmiLevel.obese;
}

/// 按身高算出「正常体重」的区间，用于目标设置页给建议
///
/// 反推公式：体重 = BMI × 身高²，把 BMI 代入 18.5 和 24 就是区间两端
/// 返回 (最小值, 最大值)，单位公斤
(double, double) healthyWeightRange(double heightCm) {
  if (heightCm <= 0) return (0, 0);
  final heightM = heightCm / 100;
  return (18.5 * heightM * heightM, 24 * heightM * heightM);
}

// ═══════════════════════════════════════════════════════
//  格式化相关
// ═══════════════════════════════════════════════════════

/// 把日期格式化成「10月19日」这种中文短格式
String formatDateCn(DateTime date) {
  return '${date.month}月${date.day}日';
}

/// 把日期格式化成相对时间：今天 / 昨天 / 3天前 / 10月19日
///
/// 训练历史列表里用这个，比纯日期更直观
String formatRelativeDate(DateTime date) {
  // 只比较「日期」不比较「时刻」，所以把时间部分抹掉
  final today = DateTime.now();
  final dayOnly = DateTime(date.year, date.month, date.day);
  final todayOnly = DateTime(today.year, today.month, today.day);

  final diffDays = todayOnly.difference(dayOnly).inDays;

  if (diffDays == 0) return '今天';
  if (diffDays == 1) return '昨天';
  if (diffDays < 7) return '$diffDays天前';
  return formatDateCn(date);
}

// ═══════════════════════════════════════════════════════
//  卡路里估算
// ═══════════════════════════════════════════════════════

/// 估算一次训练消耗的卡路里
///
/// 用的是 MET（代谢当量）公式：
///   卡路里 = MET × 体重(kg) × 时长(小时)
///
/// MET 值按训练类别取经验值：
///   有氧（慢跑、骑行）约 7.0
///   无氧（器械、力量）约 5.0
///   混合（HIIT、循环）约 8.0
///
/// 这是个粗略估算 —— 真实消耗受心率、强度、个体差异影响很大。
/// 精确测量需要心率带或智能手表，这里给个量级正确的参考值就够了。
int estimateCalories({
  required int durationMinutes,
  required double weightKg,
  required double met,
}) {
  if (durationMinutes <= 0 || weightKg <= 0) return 0;

  final hours = durationMinutes / 60;
  return (met * weightKg * hours).round();
}

/// 把分钟数格式化成「1小时20分」或「45分钟」
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes分钟';

  final hours = minutes ~/ 60; // ~/ 是整除，取小时数
  final remainMinutes = minutes % 60; // % 取余数，剩下的分钟

  // 刚好整小时就不显示「0分」
  if (remainMinutes == 0) return '$hours小时';
  return '$hours小时$remainMinutes分';
}
