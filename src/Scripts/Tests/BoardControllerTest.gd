class_name BoardControllerTest
extends Node

var test_results = []

func _ready():
	print("=== BoardController API Test ===")

	# 等待一帧确保所有节点初始化
	await get_tree().process_frame

	# 运行测试
	_test_session_data_exists()
	_test_board_controller_exists()
	_test_buy_unit_api()
	_test_refresh_shop_api()
	_test_move_unit_api()

	# 输出结果
	print("\n=== Test Results ===")
	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("%s: %s" % [status, result.name])
		if not result.passed and result.error:
			print("   Error: %s" % result.error)

	var passed_count = test_results.filter(func(r): return r.passed).size()
	var total_count = test_results.size()
	print("\nTotal: %d/%d passed" % [passed_count, total_count])

func _test_session_data_exists():
	var result = {"name": "SessionData exists", "passed": false, "error": ""}
	if GameManager.session_data:
		result.passed = true
	else:
		result.error = "GameManager.session_data is null"
	test_results.append(result)

func _test_board_controller_exists():
	var result = {"name": "BoardController exists", "passed": false, "error": ""}
	if BoardController:
		result.passed = true
	else:
		result.error = "BoardController is null"
	test_results.append(result)

func _test_buy_unit_api():
	var result = {"name": "buy_unit API exists", "passed": false, "error": ""}
	if BoardController.has_method("buy_unit"):
		result.passed = true
	else:
		result.error = "BoardController.buy_unit method not found"
	test_results.append(result)

func _test_refresh_shop_api():
	var result = {"name": "refresh_shop API exists", "passed": false, "error": ""}
	if BoardController.has_method("refresh_shop"):
		result.passed = true
	else:
		result.error = "BoardController.refresh_shop method not found"
	test_results.append(result)

func _test_move_unit_api():
	var result = {"name": "try_move_unit API exists", "passed": false, "error": ""}
	if BoardController.has_method("try_move_unit"):
		result.passed = true
	else:
		result.error = "BoardController.try_move_unit method not found"
	test_results.append(result)
