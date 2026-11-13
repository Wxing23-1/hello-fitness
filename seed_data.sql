-- ═══════════════════════════════════════════════════════════
--  Hello Fitness · 测试数据种子脚本
--  在 Supabase 控制台 → SQL Editor 里整段粘贴运行一次
-- ═══════════════════════════════════════════════════════════
--  会写入（都挂到 target_user 名下）：
--    1. 一个「4周减脂塑形」训练计划 → ai_plans
--    2. 最近 30 天的三餐+加餐     → meal_entries
--    3. 8 条训练打卡              → workout_logs
--    4. 10 条体重记录             → weight_logs
--
--  target_user 取邮箱为 136572576@qq.com 的账号；
--  如果换账号，把下面各处的 email 条件改成新邮箱即可。
-- ═══════════════════════════════════════════════════════════

with target_user as (
  select id from auth.users where email = '136572576@qq.com' limit 1
)

-- ═══════════════════════════════════════════════════════════
-- 1. 训练计划（4周减脂塑形，每周4练）
-- ═══════════════════════════════════════════════════════════
insert into public.ai_plans (id, user_id, data)
select
  'plan_test_month',
  target_user.id,
  '{
    "id": "plan_test_month",
    "name": "4周减脂塑形",
    "description": "测试数据：每周4练（胸肩三头/背二头/腿臀/有氧核心），配合每日1800千卡饮食",
    "goal": 0,
    "level": 0,
    "category": 2,
    "durationWeeks": 4,
    "workoutsPerWeek": 4,
    "isAiGenerated": true,
    "days": [
      {
        "id": "day_tm_1",
        "planId": "plan_test_month",
        "dayNumber": 1,
        "name": "胸肩三头",
        "category": 1,
        "estimatedMinutes": 45,
        "exercises": [
          {"id": "ex_tm_1_1", "name": "俯卧撑", "category": 1, "sets": 3, "reps": 10, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "胸肌", "equipment": null, "tips": "身体成一条直线，下放到胸口离地一拳"},
          {"id": "ex_tm_1_2", "name": "哑铃卧推", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "胸肌", "equipment": "哑铃", "targetWeightKg": 10, "tips": "肩胛骨后收下沉，推起时别锁死手肘"},
          {"id": "ex_tm_1_3", "name": "哑铃飞鸟", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "胸肌", "equipment": "哑铃", "targetWeightKg": 6, "tips": "肘微屈固定，沿弧线收拢"},
          {"id": "ex_tm_1_4", "name": "凳上臂屈伸", "category": 1, "sets": 3, "reps": 10, "isTimeBased": false, "restSeconds": 45, "muscleGroup": "三头肌", "equipment": null, "tips": "身体贴凳，屈肘下放到大臂平行"},
          {"id": "ex_tm_1_5", "name": "哑铃颈后臂屈伸", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 45, "muscleGroup": "三头肌", "equipment": "哑铃", "targetWeightKg": 6, "tips": "大臂夹紧头部两侧，只动小臂"}
        ]
      },
      {
        "id": "day_tm_2",
        "planId": "plan_test_month",
        "dayNumber": 2,
        "name": "背二头",
        "category": 1,
        "estimatedMinutes": 45,
        "exercises": [
          {"id": "ex_tm_2_1", "name": "哑铃划船", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "背部", "equipment": "哑铃", "targetWeightKg": 16, "tips": "腰背挺直，肘贴身拉向腹部"},
          {"id": "ex_tm_2_2", "name": "反向划船", "category": 1, "sets": 3, "reps": 10, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "背部", "equipment": null, "tips": "身体成直线，拉到胸口触杆"},
          {"id": "ex_tm_2_3", "name": "哑铃弯举", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 45, "muscleGroup": "二头肌", "equipment": "哑铃", "targetWeightKg": 8, "tips": "大臂固定，慢放快拉"},
          {"id": "ex_tm_2_4", "name": "锤式弯举", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 45, "muscleGroup": "二头肌", "equipment": "哑铃", "targetWeightKg": 8, "tips": "掌心相对，练二头外侧"}
        ]
      },
      {
        "id": "day_tm_3",
        "planId": "plan_test_month",
        "dayNumber": 3,
        "name": "腿臀",
        "category": 1,
        "estimatedMinutes": 45,
        "exercises": [
          {"id": "ex_tm_3_1", "name": "徒手深蹲", "category": 1, "sets": 3, "reps": 15, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "腿部", "equipment": null, "tips": "膝盖对准脚尖，蹲到大腿平行地面"},
          {"id": "ex_tm_3_2", "name": "弓步蹲", "category": 1, "sets": 3, "reps": 12, "isTimeBased": false, "restSeconds": 60, "muscleGroup": "腿部", "equipment": null, "tips": "前后腿都约90度，膝盖别超过脚尖"},
          {"id": "ex_tm_3_3", "name": "臀桥", "category": 1, "sets": 3, "reps": 15, "isTimeBased": false, "restSeconds": 45, "muscleGroup": "臀部", "equipment": null, "tips": "顶峰夹臀停1秒，别用腰发力"},
          {"id": "ex_tm_3_4", "name": "提踵", "category": 1, "sets": 3, "reps": 20, "isTimeBased": false, "restSeconds": 30, "muscleGroup": "小腿", "equipment": null, "tips": "脚跟尽量抬高，顶峰停1秒"}
        ]
      },
      {
        "id": "day_tm_4",
        "planId": "plan_test_month",
        "dayNumber": 4,
        "name": "有氧核心",
        "category": 2,
        "estimatedMinutes": 40,
        "exercises": [
          {"id": "ex_tm_4_1", "name": "开合跳", "category": 0, "sets": 4, "reps": 30, "isTimeBased": true, "restSeconds": 30, "muscleGroup": "全身", "equipment": null, "tips": "落地轻柔，保持节奏"},
          {"id": "ex_tm_4_2", "name": "平板支撑", "category": 1, "sets": 3, "reps": 30, "isTimeBased": true, "restSeconds": 60, "muscleGroup": "核心", "equipment": null, "tips": "肩肘垂直，身体成直线"},
          {"id": "ex_tm_4_3", "name": "卷腹", "category": 1, "sets": 3, "reps": 15, "isTimeBased": false, "restSeconds": 45, "muscleGroup": "腹肌", "equipment": null, "tips": "腹部发力卷起上背，别拽脖子"},
          {"id": "ex_tm_4_4", "name": "登山跑", "category": 2, "sets": 3, "reps": 30, "isTimeBased": true, "restSeconds": 45, "muscleGroup": "全身", "equipment": null, "tips": "核心收紧，左右腿交替提膝"},
          {"id": "ex_tm_4_5", "name": "快走或慢跑", "category": 0, "sets": 1, "reps": 1200, "isTimeBased": true, "restSeconds": 0, "muscleGroup": "心肺", "equipment": null, "tips": "20分钟，心率控制在能说话不能唱歌"}
        ]
      }
    ]
  }'::jsonb
