# AI Player State

## [Inbox - 待办]

1. `[P0]` 蝙蝠图腾新单位验证 - 石像鬼 (Gargoyle)
   - 来源：QA Tester
   - 测试任务：`docs/qa_tasks/task_gargoyle_001.md`
   - 验证点：
     - 核心 HP<30% 时进入石像形态
     - 石像形态下停止主动攻击
     - 反弹 20% 伤害给攻击者
     - 核心 HP>60% 时恢复常态
   - 测试脚本：`ai_client/gargoyle_test.py`

2. `[P0]` 蝙蝠图腾新单位验证 - 影蝠 (ShadowBat)
   - 来源：QA Tester
   - 测试任务：`docs/qa_tasks/task_shadow_bat_001.md`
   - 验证点：
     - 每 6 秒瞬移到最远敌人身边
     - 落点周围敌人获得 1 层流血
     - 瞬移后返回原位
     - 冷却时间 6 秒
   - 测试脚本：`ai_client/shadow_bat_test.py`

3. `[P1]` 全单位回归测试
   - 运行现有测试脚本验证已实现单位
   - 确保新代码未引入回归问题

## [Archive - 历史归档]

(无)

## [Archive - 历史归档]

(无)
