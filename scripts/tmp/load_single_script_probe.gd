extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("load_single_script_probe: missing script path argument")
		quit(1)
		return

	var path := args[0]
	print("load_single_script_probe: loading %s" % path)
	var script := load(path)
	if script == null:
		push_error("load_single_script_probe: failed to load %s" % path)
		quit(1)
		return

	print("load_single_script_probe: PASS %s" % path)
	quit()
