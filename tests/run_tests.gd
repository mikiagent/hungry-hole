extends SceneTree
## Headless test runner: godot --headless --path godot --script res://tests/run_tests.gd
var failures := 0
var passes := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script = load("res://tests/" + f)
		var inst = script.new()
		inst.runner = self
		for m in inst.get_method_list():
			if m.name.begins_with("test_"):
				var before := failures
				inst.call(m.name)
				print("  %s %s.%s" % ["FAIL" if failures > before else "ok  ", f, m.name])
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)

func check(cond: bool, msg: String) -> void:
	if cond: passes += 1
	else:
		failures += 1
		printerr("    ASSERT FAILED: " + msg)

func approx(a: float, b: float, eps: float, msg: String) -> void:
	check(absf(a - b) <= eps, "%s (got %s, want %s)" % [msg, a, b])