from target_user
on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════════
-- 2. 最近 30 天的饮食（三餐轮换 + 加餐）
-- ═══════════════════════════════════════════════════════════
-- 三餐菜单：每个 meal_type 有 3 个选项，按天轮换
with target_user as (
  select id from auth.users where email = '136572576@qq.com' limit 1
),
menu as (
  select * from (values
    -- meal_type, opt, name, kcal, protein, carbs, fat, category
    (0, 0, '燕麦粥+水煮蛋', 450, 25, 55, 15, 0),
    (0, 1, '全麦面包+牛奶', 400, 20, 50, 14, 0),
    (0, 2, '鸡蛋+无糖豆浆', 380, 22, 30, 18, 1),
    (1, 0, '鸡胸肉+杂粮饭', 600, 45, 70, 15, 1),
    (1, 1, '牛肉+糙米饭',   650, 40, 65, 22, 1),
    (1, 2, '清蒸鱼+荞麦面', 580, 38, 70, 16, 1),
    (2, 0, '鱼肉+红薯',     500, 35, 55, 16, 1),
    (2, 1, '豆腐+玉米',     450, 25, 60, 14, 1),
    (2, 2, '虾仁+西兰花',   480, 42, 30, 18, 1)
  ) as m(meal_type, opt, name, kcal, protein, carbs, fat, category)
)
insert into public.meal_entries (id, user_id, data)
select
  'meal_seed_' || mo.meal_type || '_' || d,
  tu.id,
  jsonb_build_object(
    'id',        'meal_seed_' || mo.meal_type || '_' || d,
    'mealType',  mo.meal_type,
    'eatenAt',   (extract(epoch from (date_trunc('day', now()) - ((29 - d) * interval '1 day') + ((6 + mo.meal_type * 6) * interval '1 hour'))) * 1000)::bigint,
    'foodName',  mo.name,
    'grams',     200,
    'calories',  mo.kcal,
    'protein',   mo.protein,
    'carbs',     mo.carbs,
    'fat',       mo.fat,
    'category',  mo.category,
    'note',      null,
    'fromAi',    false
  )
