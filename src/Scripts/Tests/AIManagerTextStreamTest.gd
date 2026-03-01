extends SceneTree

# Duck typing works because we removed the strong type hint from websocket_peer
class MockWebSocketPeer extends RefCounted:
	var last_sent_text: String = ""
	const STATE_OPEN = 1

	func get_ready_state() -> int:
		return STATE_OPEN

	func send_text(text: String) -> int:
		last_sent_text = text
		return OK

	func close():
		pass

	func poll():
		pass

	func get_available_packet_count() -> int:
		return 0

func _init():
	print("=== Starting AIManagerTextStreamTest ===")
	call_deferred("_run_tests")

func _run_tests():
	var ai_manager = self.root.get_node("AIManager")

	if not ai_manager:
		print("❌ FAIL: AIManager autoload not found")
		quit(1)
		return

	var mock_peer = MockWebSocketPeer.new()

	ai_manager.is_client_connected = true
	ai_manager.websocket_peer = mock_peer

	var pass_count = 0
	var total_count = 2

	# Test 1
	ai_manager.broadcast_text("Hello, pure text!")
	if mock_peer.last_sent_text != "Hello, pure text!":
		print("❌ FAIL: broadcast_text did not send pure text. Expected 'Hello, pure text!', got '", mock_peer.last_sent_text, "'")
	else:
		print("✅ PASS: broadcast_text sends pure text")
		pass_count += 1

	# Setup GameManager mock state
	var gm = self.root.get_node("GameManager")

	if gm:
		if gm.session_data:
			gm.session_data.wave = 5
			gm.session_data.gold = 150
			gm.session_data.core_health = 450.0
			gm.session_data.max_core_health = 500.0
			gm.session_data.grid_units = {}
	else:
		print("Warning: GameManager not found!")

	mock_peer.last_sent_text = ""

	# Test 2
	var msg = '{"type": "observe"}'
	ai_manager._handle_client_message(msg)

	var expected_part = "第 5 波，金币 150，核心血量 450.0/500.0"
	if not expected_part in mock_peer.last_sent_text:
		print("❌ FAIL: observe action did not generate correct natural language string. Got: ", mock_peer.last_sent_text)
	else:
		print("✅ PASS: observe action generates correct natural language string")
		pass_count += 1

	print("\n=== AIManagerTextStreamTest Results ===")
	print("Total: %d/%d passed" % [pass_count, total_count])

	quit(0 if pass_count == total_count else 1)
