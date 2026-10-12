extends Control

signal classification_requested(memory_id: String, belief: int)
signal move_popup_opened(entry: Control)

const MIN_ENTRY_HEIGHT := 118.0
const BODY_LINE_HEIGHT := 30.0
const HORIZONTAL_PADDING := 54.0
const VERTICAL_PADDING := 18.0

@onready var entry_panel: Control = $EntryPanel
@onready var conflict_icon: TextureRect = $EntryPanel/Margin/ContentRow/ConflictIcon
@onready var memory_text: RichTextLabel = $EntryPanel/Margin/ContentRow/MemoryText
@onready var hitbox: Button = $Hitbox
@onready var move_to_popup: Control = $MoveToPopup

var memory_id := ""
var _memory_data: Dictionary = {}
var _current_belief := MemoryManager.Belief.UNCLASSIFIED
var _allow_classification := true
var _has_conflict := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(Callable(self, "_on_entry_gui_input"))
	hitbox.pressed.connect(Callable(self, "_toggle_move_popup"))
	if move_to_popup.has_signal(&"classification_requested"):
		move_to_popup.connect(
			&"classification_requested",
			Callable(self, "_on_move_popup_classification_requested")
		)
	_apply_data()


func setup(
	memory_data: Dictionary,
	current_belief: int,
	allow_classification: bool = true,
	has_conflict: bool = false
) -> void:
	_memory_data = memory_data.duplicate(true)
	memory_id = str(_memory_data.get("id", ""))
	_current_belief = current_belief
	_allow_classification = allow_classification
	_has_conflict = has_conflict

	if is_node_ready():
		_apply_data()


func get_required_height(page_width: float, max_page_height: float) -> float:
	var content_width := maxf(page_width - HORIZONTAL_PADDING, 1.0)
	var text := str(_memory_data.get("text", ""))
	var text_height := _measure_text_height(text, content_width)
	var required := VERTICAL_PADDING + text_height

	if max_page_height > 0.0 and required > max_page_height:
		memory_text.fit_content = false
		memory_text.scroll_active = true
		memory_text.custom_minimum_size.y = maxf(
			BODY_LINE_HEIGHT * 2.0,
			max_page_height - VERTICAL_PADDING
		)
		return max_page_height

	memory_text.fit_content = true
	memory_text.scroll_active = false
	memory_text.custom_minimum_size.y = 0.0
	return maxf(required, MIN_ENTRY_HEIGHT)


func fit_to_page_width(page_width: float, max_page_height: float) -> void:
	custom_minimum_size.x = page_width
	custom_minimum_size.y = maxf(max_page_height, get_required_height(page_width, max_page_height))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func close_move_popup() -> void:
	if move_to_popup != null and move_to_popup.has_method(&"hide_popup"):
		move_to_popup.call(&"hide_popup")


func _apply_data() -> void:
	if not is_node_ready():
		return

	conflict_icon.visible = _has_conflict
	memory_text.bbcode_enabled = true
	memory_text.text = "[b]%s[/b]" % _escape_bbcode(str(_memory_data.get("text", "")))
	memory_text.fit_content = true
	memory_text.scroll_active = false
	memory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_text.add_theme_color_override("default_color", Color.BLACK)
	hitbox.disabled = not _allow_classification
	close_move_popup()


func _measure_text_height(text: String, content_width: float) -> float:
	if memory_text != null:
		memory_text.custom_minimum_size.x = content_width
		memory_text.text = "[b]%s[/b]" % _escape_bbcode(text)
		var content_height := memory_text.get_content_height()
		if content_height > 0.0:
			return content_height

	var average_character_width := 12.0
	var characters_per_line := maxi(10, floori(content_width / average_character_width))
	var line_count := maxi(1, ceili(float(text.length()) / float(characters_per_line)))
	return float(line_count) * BODY_LINE_HEIGHT


func _on_entry_gui_input(event: InputEvent) -> void:
	if not _allow_classification:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_move_popup()
			accept_event()


func _toggle_move_popup() -> void:
	if move_to_popup == null:
		return
	if not _allow_classification:
		return

	if move_to_popup.visible:
		close_move_popup()
		return

	move_popup_opened.emit(self)
	if move_to_popup.has_method(&"show_for_belief"):
		move_to_popup.call(&"show_for_belief", _current_belief)
	else:
		move_to_popup.visible = true


func _on_move_popup_classification_requested(belief: int) -> void:
	classification_requested.emit(memory_id, belief)


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")
