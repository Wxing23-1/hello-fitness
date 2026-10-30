# 后续开发计划

> 记录时间：2026-10-30 晚。本文档是「头像 + 社区 + 云同步」三块新需求的落地方案，供后续开发衔接上下文。

## 一、需求背景

当前应用数据全部存在本地 Hive（换设备即丢失），也没有账号体系和头像、社区。本次要补三件事：

1. 头像：首页问候卡和「我的」页顶部加照片头像，支持上传
2. 社区：分享自己的训练效果和当天饮食
3. 云同步：数据上云，登录后换设备不丢

三者的共同前提是**后端 + 用户系统**（现在 `screens/auth/` 为空、`pubspec.yaml` 里 Firebase 依赖被注释）。

## 二、已定决策

| 项 | 决策 |
|---|---|
| 后端/云服务 | **Supabase**（Postgres + Auth + Storage；原定 Firebase 因无 Google 账号改选） |
| 头像存储 | 存云端 Storage（bucket: `avatars`），跟随账号 |
| 实现范围 | 三个一起做，分阶段落地（见下） |
| 头像选图 | 复用已引入的 `image_picker` |
| 开发目标平台 | Web（Chrome）优先，Android/iOS 兼容 |

Supabase 配置：
- Project URL：`https://zifruhulyrflbqecvxnt.supabase.co`
- anon key：`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`（存于 `lib/services/supabase_config.dart`）

代码里已预留接入点，方向吻合：
- `UserStore`：注释「接上 Firestore 后在 `_persistXxx` 加云端写入」→ 改为在云同步层处理
- `LocalStorage`：注释「本地缓存 + 云端同步」
- `pubspec.yaml`：被注释的 Firebase 依赖不再启用，改加 `supabase_flutter`

## 三、分阶段计划

### 阶段 0 — Supabase 接入（硬前提，已完成一次人工操作）
- ~~Firebase~~ Supabase 项目已建好，拿到 Project URL + anon key
- 加 `supabase_flutter` 依赖、`main.dart` 初始化
- 建表 SQL（profiles / workout_logs / meal_entries / weight_logs / community_posts / post_likes）+ Storage bucket `avatars`
- **状态：进行中**

### 阶段 1 — 账号 + 云同步
- `AuthService`：邮箱注册 / 登录 / 登出 / 登录态监听
- `UserProfile` 新增 `avatarUrl` 字段
- `CloudSyncService`：登录后按 `users/{uid}/...` 同步 profile/goal/workoutLogs/meals/weightLogs，本地 Hive 作缓存
- 「我的」页顶部加登录入口

### 阶段 2 — 头像
- 选图 + 裁剪，上传 Storage，`avatarUrl` 随账号同步
- 首页问候卡、「我的」页头部显示头像

### 阶段 3 — 社区
- `CommunityPost` 模型（文字 + 图片 + 训练/饮食快照 + 点赞）
- 社区列表页（Firestore 流式订阅）+ 发帖页（分享今天训练效果/饮食）

## 四、待定项

- 社区入口位置：**已定** —— 新增底部第 6 标签「社区」

## 五、明天待办（衔接起点）

1. ~~建 Firebase 项目~~ 已建 Supabase，拿到 URL + anon key
2. ~~确认社区入口位置~~ 新增底部第 6 标签「社区」
3. 按阶段 1 → 2 → 3 顺序开工（进行中）
