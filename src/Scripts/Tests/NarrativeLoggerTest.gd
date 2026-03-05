extends SceneTree

func _init():
	print("=== Starting NarrativeLoggerTest ===")
	call_deferred("_run_tests")

func _run_tests():
	var narrative_logger = null
	if self.root.has_node("NarrativeLogger"):
		narrative_logger = self.root.get_node("NarrativeLogger")

	if not narrative_logger:
		print("❌ FAIL: NarrativeLogger not found")
		quit(1)
		return

	var ai_manager = self.root.get_node("AIManager")

	# We can't easily mock AIManager without changing its autoload status,
	# but we can check if it calls broadcast_text properly.
	# We will dynamically replace broadcast_text with a mock method to intercept calls!

	var intercepted_text = ""

	if ai_manager:
		# Use Godot 4 callable to mock
		var mock_func = func(text: String):
			intercepted_text = text

		# Unfortunately we can't easily patch functions in GDScript dynamically
		# without writing complex overriding nodes.
		# A simpler way: We know NarrativeLogger directly calls AIManager.broadcast_text.
		# Let's mock AIManager's websocket peer to capture the text!

		var MockPeer = load("res://src/Scripts/Tests/AIManagerTextStreamTest.gd").MockWebSocketPeer
		var mock_peer = MockPeer.new()
		ai_manager.is_client_connected = true
		ai_manager.websocket_peer = mock_peer

		# Test NarrativeLogger WaveStarted event manually
		narrative_logger._on_wave_started()

		if "【波次事件】" in mock_peer.last_sent_text:
			print("✅ PASS: NarrativeLogger generates and broadcasts natural language text")
		else:
			print("❌ FAIL: NarrativeLogger did not broadcast valid narrative text. Got: ", mock_peer.last_sent_text)
			quit(1)
			return

		print("\n=== NarrativeLoggerTest Results ===")
		print("Total: 1/1 passed")
		quit(0)
	else:
		print("❌ FAIL: AIManager not found, cannot test NarrativeLogger integration")
		quit(1)

