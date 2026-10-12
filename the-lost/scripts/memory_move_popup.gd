extends Control

signal classification_requested(belief: int)

@export_range(0.0, 8.0, 0.1) var hover_wobble_degrees := 2.0
@export_range(0.0, 24.0, 0.1) var hover_wobble_speed := 9.0

@onready var button_row: HBoxContainer = $ButtonRow
@onready var true_button: TextureButton = $ButtonRow/TrueButton
@onready var false_button: TextureButton = $ButtonRow/FalseButton
@onready var uncertain_button: TextureButton = $ButtonRow/UncertainButton

var _hovered_buttons: Dictionary = {}
var _wiggle_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_popup()
	_wire_button(true_button, MemoryManager.Belief.TRUE)
	_wire_button(false_button, MemoryManager.Belief.FALSE)
	_wire_button(uncertain_button, MemoryManager.Belief.UNCERTAIN)


func show_for_belief(current_belief: int) -> void:
	visible = true
	_arrange_buttons(current_belief)
	true_button.visible = current_belief != MemoryManager.Belief.TRUE
	false_button.visible = current_belief != MemoryManager.Belief.FALSE
	uncertain_button.visible = current_belief != MemoryManager.Belief.UNCERTAIN


func hide_popup() -> void:
	visible = false
	for button in _hovered_buttons.keys():
		if button is TextureButton:
			button.rotation = 0.0
	_hovered_buttons.clear()


func _wire_button(button: TextureButton, belief: int) -> void:
	if button == null:
		return

	button.pressed.connect(Callable(self, "_on_classification_pressed").bind(belief))
	button.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind(button))
	button.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind(button))
	button.resized.connect(Callable(self, "_refresh_button_pivot").bind(button))
	_refresh_button_pivot(button)


func _arrange_buttons(current_belief: int) -> void:
	match current_belief:
		MemoryManager.Belief.TRUE:
			button_row.move_child(uncertain_button, 0)
			button_row.move_child(false_button, 1)
		MemoryManager.Belief.FALSE:
			button_row.move_child(uncertain_button, 0)
			button_row.move_child(true_button, 1)
		_:
			button_row.move_child(true_button, 0)
			button_row.move_child(false_button, 1)


func _process(delta: float) -> void:
	if _hovered_buttons.is_empty():
		return

	_wiggle_time += delta * hover_wobble_speed
	var angle := deg_to_rad(sin(_wiggle_time) * hover_wobble_degrees)

	for button in _hovered_buttons.keys():
		if button is TextureButton:
			button.rotation = angle


func _on_button_mouse_entered(button: TextureButton) -> void:
	_hovered_buttons[button] = true
	_wiggle_time = 0.0


func _on_button_mouse_exited(button: TextureButton) -> void:
	_hovered_buttons.erase(button)
	button.rotation = 0.0


func _refresh_button_pivot(button: TextureButton) -> void:
	button.pivot_offset = button.size * 0.5


func _on_classification_pressed(belief: int) -> void:
	hide_popup()
	classification_requested.emit(belief)
