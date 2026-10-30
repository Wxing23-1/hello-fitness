/// 课程难度
enum CourseLevel {
  beginner('初级'),
  intermediate('中级'),
  advanced('高级');

  /// 显示给用户看的中文名
  final String label;

  const CourseLevel(this.label);
}

/// 训练课程
///
/// 对应「收藏课程列表」里的一张课程卡片。
class Course {
  /// 课程唯一标识，取消收藏时用它定位
  final String id;

  /// 课程名称
  final String title;

  /// 教练名字
  final String coach;

  /// 课程时长，单位分钟
  final int durationMinutes;

  /// 难度等级
  final CourseLevel level;

  /// 训练部位或分类，比如「全身」「核心」
  final String category;

  /// 预计消耗卡路里，单位千卡
  final int calories;

  const Course({
    required this.id,
    required this.title,
    required this.coach,
    required this.durationMinutes,
    required this.level,
    required this.category,
    required this.calories,
  });

  /// 生成一批演示课程
  ///
  /// 后续课程数据会从 Firestore 拉，现在先用假数据撑起界面
  static List<Course> demoCourses() {
    return const [
      Course(
        id: 'c1',
        title: '新手全身燃脂',
        coach: '李教练',
        durationMinutes: 20,
        level: CourseLevel.beginner,
        category: '全身',
        calories: 180,
      ),
      Course(
        id: 'c2',
        title: '腹肌撕裂者',
        coach: '王教练',
        durationMinutes: 15,
        level: CourseLevel.intermediate,
        category: '核心',
        calories: 140,
      ),
      Course(
        id: 'c3',
        title: '哑铃上肢塑形',
        coach: '陈教练',
        durationMinutes: 30,
        level: CourseLevel.intermediate,
        category: '上肢',
        calories: 220,
      ),
      Course(
        id: 'c4',
        title: '晨间唤醒拉伸',
        coach: '刘教练',
        durationMinutes: 10,
        level: CourseLevel.beginner,
        category: '拉伸',
        calories: 50,
      ),
      Course(
        id: 'c5',
        title: 'HIIT 极限挑战',
        coach: '赵教练',
        durationMinutes: 25,
        level: CourseLevel.advanced,
        category: '全身',
        calories: 320,
      ),
    ];
  }
}
