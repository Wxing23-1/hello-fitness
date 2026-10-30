// 导入Material库，用到 IconData 和 Icons
import 'package:flutter/material.dart';

/// 运动代谢类型：有氧 / 无氧
///
/// 有氧：持续性中低强度，主要靠氧气分解糖和脂肪供能，适合减脂和心肺
/// 无氧：短时高强度，靠糖原无氧分解供能，适合增肌和力量
/// 混合：两者兼具，比如 HIIT 是间歇性的，有氧无氧交替
enum EnergySystem {
  aerobic('有氧', '提升心肺、消耗脂肪'),
  anaerobic('无氧', '增长肌肉、提升力量'),
  mixed('混合', '有氧无氧交替进行');

  final String label;
  final String description;

  const EnergySystem(this.label, this.description);
}

/// 训练类型
///
/// 每种类型自带图标和代谢分类，训练历史列表里直接用，
/// 不用在页面里写 switch 判断
enum WorkoutType {
  running('跑步', Icons.directions_run, EnergySystem.aerobic),
  strength('力量训练', Icons.fitness_center, EnergySystem.anaerobic),
  yoga('瑜伽', Icons.self_improvement, EnergySystem.aerobic),
  cycling('骑行', Icons.directions_bike, EnergySystem.aerobic),
  swimming('游泳', Icons.pool, EnergySystem.aerobic),
  hiit('HIIT', Icons.bolt, EnergySystem.mixed);

  /// 显示给用户看的中文名
  final String label;

  /// 对应的图标
  final IconData icon;

  /// 属于有氧还是无氧
  final EnergySystem energySystem;

  const WorkoutType(this.label, this.icon, this.energySystem);
}

/// 单条训练记录
///
/// 对应「训练历史记录」列表里的一行。
class WorkoutRecord {
  /// 记录的唯一标识，删除时用它定位是哪一条
  final String id;

  /// 训练类型
  final WorkoutType type;

  /// 训练发生的时间
  final DateTime date;

  /// 训练时长，单位分钟
  final int durationMinutes;

  /// 消耗的卡路里，单位千卡
  final int calories;

  /// 备注，比如「今天状态不错」，可以为空
  final String note;

  const WorkoutRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.durationMinutes,
    required this.calories,
    this.note = '',
  });

  /// 转成 Map，用于存进 Hive
  ///
  /// DateTime 不能直接存，转成毫秒时间戳（int）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'date': date.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'calories': calories,
      'note': note,
    };
  }

  /// 从 Map 还原对象
  factory WorkoutRecord.fromMap(Map<dynamic, dynamic> map) {
    // 越界时退回第一个枚举值
    final typeIndex = map['type'] as int? ?? 0;
    final type = (typeIndex >= 0 && typeIndex < WorkoutType.values.length)
        ? WorkoutType.values[typeIndex]
        : WorkoutType.running;

    return WorkoutRecord(
      id: map['id'] as String? ?? '',
      type: type,
      // 时间戳转回 DateTime
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      calories: map['calories'] as int? ?? 0,
      note: map['note'] as String? ?? '',
    );
  }

  /// 生成一批演示数据
  ///
  /// 只在用户首次安装、本地还没有任何数据时使用。
  /// 一旦用户自己记录过训练，就不会再出现这批演示数据。
  static List<WorkoutRecord> demoRecords() {
    // 以「今天」为基准往前推，这样不管哪天打开，列表里都有「今天」「昨天」
    final now = DateTime.now();

    return [
      WorkoutRecord(
        id: 'w1',
        type: WorkoutType.running,
        date: now,
        durationMinutes: 35,
        calories: 320,
        note: '晨跑5公里，配速6分30',
      ),
      WorkoutRecord(
        id: 'w2',
        type: WorkoutType.strength,
        date: now.subtract(const Duration(days: 1)),
        durationMinutes: 60,
        calories: 280,
        note: '胸推 + 肩推，重量加了2.5kg',
      ),
      WorkoutRecord(
        id: 'w3',
        type: WorkoutType.yoga,
        date: now.subtract(const Duration(days: 2)),
        durationMinutes: 45,
        calories: 150,
        note: '',
      ),
      WorkoutRecord(
        id: 'w4',
        type: WorkoutType.hiit,
        date: now.subtract(const Duration(days: 4)),
        durationMinutes: 25,
        calories: 310,
        note: '累到不行，但很爽',
      ),
      WorkoutRecord(
        id: 'w5',
        type: WorkoutType.cycling,
        date: now.subtract(const Duration(days: 6)),
        durationMinutes: 80,
        calories: 540,
        note: '环湖骑行',
      ),
      WorkoutRecord(
        id: 'w6',
        type: WorkoutType.swimming,
        date: now.subtract(const Duration(days: 9)),
        durationMinutes: 50,
        calories: 420,
        note: '',
      ),
      WorkoutRecord(
        id: 'w7',
        type: WorkoutType.strength,
        date: now.subtract(const Duration(days: 11)),
        durationMinutes: 55,
        calories: 260,
        note: '腿部训练',
      ),
    ];
  }
}
