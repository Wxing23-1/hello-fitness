// 头像字段 + 社区帖子模型的单元测试
//
// 覆盖两块最容易写错的逻辑：
// 1. UserProfile.avatarUrl 的 copyWith 哨兵：怎么区分「不改」和「清空」
// 2. CommunityPost.fromMap 的字段映射与快照还原

import 'package:flutter_test/flutter_test.dart';

import 'package:hello_fitness/models/user_profile.dart';
import 'package:hello_fitness/models/community_post.dart';
import 'package:hello_fitness/models/post_comment.dart';

void main() {
  group('UserProfile.avatarUrl', () {
    test('toMap/fromMap 往返保留头像地址', () {
      const p = UserProfile(
        name: '张三',
        gender: Gender.male,
        age: 22,
        heightCm: 175,
        weightKg: 70,
        avatarUrl: 'https://example.com/a.jpg',
      );

      final restored = UserProfile.fromMap(p.toMap());
      expect(restored.avatarUrl, 'https://example.com/a.jpg');
    });

    test('无头像时 toMap 里 avatarUrl 为 null', () {
      const p = UserProfile(
        name: '张三',
        gender: Gender.male,
        age: 22,
        heightCm: 175,
        weightKg: 70,
      );

      final map = p.toMap();
      expect(map['avatarUrl'], isNull);
    });

    test('copyWith 不传 avatarUrl 时保持原值', () {
      const p = UserProfile(
        name: '张三',
        gender: Gender.male,
        age: 22,
        heightCm: 175,
        weightKg: 70,
        avatarUrl: 'https://example.com/a.jpg',
      );

      // 只改名字，头像应保持不变
      final updated = p.copyWith(name: '李四');
      expect(updated.name, '李四');
      expect(updated.avatarUrl, 'https://example.com/a.jpg');
    });

    test('copyWith 传 null 表示清空头像（哨兵逻辑）', () {
      const p = UserProfile(
        name: '张三',
        gender: Gender.male,
        age: 22,
        heightCm: 175,
        weightKg: 70,
        avatarUrl: 'https://example.com/a.jpg',
      );

      // 显式传 null = 移除头像
      final cleared = p.copyWith(avatarUrl: null);
      expect(cleared.avatarUrl, isNull);
    });

    test('copyWith 传新地址会更新头像', () {
      const p = UserProfile(
        name: '张三',
        gender: Gender.male,
        age: 22,
        heightCm: 175,
        weightKg: 70,
        avatarUrl: 'https://example.com/a.jpg',
      );

      final updated = p.copyWith(avatarUrl: 'https://example.com/b.jpg');
      expect(updated.avatarUrl, 'https://example.com/b.jpg');
    });
  });

  group('CommunityPost.fromMap', () {
    test('完整字段映射', () {
      final post = CommunityPost.fromMap(
        {
          'id': 'p1',
          'user_id': 'u1',
          'author_name': '小明',
          'author_avatar': 'https://example.com/avatar.jpg',
          'text': '今天练了胸',
          'image_url': 'https://example.com/post.jpg',
          'workout_snapshot': {'durationMinutes': 45},
          'meal_snapshot': {'calories': 1800.0},
          'created_at': '2026-10-30T12:00:00.000Z',
        },
        likesCount: 3,
        likedByMe: true,
        commentCount: 5,
      );

      expect(post.id, 'p1');
      expect(post.userId, 'u1');
      expect(post.authorName, '小明');
      expect(post.text, '今天练了胸');
      expect(post.workoutSnapshot?['durationMinutes'], 45);
      expect(post.mealSnapshot?['calories'], 1800.0);
      expect(post.likesCount, 3);
      expect(post.likedByMe, true);
      expect(post.commentCount, 5);
      expect(post.createdAt.year, 2026);
    });

    test('可选字段缺失时给默认值，不崩', () {
      final post = CommunityPost.fromMap(
        {
          'id': 'p2',
          'user_id': 'u2',
          'text': '',
          'created_at': '2026-10-30T12:00:00.000Z',
        },
      );

      expect(post.authorName, '健身达人');
      expect(post.authorAvatar, isNull);
      expect(post.imageUrl, isNull);
      expect(post.workoutSnapshot, isNull);
      expect(post.mealSnapshot, isNull);
      expect(post.likesCount, 0);
      expect(post.likedByMe, false);
      expect(post.commentCount, 0);
    });
  });

  group('PostComment.fromMap', () {
    test('完整字段映射', () {
      final c = PostComment.fromMap({
        'id': 'c1',
        'post_id': 'p1',
        'user_id': 'u1',
        'author_name': '小红',
        'author_avatar': 'https://example.com/a.jpg',
        'text': '加油！',
        'created_at': '2026-10-30T13:00:00.000Z',
      });

      expect(c.id, 'c1');
      expect(c.postId, 'p1');
      expect(c.authorName, '小红');
      expect(c.text, '加油！');
      expect(c.authorAvatar, 'https://example.com/a.jpg');
    });

    test('缺字段给默认值', () {
      final c = PostComment.fromMap({
        'id': 'c2',
        'text': 'nice',
        'created_at': '2026-10-30T13:00:00.000Z',
      });

      expect(c.authorName, '健身达人');
      expect(c.postId, '');
      expect(c.authorAvatar, isNull);
    });
  });
}
