import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../models/community_post.dart';
import 'auth_service.dart';

/// 社区服务
///
/// 帖子读写 + 点赞 + 图片上传。所有方法 try-catch，失败静默返回，
/// 由页面根据返回值决定要不要提示。
class CommunityService {
  CommunityService._();

  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// 拉取帖子列表（新到旧），同时统计每条帖子的点赞数和我是否点过赞
  static Future<List<CommunityPost>> fetchPosts() async {
    final client = _client;
    if (client == null) return [];

    try {
      final posts = await client
          .from('community_posts')
          .select()
          .order('created_at', ascending: false);

      final likes = await client.from('post_likes').select('post_id, user_id');

      final myId = AuthService.currentUserId;
      final count = <String, int>{};
      final mine = <String>{};
      for (final row in likes) {
        final postId = row['post_id'] as String?;
        if (postId == null) continue;
        count[postId] = (count[postId] ?? 0) + 1;
        if (myId != null && row['user_id'] == myId) {
          mine.add(postId);
        }
      }

      return (posts as List).map((p) {
        final map = (p as Map).cast<String, dynamic>();
        final id = map['id'] as String? ?? '';
        return CommunityPost.fromMap(
          map,
          likesCount: count[id] ?? 0,
          likedByMe: mine.contains(id),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

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

  /// 切换点赞状态，返回新的点赞状态（true=已点赞）
  static Future<bool> toggleLike(String postId) async {
    final client = _client;
    final uid = AuthService.currentUserId;
    if (client == null || uid == null) return false;

    try {
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
