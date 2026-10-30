import 'package:flutter/material.dart';

/// 用户头像组件
///
/// 有头像地址就显示网络图片，没有（或加载失败）就退回灰色人形图标。
/// 首页问候卡和「我的」页顶部共用，保证两处头像显示一致。
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 36,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      // 有图就用图，没有就显示人形图标
      backgroundImage: hasImage ? NetworkImage(url) : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage
          ? null
          : Icon(Icons.account_circle, size: radius * 2, color: Colors.blue),
    );

    if (onTap == null) return avatar;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
