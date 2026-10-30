// 性别枚举：用枚举而不是字符串，好处是写错了编译期就能发现
enum Gender {
  male('男'),
  female('女');

  /// 显示给用户看的中文名
  final String label;

  const Gender(this.label);
}

/// 用户资料数据模型
///
/// 对应「个人资料管理」页面可以编辑的全部字段。
///
/// 这个类是不可变的（所有字段都是 final）：改数据不是直接赋值，
/// 而是用 copyWith 生成一个新对象。这样做能避免「数据被偷偷改了
/// 但界面没刷新」的bug。
class UserProfile {
  /// 昵称
  final String name;

  /// 性别
  final Gender gender;

  /// 年龄，单位岁
  final int age;

  /// 身高，单位厘米
  final double heightCm;

  /// 体重，单位公斤
  final double weightKg;

  /// 个人简介，可以为空字符串
  final String bio;

  /// 头像图片地址（云端 Storage 的公开 URL），没设置头像时是 null
  final String? avatarUrl;

  const UserProfile({
    required this.name,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.bio = '', // 默认空，不填也行
    this.avatarUrl,
  });

  /// 默认资料，APP首次启动时用这份数据
  ///
  /// 等 Week 2 接上 Firebase 后，这里会改成从云端读取用户真实资料
  factory UserProfile.initial() {
    return const UserProfile(
      name: '张三',
      gender: Gender.male,
      age: 22,
      heightCm: 175,
      weightKg: 70,
      bio: '坚持运动，保持健康',
    );
  }

  /// 转成 Map，用于存进 Hive
  ///
  /// 枚举不能直接存，所以存它的 index（在枚举里的位置序号）
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gender': gender.index,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'bio': bio,
      'avatarUrl': avatarUrl,
    };
  }

  /// 从 Map 还原对象，用于从 Hive 读取
  ///
  /// 每个字段都给了兜底值：万一存储的数据损坏或缺字段，
  /// 也不会崩溃，而是退回默认值
  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    // 用 index 反查枚举。越界时退回第一个而不是 clamp 到最大值 ——
    // clamp 会把损坏的数据(比如 99)夹成最后一个枚举值，
    // 那样性别会莫名变成「女」，退回默认值才是正确的兜底
    final genderIndex = map['gender'] as int? ?? 0;
    final gender = (genderIndex >= 0 && genderIndex < Gender.values.length)
        ? Gender.values[genderIndex]
        : Gender.male;

    return UserProfile(
      name: map['name'] as String? ?? '张三',
      gender: gender,
      age: map['age'] as int? ?? 22,
      // num 转 double：存进去可能是 int（比如 175），读出来要转成 double
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70,
      bio: map['bio'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
    );
  }

  /// 哨兵值：区分「没传（保持原值）」和「传 null（清空头像）」
  ///
  /// avatarUrl 本身可空，普通 copyWith 的 `avatarUrl == null ? 保持 : 更新`
  /// 会把「想清空头像」误判成「不想改」，所以用哨兵对象标记。
  static const Object _unset = Object();

  /// 复制当前对象并替换掉指定字段
  ///
  /// 用法：profile.copyWith(weightKg: 68) 表示「只改体重，其他不变」。
  /// 参数都是可选的，传了就用新值，没传（null）就保留原值。
  /// avatarUrl 例外：传 null 表示清空头像，不传才保持原值。
  UserProfile copyWith({
    String? name,
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? bio,
    Object? avatarUrl = _unset,
  }) {
    return UserProfile(
      // ?? 是空值合并运算符：左边为null时取右边
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bio: bio ?? this.bio,
      avatarUrl: identical(avatarUrl, _unset)
          ? this.avatarUrl
          : avatarUrl as String?,
    );
  }
}
