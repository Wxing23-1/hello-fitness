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

## 六、补充进度（2026-10-30 续）

- 阶段 0~3 全部完成：登录/注册/找回密码、云同步（资料/目标/设置/训练/饮食/体重/AI计划/自定义食物）、头像、社区（列表/发帖/点赞/删帖）
- 新增 `AuthGate`：未登录先到登录页，可「暂不登录」进主界面用本地功能
- 新增测试 `avatar_community_test.dart`（头像哨兵逻辑 + 帖子模型），全量 261 个测试通过
- 待办（未做，需再排期）：
  - 找回密码「点邮件链接回应用设新密码」闭环（需配 Supabase Site URL + deep link）
  - 社区：评论、分页、实时订阅
  - 头像裁剪（目前只有压缩）
  - 云同步 profile 双设备冲突处理
  - README 更新为项目说明
  - 新服务（auth/云同步/社区）补充服务层单测

