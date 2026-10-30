-- ═══════════════════════════════════════════════════════════
--  Hello Fitness  ·  Supabase 建表脚本
--  在 Supabase 控制台 → SQL Editor 里整段粘贴执行一次即可
-- ═══════════════════════════════════════════════════════════

-- 生成随机 uuid（社区帖子 id 用）
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────
-- 1. 用户资料表（每用户一行，id 关联 auth.users）
--    把 profile + goal + settings + activityLevel 合并成一行，
--    云同步时整行 upsert，省得多张表来回写
-- ─────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  name             text        not null default '张三',
  gender           int         not null default 0,
  age              int         not null default 22,
  height_cm        numeric     not null default 175,
  weight_kg        numeric     not null default 70,
  bio              text        not null default '',
  avatar_url       text,
  goal_type        int         not null default 0,
  target_weight_kg numeric     not null default 65,
  weekly_workouts  int         not null default 4,
  daily_calories   int         not null default 1800,
  daily_water_ml   int         not null default 2000,
  activity_level   int         not null default 0,
  dark_mode        boolean     not null default false,
  workout_reminder boolean     not null default true,
  water_reminder   boolean     not null default false,
  unit_system      text        not null default '公制',
  updated_at       timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "profiles: 本人可读写"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ─────────────────────────────────────────────────────────
-- 2. 训练完成记录（整条 toMap 存 jsonb，简化字段映射）
-- ─────────────────────────────────────────────────────────
create table if not exists public.workout_logs (
  id         text        primary key,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  data       jsonb       not null,
  created_at timestamptz not null default now()
);

alter table public.workout_logs enable row level security;
create policy "workout_logs: 本人可读写"
  on public.workout_logs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- 3. 饮食记录
-- ─────────────────────────────────────────────────────────
create table if not exists public.meal_entries (
  id         text        primary key,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  data       jsonb       not null,
  eaten_at   timestamptz,
  created_at timestamptz not null default now()
);

alter table public.meal_entries enable row level security;
create policy "meal_entries: 本人可读写"
  on public.meal_entries for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- 4. 体重记录
-- ─────────────────────────────────────────────────────────
create table if not exists public.weight_logs (
  id         text        primary key,
  user_id    uuid        not null references auth.users (id) on delete cascade,
  data       jsonb       not null,
  created_at timestamptz not null default now()
);

alter table public.weight_logs enable row level security;
create policy "weight_logs: 本人可读写"
  on public.weight_logs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- 5. 社区帖子（所有人可读，只能改自己的）
-- ─────────────────────────────────────────────────────────
create table if not exists public.community_posts (
  id               uuid        primary key default gen_random_uuid(),
  user_id          uuid        not null references auth.users (id) on delete cascade,
  author_name      text        not null default '健身达人',
  author_avatar    text,
  text             text        not null default '',
  image_url        text,
  workout_snapshot jsonb,
  meal_snapshot    jsonb,
  created_at       timestamptz not null default now()
);

alter table public.community_posts enable row level security;
create policy "community_posts: 所有人可读"
  on public.community_posts for select using (true);
create policy "community_posts: 本人可发"
  on public.community_posts for insert with check (auth.uid() = user_id);
create policy "community_posts: 本人可删"
  on public.community_posts for delete using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- 6. 帖子点赞（一人一帖只记一条，联合主键天然去重）
-- ─────────────────────────────────────────────────────────
create table if not exists public.post_likes (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (post_id, user_id)
);

alter table public.post_likes enable row level security;
create policy "post_likes: 所有人可读"
  on public.post_likes for select using (true);
create policy "post_likes: 本人可点赞/取消"
  on public.post_likes for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────
-- 7. Storage：头像桶（公开可读，登录用户可上传自己的）
-- ─────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars: 公开可读"
  on storage.objects for select
  using (bucket_id = 'avatars');
create policy "avatars: 登录可上传"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars');
create policy "avatars: 登录可更新"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars');
create policy "avatars: 登录可删除"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars');

-- ─────────────────────────────────────────────────────────
-- 8. Storage：帖子图片桶
-- ─────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

create policy "posts: 公开可读"
  on storage.objects for select
  using (bucket_id = 'posts');
create policy "posts: 登录可上传"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'posts');
create policy "posts: 登录可删除"
  on storage.objects for delete to authenticated
  using (bucket_id = 'posts');
