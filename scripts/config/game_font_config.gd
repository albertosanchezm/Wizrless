extends Resource
class_name GameFontConfig

@export var ui_font: Font
@export var title_font: Font
@export var monospace_font: Font

@export_range(1, 128, 1) var ui_small_size: int = 8
@export_range(1, 128, 1) var ui_medium_size: int = 12
@export_range(1, 128, 1) var ui_large_size: int = 16
@export_range(1, 128, 1) var title_size: int = 20
@export_range(1, 128, 1) var damage_number_size: int = 14


func get_font_or_fallback(font: Font) -> Font:
	return font if font != null else ThemeDB.fallback_font


func get_ui_font() -> Font:
	return get_font_or_fallback(ui_font)


func get_title_font() -> Font:
	return get_font_or_fallback(title_font if title_font != null else ui_font)


func get_monospace_font() -> Font:
	return get_font_or_fallback(monospace_font if monospace_font != null else ui_font)
