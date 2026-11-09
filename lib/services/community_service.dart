import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../models/community_post.dart';
import '../models/post_comment.dart';
import 'auth_service.dart';

/// 社区服务
///
/// 帖子读写（分页）+ 点赞 + 评论 + 图片上传 + 实时监听。
/// 所有方法 try-catch，失败静默返回，由页面根据返回值决定要不要提示。
class CommunityService {
  CommunityService._();

  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// 每页帖子数量
  static const int pageSize = 20;

  // ═══════════════════════════════════════════════════════
  //  帖子列表（分页）
  // ═══════════════════════════════════════════════════════

  /// 分页拉取帖子（新到旧），同时统计每条帖子的点赞数、评论数、我是否点过赞。
  ///
  /// offset 从 0 开始；返回条数 < pageSize 说明没有下一页了。
  static Future<List<CommunityPost>> fetchPosts({
    int offset = 0,
    int limit = pageSize,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      // range(a, b) 是闭区间，取 offset 起的 limit 条
      final posts = await client
          .from('community_posts')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // 点赞、评论各单独一张表，一次全拉下来本地统计（小社区够用）
      final likes = await client.from('post_likes').select('post_id, user_id');
      final comments = await client.from('post_comments').select('post_id');

      final myId = AuthService.currentUserId;
      final likeCount = <String, int>{};
      final mine = <String>{};
      for (final row in likes) {
        final postId = row['post_id'] as String?;
        if (postId == null) continue;
        likeCount[postId] = (likeCount[postId] ?? 0) + 1;
        if (myId != null && row['user_id'] == myId) {
          mine.add(postId);
        }
      }

      final commentCount = <String, int>{};
      for (final row in comments) {
        final postId = row['post_id'] as String?;
        if (postId == null) continue;
        commentCount[postId] = (commentCount[postId] ?? 0) + 1;
      }

      return (posts as List).map((p) {
        final map = (p as Map).cast<String, dynamic>();
        final id = map['id'] as String? ?? '';
        return CommunityPost.fromMap(
          map,
          likesCount: likeCount[id] ?? 0,
          likedByMe: mine.contains(id),
          commentCount: commentCount[id] ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════
  //  发帖 / 删帖
  // ═══════════════════════════════════════════════════════

  /// 发帖，返回是否成功
  static Future<bool> createPost({
    required String text,
    String? authorName,
    String? authorAvatar,
    String? imageUrl,
    Map<String, dynamic>? workoutSnapshot,
    Map<String, dynamic>? mealSnapshot,
  }) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return false;

    try {
      // insert 插入一行新帖子；id 由数据库用 gen_random_uuid() 自动生成
      await client.from('community_posts').insert({
        'user_id': uid,
        'author_name': authorName ?? '健身达人',
        'author_avatar': authorAvatar,
        'text': text,
        'image_url': imageUrl,
        'workout_snapshot': workoutSnapshot,
        'meal_snapshot': mealSnapshot,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除自己的帖子
  static Future<void> deletePost(String postId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('community_posts').delete().eq('id', postId);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  //  点赞
  // ═══════════════════════════════════════════════════════

  /// 切换点赞状态，返回新的点赞状态（true=已点赞）
  static Future<bool> toggleLike(String postId) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return false;

    try {
      // 两个 eq 连用 = post_id 和 user_id 同时匹配（AND 关系）
      final existing = await client
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();

      if (existing == null) {
        await client
            .from('post_likes')
            .insert({'post_id': postId, 'user_id': uid});
        return true;
      } else {
        await client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  评论
  // ═══════════════════════════════════════════════════════

  /// 拉取某帖的全部评论（早的在前）
  static Future<List<PostComment>> fetchComments(String postId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final rows = await client
          .from('post_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at');
      return (rows as List)
          .map((r) => PostComment.fromMap((r as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 发评论，返回是否成功
  static Future<bool> addComment({
    required String postId,
    required String text,
    String? authorName,
    String? authorAvatar,
  }) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return false;

    try {
      await client.from('post_comments').insert({
        'post_id': postId,
        'user_id': uid,
        'author_name': authorName ?? '健身达人',
        'author_avatar': authorAvatar,
        'text': text,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除自己的评论
  static Future<void> deleteComment(String commentId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('post_comments').delete().eq('id', commentId);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  //  实时监听 + 图片上传
  // ═══════════════════════════════════════════════════════

  /// 订阅「新帖子」事件
  ///
  /// 有新帖子插入时回调 onNewPost，页面据此提示刷新。
  /// 返回 channel，页面 dispose 时要取消订阅，避免内存泄漏。
  static RealtimeChannel? subscribeToNewPosts(void Function() onNewPost) {
    final client = _client;
    if (client == null) return null;

    try {
      final channel = client.channel('public:community_posts');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'community_posts',
            callback: (_) => onNewPost(),
          )
          .subscribe();
      return channel;
    } catch (_) {
      return null;
    }
  }

  /// 上传帖子图片，返回公开 URL
  static Future<String?> uploadPostImage(Uint8List bytes) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return null;

    try {
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await client.storage.from('posts').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return client.storage.from('posts').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
