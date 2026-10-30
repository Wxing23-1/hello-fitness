/// 社区帖子数据模型
///
/// 从 Supabase `community_posts` 表映射。点赞数不落在帖子里，
/// 由 `post_likes` 表实时统计后填进来。
class CommunityPost {
  final String id;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String text;
  final String? imageUrl;

  /// 训练效果快照（发帖时可选附带），如 {dayName, durationMinutes}
  final Map<String, dynamic>? workoutSnapshot;

  /// 当天饮食快照，如 {calories, protein, carbs, fat}
  final Map<String, dynamic>? mealSnapshot;

  final DateTime createdAt;
  final int likesCount;
  final bool likedByMe;

  const CommunityPost({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatar,
    this.imageUrl,
    this.workoutSnapshot,
    this.mealSnapshot,
    this.likesCount = 0,
    this.likedByMe = false,
  });

  factory CommunityPost.fromMap(
    Map<String, dynamic> map, {
    int likesCount = 0,
    bool likedByMe = false,
  }) {
    return CommunityPost(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      authorName: map['author_name'] as String? ?? '健身达人',
      authorAvatar: map['author_avatar'] as String?,
      text: map['text'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      workoutSnapshot:
          (map['workout_snapshot'] as Map?)?.cast<String, dynamic>(),
      mealSnapshot: (map['meal_snapshot'] as Map?)?.cast<String, dynamic>(),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now(),
      likesCount: likesCount,
      likedByMe: likedByMe,
    );
  }
}
