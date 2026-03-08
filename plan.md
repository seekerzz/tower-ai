# 日志系统重构计划 (AI Client 日志系统)

## 背景分析
当前的日志系统主要由 `src/Autoload/AILogger.gd` 和 `src/Autoload/AIManager.gd` 构成。存在以下问题：
1. **强耦合**: `AILogger` 直接调用 `AIManager.broadcast_text()` 广播日志，导致两个模块之间形成了强依赖关系。
2. **逻辑重复**: 许多机制日志方法 (如 `mechanic_*`) 和事件日志方法 (`enemy_spawned`, `boss_skill` 等) 内部都有 `if AIManager and AIManager.has_method("broadcast_text")` 的判断逻辑。
3. **扩展性差**: 如果后续有新的系统需要监听日志事件，目前的硬编码模式很难优雅地支持。

## 重构目标
将日志的**记录(Logging)**和**广播(Broadcasting)**分离，采用信号(Signals)进行解耦。

## 实施计划

### 1. 重构 AILogger.gd
* **添加信号**: 在 `AILogger.gd` 顶部声明一个新的信号，例如 `signal log_broadcasted(message_text)`。
* **统一广播接口**: 新建一个内部方法 `_broadcast(msg: String)`，在该方法中触发 `log_broadcasted` 信号，并移除所有硬编码的 `if AIManager...` 检查。
* **替换所有直接调用**: 将文件中所有的 `AIManager.broadcast_text(msg)` 替换为 `_broadcast(msg)`。

### 2. 重构 AIManager.gd
* **监听信号**: 在 `AIManager.gd` 的 `_ready()` 或初始化流程中，连接 `AILogger.log_broadcasted` 信号到自身的 `broadcast_text` 方法。
* **清理无用逻辑**: 如果有相关的硬编码回调或不需要的直接引用，进行清理。

### 3. 测试与验证
* 运行日志 API 一致性测试 (`python3 ai_client/test_log_api.py`)。
* 确保 HTTP 服务端能正常接收和转发日志。
* 检查控制台输出和 WebSocket 推送是否正常，不丢失任何关键游戏事件（如波次开始、敌人生成、Boss 出现等）。

### 4. 提交预检 (Pre-commit)
* 运行代码检查和测试脚本，确保没有语法错误和回归问题。

### 5. 提交代码 (Submit)
* 提交本次重构代码，编写清晰的 Git 提交信息。
