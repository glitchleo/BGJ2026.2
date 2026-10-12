extends Control

signal classification_requested(memory_id: String, belief: int)

@export_range(0.0, 8.0, 0.1) var hover_wobble_degrees := 2.0
@export_range(0.0, 24.0, 0.1) var hover_wobble_speed := 9.0

@onready var memory_text: RichTextLabel = $MemoryText
@onready var true_button: TextureButton = $ButtonRow/TrueButton
@onready var false_button: TextureButton = $ButtonRow/FalseButton
@onready var uncertain_button: TextureButton = $ButtonRow/UncertainButton

var memory_id := ""
var _memory_data: Dictionary = {}
var _current_belief := MemoryManager.Belief.UNCLASSIFIED
var _hovered_buttons: Dictionary = {}
var _wiggle_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wire_button(true_button, MemoryManager.Belief.TRUE)
	_wire_button(false_button, MemoryManager.Belief.FALSE)
	_wire_button(uncertain_button, MemoryManager.Belief.UNCERTAIN)
	_apply_data()


func setup(memory_data: Dictionary, current_belief: int) -> void:
	_memory_data = memory_data.duplicate(true)
	memory_id = str(_memory_data.get("id", ""))
	_current_belief = current_belief

	if is_node_ready():
		_apply_data()


func _apply_data() -> void:
	if not is_node_ready():
		return

	memory_text.bbcode_enabled = true
	memory_text.text = "[b]%s[/b]" % _escape_bbcode(str(_memory_data.get("text", "")))
	memory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_text.scroll_active = false
	memory_text.add_theme_color_override("default_color", Color.BLACK)

	_set_button_enabled(true_button, _current_belief != MemoryManager.Belief.TRUE)
	_set_button_enabled(false_button, _current_belief != MemoryManager.Belief.FALSE)
	_set_button_enabled(uncertain_button, _current_belief != MemoryManager.Belief.UNCERTAIN)


func _wire_button(button: TextureButton, belief: int) -> void:
	if button == null:
		return

	button.pressed.connect(Callable(self, "_on_classification_pressed").bind(belief))
	button.mouse_entered.connect(Callable(self, "_on_button_mouse_entered").bind(button))
	button.mouse_exited.connect(Callable(self, "_on_button_mouse_exited").bind(button))
	button.resized.connect(Callable(self, "_refresh_button_pivot").bind(button))
	_refresh_button_pivot(button)


func _set_button_enabled(button: TextureButton, is_enabled: bool) -> void:
	if button == null:
		return

	button.disabled = not is_enabled
	button.modulate.a = 1.0 if is_enabled else 0.45


func _process(delta: float) -> void:
	if _hovered_buttons.is_empty():
		return

	_wiggle_time += delta * hover_wobble_speed
	var angle := deg_to_rad(sin(_wiggle_time) * hover_wobble_degrees)

	for button in _hovered_buttons.keys():
		if button is TextureButton:
			button.rotation = angle


func _on_button_mouse_entered(button: TextureButton) -> void:
	if button.disabled:
		return

	_hovered_buttons[button] = true
	_wiggle_time = 0.0


func _on_button_mouse_exited(button: TextureButton) -> void:
	_hovered_buttons.erase(button)
	button.rotation = 0.0


func _refresh_button_pivot(button: TextureButton) -> void:
	if button == null:
		return

	button.pivot_offset = button.size * 0.5


func _on_classification_pressed(belief: int) -> void:
	classification_requested.emit(memory_id, belief)


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")
