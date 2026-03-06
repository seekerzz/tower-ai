extends Node

## AI 日志系统 - 极简解耦重构版
## 全局自动加载单例

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[AILogger] AI 日志系统已初始化")

## 泛型日志广播接口
func broadcast_log(tag: String, message: String):
	# 在控制台打印最基础的日志
	print("[%s] %s" % [tag, message])

	# 发送纯文本到 AI 客户端
	if AIManager and AIManager.has_method("broadcast_text"):
		AIManager.broadcast_text("[%s] %s" % [tag, message])
