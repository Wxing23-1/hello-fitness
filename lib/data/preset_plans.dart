import '../models/training_plan.dart';

/// 预置训练计划数据
///
/// 提供 4 套计划，覆盖有氧 / 无氧 / 混合三种类别：
///   1. 新手减脂（混合）—— 有氧为主，带一点徒手力量
///   2. 纯有氧燃脂（有氧）—— 跑步、骑行、跳绳
///   3. 增肌计划（无氧）—— 健身房器械，经典推拉腿
///   4. 体能维持（混合）—— 力量 + 有氧均衡
///
/// 用户也可以让 AI 根据自己的情况生成个性化计划（见 AiPlanService）。
class PresetPlans {
  /// 获取所有预置计划
  static List<TrainingPlan> getAll() {
    return [
      _beginnerFatLoss(),
      _pureCardio(),
      _intermediateMuscleGain(),
      _keepFit(),
    ];
  }

  /// 根据 ID 获取计划，找不到时返回 null
  static TrainingPlan? getById(String id) {
    final all = getAll();
    for (final plan in all) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  /// 按类别筛选计划
  static List<TrainingPlan> getByCategory(TrainingCategory category) {
    return getAll().where((p) => p.category == category).toList();
  }

  // ═══════════════════════════════════════════════════════
  //  计划 1：新手减脂（混合，4周，每周3次）
  // ═══════════════════════════════════════════════════════
  static TrainingPlan _beginnerFatLoss() {
    const planId = 'plan_beginner_fat_loss';

    return const TrainingPlan(
      id: planId,
      name: '4周新手减脂',
      description: '徒手动作为主，在家就能做。有氧燃脂配合基础力量，避免减脂期掉肌肉',
      goal: TrainingGoal.loseWeight,
      level: TrainingLevel.beginner,
      category: TrainingCategory.mixed,
      durationWeeks: 4,
      workoutsPerWeek: 3,
      days: [
        // ── 第 1 天：全身循环（混合）──
        TrainingDay(
          id: 'day_fl_1',
          planId: planId,
          dayNumber: 1,
          name: '全身循环',
          category: TrainingCategory.mixed,
          estimatedMinutes: 35,
          exercises: [
            Exercise(
              id: 'ex_fl_1_1',
              name: '开合跳',
              category: TrainingCategory.aerobic,
              sets: 3,
              reps: 40,
              isTimeBased: true,
              restSeconds: 30,
              muscleGroup: '全身',
              tips: '落地轻柔用前脚掌，保持匀速呼吸',
            ),
            Exercise(
              id: 'ex_fl_1_2',
              name: '自重深蹲',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 15,
              restSeconds: 45,
              muscleGroup: '腿部',
              tips: '膝盖对准脚尖方向，下蹲到大腿与地面平行',
            ),
            Exercise(
              id: 'ex_fl_1_3',
              name: '跪姿俯卧撑',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 10,
              restSeconds: 45,
              muscleGroup: '胸肌',
              tips: '新手从膝盖着地开始，核心收紧别塌腰',
            ),
            Exercise(
              id: 'ex_fl_1_4',
              name: '平板支撑',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 30,
              isTimeBased: true,
              restSeconds: 60,
              muscleGroup: '核心',
              tips: '肩肘垂直，身体成一条直线，别撅屁股',
              steps: [
                '肘部在肩膀正下方撑地',
                '双脚与髋同宽，脚尖踩地',
                '收紧核心和臀部，身体成直线',
                '均匀呼吸保持姿势',
              ],
              mistakes: [
                '塌腰，腰部代偿还会酸痛',
                '撅臀把压力卸掉，核心没受刺激',
                '憋气导致血压升高',
              ],
            ),
          ],
        ),

        // ── 第 2 天：有氧燃脂 ──
        TrainingDay(
          id: 'day_fl_2',
          planId: planId,
          dayNumber: 2,
          name: '有氧燃脂',
          category: TrainingCategory.aerobic,
          estimatedMinutes: 30,
          exercises: [
            Exercise(
              id: 'ex_fl_2_1',
              name: '快走或慢跑',
              category: TrainingCategory.aerobic,
              sets: 1,
              reps: 1500,
              isTimeBased: true,
              restSeconds: 0,
              muscleGroup: '心肺',
              tips: '25分钟，心率控制在能说话但不能唱歌的强度',
            ),
            Exercise(
              id: 'ex_fl_2_2',
              name: '原地高抬腿',
              category: TrainingCategory.aerobic,
              sets: 3,
              reps: 30,
              isTimeBased: true,
              restSeconds: 30,
              muscleGroup: '腿部',
              tips: '大腿抬到与地面平行，摆臂配合',
            ),
          ],
        ),

        // ── 第 3 天：下肢核心（无氧）──
        TrainingDay(
          id: 'day_fl_3',
          planId: planId,
          dayNumber: 3,
          name: '下肢核心',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 35,
          exercises: [
            Exercise(
              id: 'ex_fl_3_1',
              name: '箭步蹲',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 45,
              muscleGroup: '腿部',
              tips: '左右各12次，前后腿都保持90度',
              steps: [
                '双脚前后分开约一步半距离',
                '上身保持直立，核心收紧',
                '下蹲至前后腿都接近 90 度',
                '前脚掌蹬地起身，保持平衡',
              ],
              mistakes: [
                '前膝超过脚尖，膝关节剪切力大',
                '上身前倾失去平衡',
                '后腿膝盖砸向地面',
              ],
            ),
            Exercise(
              id: 'ex_fl_3_2',
              name: '臀桥',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 15,
              restSeconds: 45,
              muscleGroup: '臀部',
              tips: '顶峰夹臀停1秒，感受臀部发力而不是腰',
              steps: [
                '仰卧屈膝，双脚与髋同宽踩地',
                '脚跟发力将臀部向上顶起',
                '顶点夹紧臀部停留 1 秒',
                '控制下放到臀部接近地面',
              ],
              mistakes: [
                '用腰部发力顶起，腰椎过度伸展',
                '脚放太远变成练大腿后侧',
                '顶点不收缩，白做一次',
              ],
            ),
            Exercise(
              id: 'ex_fl_3_3',
              name: '俄罗斯转体',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 20,
              restSeconds: 45,
              muscleGroup: '核心',
              tips: '左右各20次，可以手持水瓶增加难度',
              steps: [
                '坐姿屈膝，上身后倾约 45 度',
                '双手相握或持重物于胸前',
                '腹部发力带动上身左右转动',
                '转到侧面时稍停再换边',
              ],
              mistakes: [
                '只转手臂，腹部不发力',
                '上身完全坐直，张力丢失',
                '速度过快变成甩手',
              ],
            ),
            Exercise(
              id: 'ex_fl_3_4',
              name: '登山跑',
              category: TrainingCategory.mixed,
              sets: 3,
              reps: 40,
              isTimeBased: true,
              restSeconds: 45,
              muscleGroup: '全身',
              tips: '左右交替尽量快，保持臀部不要抬高',
              steps: [
                '俯撑姿势，双手撑地在肩下',
                '身体保持一条直线',
                '左右腿交替快速向胸前提膝',
                '保持呼吸节奏',
              ],
              mistakes: [
                '臀部抬高，变成折叠姿势',
                '塌腰导致腰部受力',
                '速度过快导致动作潦草',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  计划 2：纯有氧燃脂（有氧，4周，每周4次）
  // ═══════════════════════════════════════════════════════
  static TrainingPlan _pureCardio() {
    const planId = 'plan_pure_cardio';

    return const TrainingPlan(
      id: planId,
      name: '4周有氧燃脂',
      description: '全程有氧，适合体重基数大或刚恢复运动的人。对关节压力小，燃脂效率高',
      goal: TrainingGoal.loseWeight,
      level: TrainingLevel.beginner,
      category: TrainingCategory.aerobic,
      durationWeeks: 4,
      workoutsPerWeek: 4,
      days: [
        // ── 第 1 天：匀速有氧 ──
        TrainingDay(
          id: 'day_pc_1',
          planId: planId,
          dayNumber: 1,
          name: '匀速慢跑',
          category: TrainingCategory.aerobic,
          estimatedMinutes: 35,
          exercises: [
            Exercise(
              id: 'ex_pc_1_1',
              name: '动态热身',
              category: TrainingCategory.aerobic,
              sets: 1,
              reps: 300,
              isTimeBased: true,
              restSeconds: 0,
              muscleGroup: '全身',
              tips: '5分钟，活动踝、膝、髋关节',
            ),
            Exercise(
              id: 'ex_pc_1_2',
              name: '匀速慢跑',
              category: TrainingCategory.aerobic,
              sets: 1,
              reps: 1800,
              isTimeBased: true,
              restSeconds: 0,
              muscleGroup: '心肺',
              tips: '30分钟，配速不用快，能坚持下来最重要',
            ),
          ],
        ),

        // ── 第 2 天：跳绳间歇 ──
        TrainingDay(
          id: 'day_pc_2',
          planId: planId,
          dayNumber: 2,
          name: '跳绳间歇',
          category: TrainingCategory.aerobic,
          estimatedMinutes: 25,
          exercises: [
            Exercise(
              id: 'ex_pc_2_1',
              name: '跳绳',
              category: TrainingCategory.aerobic,
              sets: 6,
              reps: 120,
              isTimeBased: true,
              restSeconds: 60,
              muscleGroup: '全身',
              tips: '每组2分钟，膝盖微屈减少冲击',
            ),
          ],
        ),

        // ── 第 3 天：骑行 ──
        TrainingDay(
          id: 'day_pc_3',
          planId: planId,
          dayNumber: 3,
          name: '骑行耐力',
          category: TrainingCategory.aerobic,
          estimatedMinutes: 45,
          exercises: [
            Exercise(
              id: 'ex_pc_3_1',
              name: '动感单车或户外骑行',
              category: TrainingCategory.aerobic,
              sets: 1,
              reps: 2400,
              isTimeBased: true,
              restSeconds: 0,
              muscleGroup: '腿部+心肺',
              tips: '40分钟中等强度，对膝关节友好',
            ),
          ],
        ),

        // ── 第 4 天：有氧操 ──
        TrainingDay(
          id: 'day_pc_4',
          planId: planId,
          dayNumber: 4,
          name: '有氧操',
          category: TrainingCategory.aerobic,
          estimatedMinutes: 30,
          exercises: [
            Exercise(
              id: 'ex_pc_4_1',
              name: '开合跳',
              category: TrainingCategory.aerobic,
              sets: 4,
              reps: 45,
              isTimeBased: true,
              restSeconds: 30,
              muscleGroup: '全身',
              tips: '保持节奏，呼吸均匀',
            ),
            Exercise(
              id: 'ex_pc_4_2',
              name: '高抬腿',
              category: TrainingCategory.aerobic,
              sets: 4,
              reps: 30,
              isTimeBased: true,
              restSeconds: 30,
              muscleGroup: '腿部',
              tips: '核心收紧，大腿抬平',
            ),
            Exercise(
              id: 'ex_pc_4_3',
              name: '波比跳（简化版）',
              category: TrainingCategory.mixed,
              sets: 3,
              reps: 10,
              restSeconds: 60,
              muscleGroup: '全身',
              tips: '新手可以去掉跳跃，改成站起',
              steps: [
                '站立后下蹲，双手撑地',
                '双腿向后跳成俯撑姿势',
                '收腿回到深蹲位',
                '站起（进阶版加一个跳跃）',
              ],
              mistakes: [
                '撑地时塌腰',
                '收腿不到位导致起身困难',
                '落地过重，膝踝冲击大',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  计划 3：增肌（无氧，4周，每周4次）
  // ═══════════════════════════════════════════════════════
  static TrainingPlan _intermediateMuscleGain() {
    const planId = 'plan_intermediate_muscle';

    return const TrainingPlan(
      id: planId,
      name: '4周增肌计划',
      description: '经典推拉腿分化，需要健身房器械。想增加肌肉量和力量就练这个',
      goal: TrainingGoal.gainMuscle,
      level: TrainingLevel.intermediate,
      category: TrainingCategory.anaerobic,
      durationWeeks: 4,
      workoutsPerWeek: 4,
      days: [
        // ── 第 1 天：胸 + 三头 ──
        TrainingDay(
          id: 'day_mg_1',
          planId: planId,
          dayNumber: 1,
          name: '胸肌三头',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 50,
          exercises: [
            Exercise(
              id: 'ex_mg_1_1',
              name: '杠铃卧推',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 10,
              restSeconds: 90,
              muscleGroup: '胸肌',
              equipment: '杠铃',
              targetWeightKg: 50,
              tips: '下放到胸口轻触，推起时手臂不要完全锁死',
              steps: [
                '躺平后肩胛骨后收下沉，在背部挤出一个小拱形',
                '双手握距比肩略宽，手腕保持中立不要后折',
                '杠铃沿弧线下放到乳线位置，大臂与身体约 45 度',
                '脚掌踩实发力，推起时胸肌主动收缩',
              ],
              mistakes: [
                '肩膀前耸离开凳面，容易造成肩关节撞击',
                '杠铃直上直下压到脖子，危险且练不到胸',
                '手肘完全打直锁死，关节承压且失去张力',
              ],
            ),
            Exercise(
              id: 'ex_mg_1_2',
              name: '上斜哑铃推举',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 12,
              restSeconds: 75,
              muscleGroup: '胸肌上部',
              equipment: '哑铃',
              targetWeightKg: 16,
              tips: '板凳调到30-45度，角度太大会变成练肩',
              steps: [
                '板凳调到 30-45 度，肩胛后收',
                '哑铃置于胸部两侧',
                '沿弧线向上推起，顶点哑铃接近',
                '控制下放到胸部有拉伸感',
              ],
              mistakes: [
                '角度调太高，变成练肩',
                '下放过深，肩关节压力大',
                '两只哑铃互相碰撞借力',
              ],
            ),
            Exercise(
              id: 'ex_mg_1_3',
              name: '绳索夹胸',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 15,
              restSeconds: 60,
              muscleGroup: '胸肌',
              equipment: '龙门架',
              targetWeightKg: 15,
              tips: '收到中间稍停顿，感受胸肌中缝',
              steps: [
                '站在龙门架中间，双手各握一侧',
                '上身微微前倾，肘部微屈固定',
                '双手沿弧线向身体中线收',
                '顶峰挤压胸肌 1 秒',
              ],
              mistakes: [
                '靠手臂弯曲拉动，变成弯举',
                '上身摆动借力',
                '幅度不足，两手没有靠近',
              ],
            ),
            Exercise(
              id: 'ex_mg_1_4',
              name: '绳索下压',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '三头肌',
              equipment: '龙门架',
              targetWeightKg: 20,
              tips: '大臂夹紧身体固定，只动小臂',
              steps: [
                '面对龙门架，双手握住绳索',
                '大臂夹紧体侧，上身微微前倾',
                '只动小臂向下压到完全伸直',
                '顶峰收缩三头后控制还原',
              ],
              mistakes: [
                '大臂前后摆动，胸背代偿',
                '上身起伏借体重下压',
                '还原时手肘超过 90 度，张力丢失',
              ],
            ),
          ],
        ),

        // ── 第 2 天：背 + 二头 ──
        TrainingDay(
          id: 'day_mg_2',
          planId: planId,
          dayNumber: 2,
          name: '背部二头',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 50,
          exercises: [
            Exercise(
              id: 'ex_mg_2_1',
              name: '引体向上',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: -1,
              restSeconds: 90,
              muscleGroup: '背阔肌',
              equipment: '单杠',
              tips: '做到力竭，做不动可以用弹力带辅助或改高位下拉',
              steps: [
                '正握单杠，握距略宽于肩',
                '肩胛骨先下沉后收，启动背阔肌',
                '拉到下巴过杠或上胸触杠',
                '控制 2 秒缓慢下放，不要自由落体',
              ],
              mistakes: [
                '只用手臂发力，背部几乎不参与',
                '身体摇摆借惯性，有效刺激大幅下降',
                '下放时完全放松，肩关节被动受力',
              ],
            ),
            Exercise(
              id: 'ex_mg_2_2',
              name: '杠铃划船',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 10,
              restSeconds: 75,
              muscleGroup: '背部',
              equipment: '杠铃',
              targetWeightKg: 40,
              tips: '上半身前倾45度，腰背全程挺直，拉到肚脐',
              steps: [
                '双脚与肩同宽，屈髋前倾约 45 度',
                '腰背全程挺直，核心收紧',
                '肘部贴近身体，拉向肚脐方向',
                '顶峰挤压背部 1 秒再缓慢下放',
              ],
              mistakes: [
                '弓背发力，腰椎承受剪切力',
                '靠上半身起伏甩起重量',
                '拉到胸口位置，变成练后束',
              ],
            ),
            Exercise(
              id: 'ex_mg_2_3',
              name: '单臂哑铃划船',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '背部',
              equipment: '哑铃',
              targetWeightKg: 18,
              tips: '左右各做，手肘贴着身体往后拉',
              steps: [
                '一手一膝撑凳，另一手持哑铃下垂',
                '腰背挺直，与地面接近平行',
                '肘部贴身向后上方拉到胸侧',
                '背部挤压后控制下放',
              ],
              mistakes: [
                '身体扭转借力',
                '只用手臂拉，背部不收缩',
                '弓背导致腰部受力',
              ],
            ),
            Exercise(
              id: 'ex_mg_2_4',
              name: '杠铃弯举',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 10,
              restSeconds: 60,
              muscleGroup: '二头肌',
              equipment: '杠铃',
              targetWeightKg: 25,
              tips: '慢放快拉，别用腰部借力甩起来',
              steps: [
                '双手正握杠铃，与肩同宽',
                '大臂夹紧体侧保持固定',
                '屈肘向上弯举到顶峰收缩',
                '控制 2 秒缓慢下放',
              ],
              mistakes: [
                '用腰部摆动甩起重量',
                '大臂前后晃动，前三角代偿',
                '下放过快失去离心刺激',
              ],
            ),
          ],
        ),

        // ── 第 3 天：肩 ──
        TrainingDay(
          id: 'day_mg_3',
          planId: planId,
          dayNumber: 3,
          name: '肩部力量',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 45,
          exercises: [
            Exercise(
              id: 'ex_mg_3_1',
              name: '坐姿杠铃推举',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 10,
              restSeconds: 90,
              muscleGroup: '肩部前束',
              equipment: '杠铃',
              targetWeightKg: 30,
              tips: '核心收紧，别用腰代偿往后倒',
              steps: [
                '坐稳靠紧椅背，核心收紧',
                '杠铃置于上胸，握距略宽于肩',
                '垂直向上推起，到接近打直时停',
                '控制下放到下巴高度',
              ],
              mistakes: [
                '过度后仰把动作变成上斜卧推',
                '下放过低造成肩关节过度外旋',
                '耸肩发力，斜方肌代偿',
              ],
            ),
            Exercise(
              id: 'ex_mg_3_2',
              name: '哑铃侧平举',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 15,
              restSeconds: 60,
              muscleGroup: '肩部中束',
              equipment: '哑铃',
              targetWeightKg: 8,
              tips: '抬到肩膀高度就够，重量宁小勿大',
              steps: [
                '双手持哑铃自然下垂于体侧',
                '肘部微屈并保持固定角度',
                '以肩为轴向两侧抬起到肩高',
                '控制 2 秒缓慢放下',
              ],
              mistakes: [
                '抬过肩膀高度，斜方肌接管发力',
                '靠身体晃动甩起重量',
                '重量过大导致动作变形',
              ],
            ),
            Exercise(
              id: 'ex_mg_3_3',
              name: '俯身飞鸟',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 15,
              restSeconds: 60,
              muscleGroup: '肩部后束',
              equipment: '哑铃',
              targetWeightKg: 8,
              tips: '后束是大多数人的弱项，重量轻一点做标准',
              steps: [
                '屈髋前倾，上身接近与地面平行',
                '手臂自然下垂，肘部微屈',
                '向两侧后方张开到与肩平齐',
                '感受肩后束收缩后缓慢还原',
              ],
              mistakes: [
                '用腰部起伏带动手臂',
                '重量太大变成俯身划船',
                '手臂完全伸直锁死肘关节',
              ],
            ),
          ],
        ),

        // ── 第 4 天：腿 ──
        TrainingDay(
          id: 'day_mg_4',
          planId: planId,
          dayNumber: 4,
          name: '腿部力量',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 55,
          exercises: [
            Exercise(
              id: 'ex_mg_4_1',
              name: '杠铃深蹲',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 10,
              restSeconds: 120,
              muscleGroup: '股四头肌',
              equipment: '杠铃',
              targetWeightKg: 60,
              tips: '力量训练之王。新手务必先练好自重深蹲再上重量',
              steps: [
                '杠铃放在斜方肌上沿，不要压到颈椎',
                '双脚略宽于肩，脚尖微微外展',
                '先屈髋向后坐，再屈膝下蹲，全程挺胸',
                '蹲到大腿与地面平行，脚掌蹬地起身',
              ],
              mistakes: [
                '膝盖内扣，最常见也最伤膝的错误',
                '起身时弓背塌腰，腰椎受伤风险高',
                '脚跟离地，重心前移导致膝盖压力骤增',
              ],
            ),
            Exercise(
              id: 'ex_mg_4_2',
              name: '腿举',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 12,
              restSeconds: 90,
              muscleGroup: '股四头肌',
              equipment: '腿举机',
              targetWeightKg: 80,
              tips: '下放到膝盖约90度，膝盖不要完全锁死',
              steps: [
                '坐稳靠紧背垫，双脚踩在踏板上',
                '双脚与肩同宽，脚尖略外展',
                '屈膝下放到约 90 度',
                '蹬起时膝盖不要完全锁死',
              ],
              mistakes: [
                '膝盖完全打直锁死，关节承压',
                '下放过深导致臀部离开坐垫、腰椎受力',
                '膝盖内扣',
              ],
            ),
            Exercise(
              id: 'ex_mg_4_3',
              name: '腿弯举',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 15,
              restSeconds: 60,
              muscleGroup: '股二头肌',
              equipment: '腿弯举机',
              targetWeightKg: 35,
              tips: '控制离心下放，别让配重片砸回去',
              steps: [
                '俯卧或坐姿调好腿垫位置',
                '腿垫卡在脚踝上方',
                '屈膝向上收到最大幅度',
                '控制离心缓慢还原',
              ],
              mistakes: [
                '靠臀部抬起借力',
                '还原时让配重片砸回去',
                '幅度不足',
              ],
            ),
            Exercise(
              id: 'ex_mg_4_4',
              name: '站姿提踵',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 20,
              restSeconds: 45,
              muscleGroup: '小腿',
              tips: '顶峰停1秒，全幅度做',
              steps: [
                '前脚掌踩稳，脚跟悬空',
                '身体直立，核心收紧',
                '脚跟尽量抬高，顶峰停 1 秒',
                '缓慢下放到小腿有拉伸感',
              ],
              mistakes: [
                '靠膝盖弯曲弹跳借力',
                '幅度太小',
                '速度过快没有顶峰收缩',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  计划 4：体能维持（混合，4周，每周3次）
  // ═══════════════════════════════════════════════════════
  static TrainingPlan _keepFit() {
    const planId = 'plan_keep_fit';

    return const TrainingPlan(
      id: planId,
      name: '体能维持计划',
      description: '力量和有氧均衡搭配，适合已有健身习惯、想保持当前状态的人',
      goal: TrainingGoal.keepFit,
      level: TrainingLevel.intermediate,
      category: TrainingCategory.mixed,
      durationWeeks: 4,
      workoutsPerWeek: 3,
      days: [
        // ── 第 1 天：上肢推（无氧）──
        TrainingDay(
          id: 'day_kf_1',
          planId: planId,
          dayNumber: 1,
          name: '上肢推',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 40,
          exercises: [
            Exercise(
              id: 'ex_kf_1_1',
              name: '标准俯卧撑',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 15,
              restSeconds: 60,
              muscleGroup: '胸肌',
              tips: '身体成一条直线，下放到胸口离地一拳',
              steps: [
                '双手撑地略宽于肩，身体成一条直线',
                '核心和臀部收紧，不要塌腰或撅臀',
                '下放到胸口离地约一拳',
                '掌跟推地起身，胸肌主动收缩',
              ],
              mistakes: [
                '塌腰导致腰部代偿和酸痛',
                '只下放一半，幅度不足',
                '手肘向外张成 90 度，肩关节压力大',
              ],
            ),
            Exercise(
              id: 'ex_kf_1_2',
              name: '哑铃推举',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '肩部',
              equipment: '哑铃',
              targetWeightKg: 14,
              tips: '维持期用平时80%的重量就够',
              steps: [
                '坐姿或站姿，核心收紧',
                '哑铃置于肩部两侧，掌心朝前',
                '垂直向上推起到接近打直',
                '控制下放到耳朵高度',
              ],
              mistakes: [
                '过度后仰变成上斜卧推',
                '耸肩发力',
                '下放过低造成肩关节不适',
              ],
            ),
            Exercise(
              id: 'ex_kf_1_3',
              name: '双杠臂屈伸',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '三头肌',
              equipment: '双杠',
              tips: '身体直立练三头，前倾练胸',
              steps: [
                '双手撑住双杠，身体悬空',
                '身体直立练三头，前倾练胸',
                '屈肘下放到大臂与地面平行',
                '推起到接近打直',
              ],
              mistakes: [
                '下放过深，肩关节被动拉伸',
                '身体晃动借惯性',
                '肩膀耸起没有下沉',
              ],
            ),
          ],
        ),

        // ── 第 2 天：上肢拉（无氧）──
        TrainingDay(
          id: 'day_kf_2',
          planId: planId,
          dayNumber: 2,
          name: '上肢拉',
          category: TrainingCategory.anaerobic,
          estimatedMinutes: 40,
          exercises: [
            Exercise(
              id: 'ex_kf_2_1',
              name: '高位下拉',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '背阔肌',
              equipment: '下拉机',
              targetWeightKg: 40,
              tips: '拉到锁骨位置，肩胛骨下沉后收',
              steps: [
                '坐稳调好腿垫，正握略宽于肩',
                '肩胛骨先下沉后收',
                '拉到锁骨或上胸位置',
                '控制 2 秒缓慢还原',
              ],
              mistakes: [
                '后仰太多变成坐姿划船',
                '只靠手臂拉，背部不参与',
                '还原时放任重量快速弹回',
              ],
            ),
            Exercise(
              id: 'ex_kf_2_2',
              name: '坐姿划船',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 60,
              muscleGroup: '背部中段',
              equipment: '划船机',
              targetWeightKg: 40,
              tips: '拉到腹部，别靠后仰借力',
              steps: [
                '坐稳蹬住踏板，膝盖保持微屈',
                '腰背挺直，核心收紧',
                '肘部贴身拉向腹部',
                '背部挤压后控制还原',
              ],
              mistakes: [
                '靠上身前后摆动借力',
                '弓背拉重量',
                '肘部外张，变成练后束',
              ],
            ),
            Exercise(
              id: 'ex_kf_2_3',
              name: '哑铃弯举',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 12,
              restSeconds: 45,
              muscleGroup: '二头肌',
              equipment: '哑铃',
              targetWeightKg: 12,
              tips: '交替或同时都可以',
              steps: [
                '双手持哑铃自然下垂',
                '大臂固定在体侧',
                '交替或同时弯举，顶点可外旋手腕',
                '缓慢下放到完全伸展',
              ],
              mistakes: [
                '身体后仰借力',
                '大臂抬起，肩部参与',
                '只做半程幅度',
              ],
            ),
          ],
        ),

        // ── 第 3 天：下肢 + 有氧（混合）──
        TrainingDay(
          id: 'day_kf_3',
          planId: planId,
          dayNumber: 3,
          name: '下肢有氧',
          category: TrainingCategory.mixed,
          estimatedMinutes: 45,
          exercises: [
            Exercise(
              id: 'ex_kf_3_1',
              name: '深蹲',
              category: TrainingCategory.anaerobic,
              sets: 4,
              reps: 12,
              restSeconds: 75,
              muscleGroup: '腿部',
              tips: '自重或负重都行，维持期不用追求大重量',
              steps: [
                '双脚与肩同宽，脚尖略外展',
                '双手前伸或抱于胸前保持平衡',
                '屈髋屈膝下蹲，挺胸收紧核心',
                '蹲到大腿与地面平行后蹬地起身',
              ],
              mistakes: [
                '膝盖内扣',
                '脚跟离地重心前倾',
                '下蹲幅度不足，刺激有限',
              ],
            ),
            Exercise(
              id: 'ex_kf_3_2',
              name: '罗马尼亚硬拉',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 10,
              restSeconds: 90,
              muscleGroup: '臀腿后侧',
              equipment: '杠铃',
              targetWeightKg: 40,
              tips: '腰背全程挺直，臀部向后推，感受大腿后侧拉伸',
              steps: [
                '双脚与髋同宽，膝盖保持微屈不变',
                '臀部向后推送，杠铃沿大腿前侧下滑',
                '下放到大腿后侧有明显拉伸感即停',
                '收紧臀部带动身体还原直立',
              ],
              mistakes: [
                '弯腰去捡杠铃而不是屈髋，腰部代偿',
                '膝盖越蹲越弯，动作变成普通硬拉',
                '杠铃离开身体太远，腰椎杠杆压力翻倍',
              ],
            ),
            Exercise(
              id: 'ex_kf_3_3',
              name: '卷腹',
              category: TrainingCategory.anaerobic,
              sets: 3,
              reps: 20,
              restSeconds: 45,
              muscleGroup: '腹肌',
              tips: '慢起慢放，用腹部发力别拽脖子',
              steps: [
                '仰卧屈膝，双手轻放耳侧或胸前',
                '下巴微收，不要用手拉脖子',
                '腹部发力把上背卷离地面',
                '缓慢还原，腹部保持张力',
              ],
              mistakes: [
                '双手抱头硬拉脖子，颈椎受力',
                '靠惯性快速起落，腹部几乎不发力',
                '完全躺平放松，张力中断',
              ],
            ),
            Exercise(
              id: 'ex_kf_3_4',
              name: '慢跑收尾',
              category: TrainingCategory.aerobic,
              sets: 1,
              reps: 900,
              isTimeBased: true,
              restSeconds: 0,
              muscleGroup: '心肺',
              tips: '15分钟轻松跑，帮助恢复也维持心肺',
            ),
          ],
        ),
      ],
    );
  }
}
