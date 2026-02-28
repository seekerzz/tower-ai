extends Node

## 测试崩溃场景 - 在 _ready 中主动抛出 GDScript 错误

func _ready():
	print("TestCrash: 即将触发崩溃...")

	# 故意访问 null 节点，触发 SCRIPT ERROR
	var nonexistent_node = $"NonexistentNode"
	# 这行会导致: SCRIPT ERROR: Invalid get index 'name' (on base: 'Nil').
	var name = nonexistent_node.name
