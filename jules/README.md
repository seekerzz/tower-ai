# Jules 任务管理脚本

用于与 Google Jules AI 编程助手交互的 API 客户端工具。

---

## 环境准备

设置环境变量：

```bash
export JULES_API_KEY=your_api_key_here
export HTTP_PROXY=your_proxy_here   # 如 http://192.168.1.100:1080
export HTTPS_PROXY=your_proxy_here  # 同上
```

**代理设置说明：**
- Jules API 和 GitHub 操作都需要代理才能正常访问
- 需要在 **当前终端会话** 中设置代理环境变量，或在 `~/.bashrc` 中配置
- 如需从 GitHub 获取远程分支，请确保设置了 `http_proxy` 和 `https_proxy` 后再执行 `git fetch`

获取 API Key: https://jules.google.com/settings#api

---

## 脚本说明

### 1. submit_jules_task.py - 提交 Jules 任务

向 Jules AI 提交编程任务。

**基本用法：**

```bash
python submit_jules_task.py --task-id <TASK_ID> --prompt "<PROMPT内容>"
```

**参数说明：**

| 参数 | 简写 | 必填 | 说明 |
|------|------|------|------|
| `--task-id` | `-t` | 是 | 任务唯一标识，如 feat-auth-login |
| `--prompt` | `-p` | 是 | Prompt 内容（直接文本） |
| `--title` | 无 | 否 | 任务标题，默认为 task-id |
| `--repo` | `-r` | 否 | GitHub 仓库地址，格式: `owner/repo`。如不指定，自动检测当前 git 仓库的远程地址 |

**使用示例：**

```bash
# 功能开发（自动检测当前 git 仓库的 GitHub 地址）
python submit_jules_task.py -t feat-jwt-auth -p "Implement JWT authentication"

# 手动指定 GitHub 仓库地址
python submit_jules_task.py -t feat-jwt-auth -p "Implement JWT authentication" --repo myorg/myrepo

# Bug 修复
python submit_jules_task.py -t bug-login-error -p "Fix login error handling"

# 多行内容（使用 heredoc）
python submit_jules_task.py -t refactor-user-service -p "$(cat <<'EOF'
Refactor user service to use dependency injection:
- Extract interface
- Update tests
- Add documentation
EOF
)"

# 从文件读取内容后传入
python submit_jules_task.py -t docs-api-update -p "$(cat my_prompt.md)"
```

**GitHub 仓库地址说明：**

脚本会自动检测当前目录下 git 仓库的远程地址（`origin`）：
- 支持 HTTPS 格式: `https://github.com/owner/repo.git`
- 支持 SSH 格式: `git@github.com:owner/repo.git`

如果自动检测失败或需要指定其他仓库，请使用 `--repo` 参数手动指定，格式为 `owner/repo`。

**输出信息：**
- Session ID（用于后续查询状态）
- Jules 会话 URL
- 自动更新 `jules/progress.md` 进度文件

---

### 2. check_jules_status.py - 检查 Jules 任务状态

查询或监控已提交任务的执行状态。

**基本用法：**

```bash
# 单次查询状态
python check_jules_status.py --session-id <SESSION_ID>

# 通过 task-id 从进度文件查找并查询
python check_jules_status.py --task-id <TASK_ID>

# 持续监控直到任务完成
python check_jules_status.py --session-id <SESSION_ID> --wait
```

**参数说明：**

| 参数 | 简写 | 必填 | 说明 |
|------|------|------|------|
| `--session-id` | `-s` | 否* | Jules Session ID |
| `--task-id` | `-t` | 否* | 任务ID，如 feat-auth-login |
| `--wait` | `-w` | 否 | 持续监控模式，轮询直到任务完成 |
| `--timeout` | 无 | 否 | 超时时间（秒），默认 3600 |

*注：`--session-id` 和 `--task-id` 至少提供一个

**使用示例：**

```bash
# 使用 Session ID 单次查询
python check_jules_status.py -s 123456789

# 使用 Task ID 查询（自动查找对应 Session）
python check_jules_status.py -t feat-jwt-auth

# 持续监控任务状态（每 30 秒轮询一次）
python check_jules_status.py -s 123456789 -w

# 监控并设置 1 小时超时
python check_jules_status.py -s 123456789 -w --timeout 3600
```

**任务状态：**
- `PENDING` - 等待中
- `RUNNING` - 执行中
- `COMPLETED` - 已完成
- `FAILED` - 失败
- `CANCELLED` - 已取消

**完成时输出：**
- 最终状态
- 生成的 PR URL
- PR 分支信息

---

## 完整工作流程示例

```bash
# 1. 提交任务
python submit_jules_task.py -t feat-dependency-injection -p "Refactor auth module to use DI"

# 输出示例：
# ============================================================
# Submitting task: feat-dependency-injection
# ============================================================
# [OK] Success! Session ID: 987654321
# [OK] URL: https://jules.google.com/session/987654321
# [OK] Progress updated: jules/progress.md

# 2. 监控任务状态（需要设置代理）
export http_proxy=http://192.168.1.100:1080
export https_proxy=http://192.168.1.100:1080
python check_jules_status.py -s 987654321 -w

# 3. 获取远程分支（需要设置代理）
export http_proxy=http://192.168.1.100:1080
export https_proxy=http://192.168.1.100:1080
git fetch origin
git checkout origin/jules-task-feat-dependency-injection

# 输出示例：
# ============================================================
# 监控任务: 987654321
# URL: https://jules.google.com/session/987654321
# ============================================================
# [1] 状态: RUNNING
# [2] 状态: RUNNING
# [3] 状态: COMPLETED
#
# ============================================================
# 任务结束 - 状态: COMPLETED
# ============================================================
#
# PR: https://github.com/seekerzz/tower-html/pull/42
# 分支: jules-task-feat-dependency-injection
```

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `submit_jules_task.py` | 任务提交脚本 |
| `check_jules_status.py` | 状态查询脚本 |
| `progress.md` | 任务进度记录文件（自动更新） |

---

## 注意事项

1. **API Key 安全**：不要在代码中硬编码 API Key，建议通过环境变量传入
2. **代理设置**：
   - 提交 Jules 任务前必须设置 `HTTP_PROXY` 和 `HTTPS_PROXY` 环境变量
   - 从 GitHub 获取远程分支时也需要代理：`git fetch origin` 前确保代理已设置
3. **GitHub 仓库**：脚本会自动检测当前 git 仓库的远程地址，确保在正确的仓库目录下执行，或使用 `--repo` 参数手动指定
4. **超时时间**：长任务建议使用 `--wait` 模式监控
5. **进度文件**：提交任务后会自动更新 `jules/progress.md`，可用于后续查询
6. **Prompt 约束（重要）**：
   - 提交任务时，Prompt 中必须明确禁止 Jules 创建任何 Markdown 文件（如文档、报告、README等）
   - 建议 Prompt 模板： `"实现 XXX 功能。要求：1. ... 2. ... 3. 禁止创建任何 .md 文件或文档"`
