extends Control

signal value_changed(value: float)

@export_range(0.0, 1.0, 0.01) var value := 1.0

@onready var track_line: ColorRect = $TrackLine
@onready var handle_line: ColorRect = $HandleLine
@onready var hitbox: Button = $Hitbox

var _dragging := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	hitbox.gui_input.connect(Callable(self, "_on_hitbox_gui_input"))
	resized.connect(Callable(self, "_update_visuals"))
	track_line.resized.connect(Callable(self, "_update_visuals"))
	handle_line.resized.connect(Callable(self, "_update_visuals"))
	_update_visuals()


func set_value(next_value: float, emit_change: bool = true) -> void:
	var clamped_value := clampf(next_value, 0.0, 1.0)
	var changed := not is_equal_approx(value, clamped_value)
	value = clamped_value
	_update_visuals()

	if changed and emit_change:
		value_changed.emit(value)


func _on_hitbox_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		_dragging = mouse_event.pressed
		if mouse_event.pressed:
			_set_value_from_mouse()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_value_from_mouse()
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_dragging = false


func _set_value_from_mouse() -> void:
	var track_left := track_line.position.x
	var track_width := maxf(track_line.size.x, 1.0)
	var local_x := clampf(get_local_mouse_position().x, track_left, track_left + track_width)
	set_value((local_x - track_left) / track_width)


func _update_visuals() -> void:
	if track_line == null or handle_line == null:
		return

	var track_left := track_line.position.x
	var track_width := maxf(track_line.size.x, 1.0)
	var handle_x := track_left + (track_width * clampf(value, 0.0, 1.0))
	handle_line.position.x = handle_x - (handle_line.size.x * 0.5)
	handle_line.position.y = (size.y - handle_line.size.y) * 0.5
