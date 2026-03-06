extends Node

func _ready():
	print("Running compile test for all unit behaviors in a proper SceneTree...")

	var success_count = 0
	var fail_count = 0

	var dirs_to_check = [
		"res://src/Scripts/Units/"
	]

	while dirs_to_check.size() > 0:
		var current_dir = dirs_to_check.pop_back()
		var dir = DirAccess.open(current_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue

				var full_path = current_dir + file_name
				if dir.current_is_dir():
					dirs_to_check.append(full_path + "/")
				elif file_name.ends_with(".gd"):
					var script = load(full_path)
					if script:
						print("OK: " + full_path)
						success_count += 1
					else:
						print("FAIL: " + full_path)
						fail_count += 1
				file_name = dir.get_next()
		else:
			print("Failed to open directory " + current_dir)

	print("--- Test Complete ---")
	print("Success: ", success_count)
	print("Failed: ", fail_count)

	get_tree().quit()
