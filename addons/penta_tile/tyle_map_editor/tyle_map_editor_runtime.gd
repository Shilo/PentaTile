extends TyleMapEditor

# Compatibility wrapper for scenes or editor state that still reference the
# original runtime host path. The implementation lives in tyle_map_editor.gd.

@export var start_open: bool = false:
	set(value):
		start_open = value
		showing = value
	get:
		return showing

@export var show_close_button: bool = true:
	set(value):
		show_close_button = value
		if _panel and _panel.has_method("set_close_button_visible"):
			_panel.set_close_button_visible(value)

@export var grid_enabled: bool = true
@export var layer_highlight_enabled: bool = false
@export var grid_color: Color = Color(1.0, 0.5, 0.2, 0.5)
