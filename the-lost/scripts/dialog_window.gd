extends Control

signal dialog_finished(memory_ids: Array)
signal option_selected(option_index: int, option_data: Dictionary)

const INTERACT_ACTION: StringName = &"interact"
const NORMAL_TEXTURE = preload("res://assets/gameUI/dialog-normal.png")
const OPTIONS_TEXTURE = preload("res://assets/gameUI/dialog-options.png")

@onready var dialog_texture: TextureRect = $DialogTexture
@onready var name_label: Label = $NamePlate/NameLabel
@onready var line_label: Label = $LineText
@onready var advance_hitbox: Button = $AdvanceHitbox

var _lines: Array[String] = []
var _options: Array = []
var _memory_ids: Array[String] = []
var option_slots: Array[Control] = []
var _dialog_index := 0
var _can_advance := false
var _has_interact_action := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_has_interact_action = InputMap.has_action(INTERACT_ACTION)
	advance_hitbox.pressed.connect(Callable(self, "advance"))
	option_slots = [
		get_node("OptionSlots/OptionSlot1") as Control,
		get_node("OptionSlots/OptionSlot2") as Control,
		get_node("OptionSlots/OptionSlot3") as Control,
	]

	for index in range(option_slots.size()):
		var slot := option_slots[index]
		var button := slot.get_node("Hitbox") as Button
		button.pressed.connect(Callable(self, "_on_option_pressed").bind(index))


func start_dialog(
	speaker_name: String,
	lines: Array,
	options: Array = [],
	memory_ids: Array = []
) -> void:
	_lines = _string_array(lines)
	_options = options.duplicate(true)
	_memory_ids = _string_array(memory_ids)
	_dialog_index = 0
	_can_advance = false

	if _lines.is_empty():
		_lines.append("...")

	name_label.text = speaker_name
	visible = true
	_refresh()
	call_deferred(&"_enable_advance")


func advance() -> void:
	if not visible or not _can_advance:
		return
	if _has_visible_options():
		return

	if _dialog_index < _lines.size() - 1:
		_dialog_index += 1
		_refresh()
		return

	_finish_dialog()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_interact_pressed(event):
		advance()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var show_options := _has_visible_options()
	line_label.text = _lines[_dialog_index]
	dialog_texture.texture = OPTIONS_TEXTURE if show_options else NORMAL_TEXTURE
	advance_hitbox.visible = not show_options

	for index in range(option_slots.size()):
		var slot := option_slots[index]
		var option_visible := show_options and index < _options.size()
		slot.visible = option_visible
		var button := slot.get_node("Hitbox") as Button
		button.disabled = not option_visible
		if not option_visible:
			continue

		var label := slot.get_node("Label") as Label
		var option_data = _options[index]
		if option_data is Dictionary:
			label.text = str(option_data.get("text", ""))
		else:
			label.text = str(option_data)


func _has_visible_options() -> bool:
	return _dialog_index >= _lines.size() - 1 and not _options.is_empty()


func _finish_dialog() -> void:
	var discovered_ids := _memory_ids.duplicate()
	visible = false
	_lines.clear()
	_options.clear()
	_memory_ids.clear()
	_dialog_index = 0
	_can_advance = false
	dialog_finished.emit(discovered_ids)


func _enable_advance() -> void:
	_can_advance = visible


func _on_option_pressed(option_index: int) -> void:
	if option_index < 0 or option_index >= _options.size():
		return

	var option_data = {}
	if _options[option_index] is Dictionary:
		option_data = _options[option_index]
	else:
		option_data = {"text": str(_options[option_index])}

	option_selected.emit(option_index, option_data)

	if option_data.has("memory_ids"):
		_memory_ids = _string_array(option_data.get("memory_ids", []))

	if option_data.has("lines"):
		_lines = _string_array(option_data.get("lines", []))
		_options.clear()
		_dialog_index = 0
		_can_advance = true

		if _lines.is_empty():
			_finish_dialog()
		else:
			_refresh()
		return

	_finish_dialog()


func _is_interact_pressed(event: InputEvent) -> bool:
	if _has_interact_action:
		return event.is_action_pressed(INTERACT_ACTION)

	if event is InputEventKey:
		var key_event := event as InputEventKey
		return (
			key_event.pressed
			and not key_event.echo
			and key_event.physical_keycode == KEY_E
		)

	return false


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result

	for item in value:
		result.append(str(item))

	return result
