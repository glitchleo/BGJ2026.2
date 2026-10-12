extends CanvasLayer

@export_file("*.tscn") var gameplay_scene_path := "res://scenes/main/main.tscn"
@export_range(0.0, 5.0, 0.1) var hover_wobble_degrees := 2.0
@export_range(0.0, 20.0, 0.1) var hover_wobble_speed := 6.0

@onready var restart_button: TextureButton = $Root/RestartButton
@onready var leave_button: TextureButton = $Root/LeaveButton

var _menu_buttons: Array[TextureButton] = []
var _hovered_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	get_tree().paused = false

	if MusicManager.has_method(&"play_menu_music"):
		MusicManager.call(&"play_menu_music")

	_menu_buttons = [
		restart_button,
		leave_button,
	]

	for button in _menu_buttons:
		_wire_hover_button(button)

	restart_button.pressed.connect(Callable(self, "_on_restart_pressed"))
	leave_button.pressed.connect(Callable(self, "_on_leave_pressed"))
	call_deferred(&"_refresh_button_pivots")


func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var wobble := sin(time * hover_wobble_speed) * hover_wobble_degrees
	var reset_weight := clampf(delta * maxf(hover_wobble_speed, 1.0) * 4.0, 0.0, 1.0)

	for button in _menu_buttons:
		if not is_instance_valid(button):
			continue

		if _hovered_buttons.has(button):
			button.rotation = deg_to_rad(wobble)
		else:
			button.rotation = lerp_angle(button.rotation, 0.0, reset_weight)


func _on_restart_pressed() -> void:
	get_tree().paused = false

	var result := get_tree().change_scene_to_file(gameplay_scene_path)
	if result != OK:
		push_error("EndMenu: Could not load gameplay scene %s" % gameplay_scene_path)


func _on_leave_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _wire_hover_button(button: TextureButton) -> void:
	if button == null:
		return

	button.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind(button))
	button.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind(button))
	button.resized.connect(Callable(self, "_refresh_button_pivot").bind(button))


func _refresh_button_pivots() -> void:
	for button in _menu_buttons:
		_refresh_button_pivot(button)


func _refresh_button_pivot(button: TextureButton) -> void:
	if button == null:
		return

	button.pivot_offset = button.size * 0.5


func _on_button_mouse_entered(button: TextureButton) -> void:
	_hovered_buttons[button] = true


func _on_button_mouse_exited(button: TextureButton) -> void:
	_hovered_buttons.erase(button)
