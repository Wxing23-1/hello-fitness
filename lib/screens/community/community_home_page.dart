import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../services/community_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_store.dart';
import '../../widgets/user_avatar.dart';
import '../auth/auth_page.dart';
import 'new_post_page.dart';

/// 社区页
///
/// 展示大家的训练效果和饮食分享，可点赞、发帖、删自己的帖。
/// 未登录只能看，发帖/点赞会引导先登录。
class CommunityHomePage extends StatefulWidget {
  const CommunityHomePage({super.key});

  @override
  State<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends State<CommunityHomePage> {
  List<CommunityPost>? _posts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await CommunityService.fetchPosts();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  Future<void> _openComposer() async {
    final store = context.read<UserStore>();
    if (!store.isSignedIn) {
      _promptLogin();
      return;
    }
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewPostPage()),
    );
    if (posted == true) _load();
  }

  void _promptLogin() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请先登录'),
        content: const Text('登录后即可发帖和点赞。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(CommunityPost post) async {
    final store = context.read<UserStore>();
    if (!store.isSignedIn) {
      _promptLogin();
      return;
    }
    final liked = await CommunityService.toggleLike(post.id);
    if (!mounted || _posts == null) return;

    setState(() {
      _posts = _posts!.map((p) {
        if (p.id != post.id) return p;
        // 直接重建这条帖子，更新点赞状态
        return CommunityPost(
          id: p.id,
          userId: p.userId,
          authorName: p.authorName,
          text: p.text,
          createdAt: p.createdAt,
          authorAvatar: p.authorAvatar,
          imageUrl: p.imageUrl,
          workoutSnapshot: p.workoutSnapshot,
          mealSnapshot: p.mealSnapshot,
          likesCount: liked ? p.likesCount + 1 : p.likesCount - 1,
          likedByMe: liked,
        );
      }).toList();
    });
  }

  Future<void> _deletePost(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('确定删除这条帖子吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CommunityService.deletePost(post.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('社区'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openComposer,
        child: const Icon(Icons.edit),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts == null || _posts!.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    itemCount: _posts!.length,
                    itemBuilder: (context, i) =>
                        _PostCard(
                          post: _posts![i],
                          onLike: () => _toggleLike(_posts![i]),
                          onDelete: () => _deletePost(_posts![i]),
                        ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            '还没有帖子',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '点右下角，分享你的训练效果或饮食吧',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// 单条帖子卡片
class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = post.userId == AuthService.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者行
          Row(
            children: [
              UserAvatar(avatarUrl: post.authorAvatar, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('MM-dd HH:mm').format(post.createdAt),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (isMine)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 正文
          if (post.text.isNotEmpty)
            Text(post.text, style: const TextStyle(fontSize: 14, height: 1.4)),

          // 图片
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: Colors.grey.shade100,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ],

          // 快照标签
          if (post.workoutSnapshot != null || post.mealSnapshot != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (post.workoutSnapshot != null)
                  _snapshotChip(Icons.fitness_center, Colors.blue,
                      _workoutText(post.workoutSnapshot!)),
                if (post.mealSnapshot != null)
                  _snapshotChip(Icons.restaurant, Colors.orange,
                      _mealText(post.mealSnapshot!)),
              ],
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // 点赞
          Row(
            children: [
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                        color: post.likedByMe ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(
                          fontSize: 13,
                          color: post.likedByMe ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _snapshotChip(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  String _workoutText(Map<String, dynamic> s) {
    final day = s['dayName'];
    final mins = s['durationMinutes'];
    if (day == null && mins == null) return '训练打卡';
    return '训练：${day ?? ''} ${mins != null ? '$mins分钟' : ''}'.trim();
  }

  String _mealText(Map<String, dynamic> s) {
    final kcal = s['calories'];
    if (kcal == null) return '饮食记录';
    return '饮食：${kcal.toStringAsFixed(0)} 千卡';
  }
}
