extends Node

## AI 日志系统 - 分级中文日志打印
## 全局自动加载单例

# ===== 日志开关配置 =====
const SHOW_NET: bool = true    # 网络底层连接与原始 JSON 收发
const SHOW_EVENT: bool = true  # 状态发送与游戏暂停事件
const SHOW_ACTION: bool = true # AI 动作解析与执行结果
const SHOW_ERROR: bool = true  # 动作执行拦截与报错信息

# ===== 颜色配置 =====
const COLOR_NET: String = "[color=#3498db]"    # 蓝色 - 网络
const COLOR_EVENT: String = "[color=#2ecc71]"  # 绿色 - 事件
const COLOR_ACTION: String = "[color=#f39c12]" # 橙色 - 动作
const COLOR_ERROR: String = "[color=#e74c3c]"  # 红色 - 错误
const COLOR_RESET: String = "[/color]"

# ===== 日志级别 =====
enum LogLevel { NET, EVENT, ACTION, ERROR }

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[AILogger] AI 日志系统已初始化")

## 网络日志 - 连接与 JSON 收发
func net(message: String):
	if SHOW_NET:
		print_rich("%s[网络] %s%s" % [COLOR_NET, message, COLOR_RESET])

## 事件日志 - 状态发送与游戏暂停
func event(message: String):
	if SHOW_EVENT:
		print_rich("%s[事件] %s%s" % [COLOR_EVENT, message, COLOR_RESET])

## 动作日志 - AI 动作解析与执行
func action(message: String):
	if SHOW_ACTION:
		print_rich("%s[动作] %s%s" % [COLOR_ACTION, message, COLOR_RESET])

## 错误日志 - 动作执行拦截与报错
func error(message: String):
	if SHOW_ERROR:
		print_rich("%s[错误] %s%s" % [COLOR_ERROR, message, COLOR_RESET])

## 原始 JSON 日志（网络层）
func net_json(direction: String, json_data: Variant):
	if SHOW_NET:
		var json_str = JSON.stringify(json_data)
		if json_str.length() > 200:
			json_str = json_str.substr(0, 200) + "..."
		print_rich("%s[网络][%s] %s%s" % [COLOR_NET, direction, json_str, COLOR_RESET])

## 连接状态日志
func net_connection(status: String, details: String = ""):
	if SHOW_NET:
		var msg = "[连接] " + status
		if details != "":
			msg += " - " + details
		print_rich("%s%s%s" % [COLOR_NET, msg, COLOR_RESET])
