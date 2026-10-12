extends Control

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/main/main.tscn"
@export_range(0.0, 5.0, 0.1) var hover_wobble_degrees := 2.0
@export_range(0.0, 20.0, 0.1) var hover_wobble_speed := 6.0

@onready var play_button: TextureButton = $ButtonColumn/PlayButton
@onready var quit_button: TextureButton = $ButtonColumn/QuitButton
@onready var settings_button: TextureButton = $SettingsButton
@onready var settings_menu: Control = $SettingsMenu

var _menu_buttons: Array = []
var _hovered_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	if MusicManager.has_method(&"play_menu_music"):
		MusicManager.call(&"play_menu_music")

	if MemoryUI.has_method(&"set_game_ui_visible"):
		MemoryUI.call(&"set_game_ui_visible", false)

	_menu_buttons = [
		play_button,
		quit_button,
		settings_button,
	]

	for button in _menu_buttons:
		_wire_hover_button(button as TextureButton)

	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	if settings_menu.has_signal(&"back_requested"):
		settings_menu.connect(&"back_requested", Callable(self, "_on_settings_back_requested"))

	settings_menu.visible = false
	call_deferred(&"_refresh_button_pivots")


func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var wobble := sin(time * hover_wobble_speed) * hover_wobble_degrees
	var reset_weight := clampf(delta * maxf(hover_wobble_speed, 1.0) * 4.0, 0.0, 1.0)

	for raw_button in _menu_buttons:
		var button := raw_button as TextureButton
		if not is_instance_valid(button):
			continue

		if _hovered_buttons.has(button):
			button.rotation = deg_to_rad(wobble)
		else:
			button.rotation = lerp_angle(button.rotation, 0.0, reset_weight)


func _unhandled_input(event: InputEvent) -> void:
	if not settings_menu.visible:
		return

	if event.is_action_pressed(&"ui_cancel"):
		_hide_settings_menu()
		get_viewport().set_input_as_handled()


func _wire_hover_button(button: TextureButton) -> void:
	if button == null:
		return

	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	button.resized.connect(_refresh_button_pivot.bind(button))


func _refresh_button_pivots() -> void:
	for raw_button in _menu_buttons:
		_refresh_button_pivot(raw_button as TextureButton)


func _refresh_button_pivot(button: TextureButton) -> void:
	if button == null:
		return

	button.pivot_offset = button.size * 0.5


func _on_button_mouse_entered(button: TextureButton) -> void:
	_hovered_buttons[button] = true


func _on_button_mouse_exited(button: TextureButton) -> void:
	_hovered_buttons.erase(button)


func _on_play_pressed() -> void:
	var result := get_tree().change_scene_to_file(gameplay_scene_path)
	if result != OK:
		push_error("MainMenu: Could not load gameplay scene %s" % gameplay_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	if settings_menu.has_method(&"show_menu"):
		settings_menu.call(&"show_menu")
	else:
		settings_menu.visible = true


func _on_settings_back_requested() -> void:
	_hide_settings_menu()


func _hide_settings_menu() -> void:
	if settings_menu.has_method(&"hide_menu"):
		settings_menu.call(&"hide_menu")
	else:
		settings_menu.visible = false
