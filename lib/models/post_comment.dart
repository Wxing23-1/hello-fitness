/// 帖子评论数据模型
///
/// 从 Supabase `post_comments` 表映射。id 由数据库用 uuid 生成。
class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String text;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatar,
  });

  factory PostComment.fromMap(Map<String, dynamic> map) {
    return PostComment(
      id: map['id'] as String? ?? '',
      postId: map['post_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      authorName: map['author_name'] as String? ?? '健身达人',
      authorAvatar: map['author_avatar'] as String?,
      text: map['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
