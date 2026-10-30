import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/community_service.dart';
import '../../services/user_store.dart';

/// 发帖页
///
/// 输入文字 + 可选图片 + 可选附带「今天的训练效果 / 饮食」快照。
/// 快照从 UserStore 现成数据拼出来，发帖时随帖子一起存。
class NewPostPage extends StatefulWidget {
  const NewPostPage({super.key});

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final _textCtrl = TextEditingController();
  String? _imageUrl;
  bool _busy = false;

  bool _attachWorkout = false;
  bool _attachMeal = false;

  @override
  void initState() {
    super.initState();
    // 有数据才默认勾上，避免发一堆空快照
    final store = context.read<UserStore>();
    _attachWorkout = store.todayWorkoutMinutes > 0;
    _attachMeal = store.todaySummary.entryCount > 0;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    final bytes = await file.readAsBytes();
    final url = await CommunityService.uploadPostImage(bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _imageUrl = url;
    });
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片上传失败')),
      );
    }
  }

  Future<void> _submit() async {
    final store = context.read<UserStore>();
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写点什么或选张图片吧')),
      );
      return;
    }

    setState(() => _busy = true);

    Map<String, dynamic>? workoutSnapshot;
    if (_attachWorkout && store.todayWorkoutMinutes > 0) {
      workoutSnapshot = {'durationMinutes': store.todayWorkoutMinutes};
    }

    Map<String, dynamic>? mealSnapshot;
    if (_attachMeal && store.todaySummary.entryCount > 0) {
      final s = store.todaySummary;
      mealSnapshot = {
        'calories': s.calories,
        'protein': s.protein,
        'carbs': s.carbs,
        'fat': s.fat,
      };
    }

    final ok = await CommunityService.createPost(
      text: text,
      authorName: store.profile.name,
      authorAvatar: store.profile.avatarUrl,
      imageUrl: _imageUrl,
      workoutSnapshot: workoutSnapshot,
      mealSnapshot: mealSnapshot,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布失败，请稍后再试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('发布动态'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _textCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '分享你的训练效果或今天的饮食…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          // 图片
          if (_imageUrl == null)
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('添加图片'),
            )
          else
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _imageUrl!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                IconButton.filled(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _busy ? null : () => setState(() => _imageUrl = null),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // 快照开关
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('附上今天的训练效果'),
                  subtitle: Text(
                    context.read<UserStore>().todayWorkoutMinutes > 0
                        ? '今日已练 ${context.read<UserStore>().todayWorkoutMinutes} 分钟'
                        : '今天还没有训练记录',
                  ),
                  value: _attachWorkout,
                  onChanged: _busy ? null : (v) => setState(() => _attachWorkout = v),
                ),
                SwitchListTile(
                  title: const Text('附上今天的饮食'),
                  subtitle: Text(
                    _mealSummaryText(),
                  ),
                  value: _attachMeal,
                  onChanged: _busy ? null : (v) => setState(() => _attachMeal = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mealSummaryText() {
    final s = context.read<UserStore>().todaySummary;
    if (s.entryCount == 0) return '今天还没有饮食记录';
    return '${s.calories.toStringAsFixed(0)} 千卡 · ${s.entryCount} 条记录';
  }
}
