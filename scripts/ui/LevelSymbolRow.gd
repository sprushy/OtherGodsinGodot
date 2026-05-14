class_name LevelSymbolRow
extends Control

const LEVEL_SYMBOL_TEXTURE := preload("res://images/ui/LevelSymbol.jpg")

var level_count: int = 0
var symbol_size: float = 12.0
var symbol_color: Color = Color.WHITE

func setup(count: int, size_px: float, color: Color = Color.WHITE) -> void:
	level_count = maxi(0, count)
	symbol_size = maxf(1.0, size_px)
	symbol_color = color
	custom_minimum_size = Vector2(symbol_size * float(level_count), symbol_size)
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	for i in range(level_count):
		draw_texture_rect(
			LEVEL_SYMBOL_TEXTURE,
			Rect2(Vector2(symbol_size * float(i), 0.0), Vector2(symbol_size, symbol_size)),
			false,
			symbol_color
		)
