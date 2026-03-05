## 🌟 一、 架构声明与核心理念

本白皮书定义了 Tower-AI 项目的“全自动、零干预、高度自治”的多 AI Agent 协同开发协议。本系统的核心运转依赖以下三大铁律：

1. **绝对的信息茧房（Context Isolation）**：各角色被严格限制在自己的“视界”内。策划不懂代码且无权查看代码；总监不管细节；技术独揽合并。没有任何一个 Agent 拥有全局视角的记忆。
2. **信箱驱动的状态机（Inbox-Driven State Machine）**：抛弃漫长的对话上下文记录。Agent 每次唤醒均视为“失忆”，通过读取自己专属的 `_state.md` 瞬间恢复记忆，并通过向游角色信箱（Inbox）投递路径指针来驱动工作流。
3. **大刀阔斧与并行最大化（Ruthless Refactoring & Max Parallelism）**：一切代码修改优先考虑可读性与极简性，容忍高昂的迁移成本进行重构；开发任务必须基于单一静态切片绝对解耦，以最大化压榨并行吞吐量。

------

## 📂 二、 全局文件系统与隔离图谱

为了完美还原整个系统，请严格在项目根目录下构建以下文件拓扑结构。所有角色仅允许在授权的沙盒路径内读写。

Plaintext

```
tower-ai/
├── docs/
│   ├── roles/                     # [静态定义] Agent 的标准作业程序 (SOP)
│   │   ├── project_director.md    # 项目总监规范
│   │   ├── game_designer.md       # 游戏策划规范
│   │   ├── technical_director.md  # 技术总监规范
│   │   └── ai_player.md           # AI 模拟玩家规范
│   ├── states/                    # [动态流转] 各角色的专属信箱与状态机台账
│   │   ├── project_director_state.md
│   │   ├── game_designer_state.md
│   │   ├── tech_director_state.md
│   │   ├── ai_player_state.md
│   │   ├── qa_tester_state.md
│   │   ├── project_director_state_archive.md  # [归档] 已完成任务历史记录
│   │   ├── game_designer_state_archive.md
│   │   ├── tech_director_state_archive.md
│   │   ├── ai_player_state_archive.md
│   │   └── qa_tester_state_archive.md
│   ├── design_proposals/          # 策划输出的纯文本机制设计案
│   └── player_reports/            # AI Player 跑测生成的结构化体验报告
├── logs/                          # AI Player 吐出的海量黑盒游玩日志
├── src/                           # 核心代码仓 (仅技术总监可见)
├── data/                          # 游戏数值配置表
└── ai_client/                     # 自动化拉起客户端的测试脚本
```

------

## 🤖 三、 团队角色矩阵与 SOP 引用

要实例化对应的数字员工，请在初始化 System Prompt 时，直接加载对应路径的 SOP 文档。

### 1. 👔 项目总监 (Project Director)

- **还原路径**：加载 `docs/roles/project_director.md`
- **核心定义**：全盘流程的守望者。不看代码、不写提案。只负责监控全局进度，且只有在系统触发底层死锁（如引擎彻底崩溃、逻辑互斥）时，才允许向人类老板发起仲裁呼叫。

### 2. 🎨 游戏策划 (Game Designer)

- **还原路径**：加载 `docs/roles/game_designer.md`
- **核心定义**：瞎子摸象式的机制主脑。完全不懂代码，通过盲读 `logs/` 下的流水文本分析机制坑点与爽点。
- **强制执行**：在向技术总监投递提案时，**必须反问并预测该机制未来的扩展方向**，强制要求下游据此设计函数接口。同时，拥有向技术侧直接下发“增加特定遥测日志埋点”的权力。

### 3. 💻 技术总监 (Technical Director)

- **还原路径**：加载 `docs/roles/technical_director.md`
- **核心定义**：独裁的代码架构师。负责合并所有分支、派发任务。
- **强制执行**：审查现有代码库时，**一旦发现代码冗余或混乱，必须一并下达重构指令（可读性最重要，允许极简大改动）**。

### 4. 🎮 AI 模拟玩家 (AI Player)

- **还原路径**：加载 `docs/roles/ai_player.md`
- **核心定义**：无情的自动化黑盒测试机。负责接单、拉起客户端、执行混沌/极限流派跑测，并无死角地吐出所有状态转化的文本日志。

### 5. 🧪 测试工程师 (QA Tester)

- **还原路径**：加载 `docs/roles/qa_tester.md`
- **核心定义**：游戏机制正确性的守护者。通过代码审查、日志分析和针对性测试来验证游戏机制是否与GameDesign.md设计一致。负责标记机制验证状态，构造特定测试场景，并委托AI Player执行验证。

------

## 🚀 四、 核心驱动引擎：信箱唤醒协议 (Wake-up Protocol)

整个团队的运转不需要任何外部调度中心，完全依赖以下标准化“接力循环”：

1. **苏醒 (Wake-up)**：被触发执行的 Agent，第一且唯一的动作是读取自己位于 `docs/states/` 下的专属状态机文档。
2. **消费 (Consume)**：读取 `[Inbox - 待办]` 区域，获取上游塞入的文件路径指针（例如一份报错日志、或者一份新提案）。
3. **执行 (Execute)**：遵循自己角色的 SOP 进行工作（分析日志、写提案、审查并分发开发任务、或者拉起客户端跑测）。
4. **投递 (Dispatch)**：工作完成后，将产出物的绝对路径，**追加写入（Append）**下游角色 `_state.md` 的 `[Inbox]` 区域中。
5. **归档与清理 (Archive & Cleanup)**：将已完成的 Inbox 条目移入 `[Archive]` 区域。为保持状态文件可读性，**强制要求**仅保留最近 **10条** 未完成任务；将已完成的任务条目移动到对应的 `docs/states/[ROLE]_state_archive.md` 归档文件中。
6. **休眠 (Sleep)**：进程自杀释放内存，等待下一次被信箱投递唤醒。

------

## 🛡️ 五、 提交检查机制 (Pre-Commit Checks)

为了确保各角色严格遵守其职责范围，项目实现了提交检查机制。该机制通过 Git 的 `pre-commit` 钩子来实现，会在每次提交前检查提交的文件是否符合角色的权限范围。

### 1. 安装方法

在项目根目录下执行以下命令，将钩子脚本安装到 Git 的 hooks 目录：

```bash
ln -sf ../../hooks/pre-commit .git/hooks/pre-commit
chmod +x hooks/pre-commit scripts/pre_commit_check.py
```

### 2. 工作原理

- 钩子会检查提交的文件是否符合当前角色的权限范围
- 角色信息通过 `ROLE` 环境变量传递（例如：`ROLE=game_designer git commit`）
- 如果没有设置角色信息，钩子会发出警告并允许提交
- 如果提交了不符合角色权限的文件，钩子会阻止提交并显示错误信息

### 3. 角色权限范围

各角色的权限范围已在 `scripts/pre_commit_check.py` 文件中定义，严格遵循 README.md 中描述的职责范围。

### 4. 注意事项

- 钩子脚本仅在本地提交时生效，不会影响远程仓库的提交
- 如果需要绕过检查，可以使用 `--no-verify` 选项（不推荐）
- 钩子脚本依赖 Python 3，请确保已安装 Python 3
