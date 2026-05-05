extends SceneTree

func _init() -> void:
	var path := "C:/Users/spaul/Documents/GitHub/OtherGodsinGodot/hello_probe.log"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_line("hello")
		file.flush()
		file.close()
	print("hello probe")
	quit(0)
