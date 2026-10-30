import 'package:flutter/material.dart';

/// 图表的空状态
///
/// 没数据时显示提示而不是一张空坐标系 —— 空图会让人以为功能坏了。
/// 四张图共用，所以抽成组件。
class ChartEmpty extends StatelessWidget {
  final IconData icon;

  /// 主提示
  final String message;

  /// 下面的小字，告诉用户怎么做才有数据
  final String? hint;

  const ChartEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 和图表一样高，避免有无数据时卡片高度跳变
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
