/// 体重记录
///
/// 每次称重记一条，用来画体重变化曲线。
/// 和 UserProfile.weightKg 的区别：那个是「当前体重」只有一个值，
/// 这里是历史序列，能看出趋势。
class WeightLog {
  /// 唯一标识
  final String id;

  /// 称重日期
  final DateTime date;

  /// 体重（公斤）
  final double weightKg;

  /// 体脂率（百分比），没测就是 null
  ///
  /// 有体脂秤的人才填得出来，所以是可选的
  final double? bodyFatPercent;

  /// 备注，比如「早起空腹」
  final String? note;

  const WeightLog({
    required this.id,
    required this.date,
    required this.weightKg,
    this.bodyFatPercent,
    this.note,
  });

  /// 创建一条新记录
  factory WeightLog.create({
    required double weightKg,
    DateTime? date,
    double? bodyFatPercent,
    String? note,
  }) {
    final d = date ?? DateTime.now();

    return WeightLog(
      id: 'wl_${d.millisecondsSinceEpoch}',
      date: d,
      weightKg: weightKg,
      bodyFatPercent: bodyFatPercent,
      note: note,
    );
  }

  /// 只保留年月日的日期
  ///
  /// 判断「同一天是否已有记录」时用 —— 一天称多次只留最后一次
  DateTime get dayOnly => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'weightKg': weightKg,
      'bodyFatPercent': bodyFatPercent,
      'note': note,
    };
  }

  factory WeightLog.fromMap(Map map) {
    return WeightLog(
      id: map['id'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? 0),
      // 用 num 兜住：jsonDecode 会把 70.0 读成 int
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
      note: map['note'] as String?,
    );
  }
}
