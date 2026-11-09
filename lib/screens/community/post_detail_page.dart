import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../models/post_comment.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/user_store.dart';
import '../../widgets/user_avatar.dart';
import '../auth/auth_page.dart';

/// 帖子详情页：帖子正文 + 评论列表 + 发评论
///
/// 评论后返回 true，让列表页刷新评论数。
class PostDetailPage extends StatefulWidget {
  final CommunityPost post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentCtrl = TextEditingController();
  List<PostComment>? _comments;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final list = await CommunityService.fetchComments(widget.post.id);
    if (!mounted) return;
    setState(() => _comments = list);
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final store = context.read<UserStore>();
    if (!store.isSignedIn) {
      _promptLogin();
      return;
    }

    setState(() => _sending = true);
    final ok = await CommunityService.addComment(
      postId: widget.post.id,
      text: text,
      authorName: store.profile.name,
      authorAvatar: store.profile.avatarUrl,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      _commentCtrl.clear();
      await _loadComments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评论失败，请稍后再试')),
      );
    }
  }

  void _promptLogin() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请先登录'),
        content: const Text('登录后才能评论。'),
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

  Future<void> _deleteComment(PostComment c) async {
    await CommunityService.deleteComment(c.id);
    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('动态详情'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _PostBody(post: widget.post),
                const SizedBox(height: 16),
                const Text(
                  '评论',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_comments == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_comments!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        '还没有评论，来抢沙发',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ..._comments!.map((c) => _CommentTile(
                        comment: c,
                        onDelete: () => _deleteComment(c),
                      )),
              ],
            ),
          ),

          // 底部评论输入框
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: const InputDecoration(
                        hintText: '说点什么…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _sendComment,
                    icon: const Icon(Icons.send, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 帖子正文（复用列表里的展示逻辑，简化版）
class _PostBody extends StatelessWidget {
  final CommunityPost post;

  const _PostBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ],
          ),
          if (post.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(post.text, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey.shade100,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单条评论
class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final VoidCallback onDelete;

  const _CommentTile({required this.comment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isMine = comment.userId == AuthService.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(avatarUrl: comment.authorAvatar, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MM-dd HH:mm').format(comment.createdAt),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.text, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          if (isMine)
            InkWell(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.delete_outline,
                    size: 16, color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }
}