from generate_series(0, 29) as d
cross join generate_series(0, 2) as mt
cross join target_user tu
join menu mo on mo.meal_type = mt and mo.opt = (d % 3)
on conflict (id) do nothing;

-- 加餐（每天固定坚果+香蕉）
with target_user as (
  select id from auth.users where email = '136572576@qq.com' limit 1
)
insert into public.meal_entries (id, user_id, data)
select
  'meal_seed_snack_' || d,
  tu.id,
  jsonb_build_object(
    'id',        'meal_seed_snack_' || d,
    'mealType',  3,
    'eatenAt',   (extract(epoch from (date_trunc('day', now()) - ((29 - d) * interval '1 day') + interval '15 hours')) * 1000)::bigint,
    'foodName',  '坚果+香蕉',
    'grams',     150,
    'calories',  250,
    'protein',   6,
    'carbs',     30,
    'fat',       12,
    'category',  4,
    'note',      null,
    'fromAi',    false
  )
from generate_series(0, 29) as d
cross join target_user tu
on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════════
-- 3. 训练打卡（8 条，散布在最近 30 天）
-- ═══════════════════════════════════════════════════════════
with target_user as (
  select id from auth.users where email = '136572576@qq.com' limit 1
),
logs as (
  select * from (values
    -- days_ago, day_id,    duration, feeling
    (1,  'day_tm_1', 45, 4),
    (3,  'day_tm_2', 42, 3),
    (6,  'day_tm_3', 48, 4),
    (8,  'day_tm_4', 38, 5),
    (10, 'day_tm_1', 45, 4),
    (13, 'day_tm_2', 45, 3),
    (17, 'day_tm_3', 50, 4),
    (20, 'day_tm_4', 40, 5)
  ) as l(days_ago, day_id, duration, feeling)
)
insert into public.workout_logs (id, user_id, data)
select
  'log_seed_' || l.days_ago,
  tu.id,
  jsonb_build_object(
    'id',              'log_seed_' || l.days_ago,
    'planId',          'plan_test_month',
    'dayId',           l.day_id,
    'completedAt',     (extract(epoch from (date_trunc('day', now()) - (l.days_ago * interval '1 day') + interval '19 hours')) * 1000)::bigint,
    'durationMinutes', l.duration,
    'exercises',       jsonb_build_array(
      jsonb_build_object('exerciseId', 'ex_tm_1_1', 'completedSets', 3, 'repsPerSet', jsonb_build_array(10,10,10), 'weight', null),
      jsonb_build_object('exerciseId', 'ex_tm_1_2', 'completedSets', 3, 'repsPerSet', jsonb_build_array(12,12,12), 'weight', 10),
      jsonb_build_object('exerciseId', 'ex_tm_1_3', 'completedSets', 3, 'repsPerSet', jsonb_build_array(12,12,12), 'weight', 6)
    ),
    'feeling',         l.feeling,
    'note',            null
  )
from logs l
cross join target_user tu
on conflict (id) do nothing;

-- ═══════════════════════════════════════════════════════════
-- 4. 体重记录（10 条，最近 30 天，缓慢下降）
-- ═══════════════════════════════════════════════════════════
with target_user as (
  select id from auth.users where email = '136572576@qq.com' limit 1
),
weights as (
  select * from (values
    (1, 71.8), (4, 71.5), (7, 71.4), (10, 71.0),
    (14, 70.8), (17, 70.5), (20, 70.3), (23, 70.0),
    (26, 69.8), (29, 69.5)
  ) as w(days_ago, weight_kg)
)
insert into public.weight_logs (id, user_id, data)
select
  'wl_seed_' || w.days_ago,
  tu.id,
  jsonb_build_object(
    'id',            'wl_seed_' || w.days_ago,
    'date',          (extract(epoch from (date_trunc('day', now()) - (w.days_ago * interval '1 day') + interval '7 hours')) * 1000)::bigint,
    'weightKg',      w.weight_kg,
    'bodyFatPercent', null,
    'note',          null
  )
from weights w
cross join target_user tu
on conflict (id) do nothing;

-- 完成，回 App 重新登录（或下拉刷新）即可看到数据
