extends Control

signal memory_book_opened
signal memory_book_closed
signal section_changed(section_id: String)
signal page_changed(spread_index: int)
signal memory_classification_requested(memory_id: String, classification: int)

const MEMORY_ENTRY_SCENE = preload("res://scenes/memory_entry.tscn")
const TRUE_BOOK_TEXTURE = preload("res://assets/gameUI/book-trust.png")
const UNCERTAIN_BOOK_TEXTURE = preload("res://assets/gameUI/book-uncertain.png")
const FALSE_BOOK_TEXTURE = preload("res://assets/gameUI/book-false.png")
const PAGE_TURN_SOUND = preload("res://assets/SFX/turningPages.mp3")
const SFX_BUS := "SFX"
const MIN_ENTRY_HEIGHT := 118.0

@export_range(1, 12, 1) var entries_per_page := 4
@export_range(0.0, 32.0, 1.0) var entry_gap := 4.0
@export_range(0.0, 1.0, 0.01) var page_turn_volume := 0.55
@export_range(0.5, 2.0, 0.01) var page_turn_pitch := 1.18
@export_range(0.5, 2.0, 0.01) var book_open_pitch := 1.08

@onready var book_texture: TextureRect = $BookContainer/BookTexture
@onready var left_page_content: VBoxContainer = $BookContainer/LeftPage/LeftPageContent
@onready var right_page_content: VBoxContainer = $BookContainer/RightPage/RightPageContent
@onready var previous_page_button: TextureButton = $BookContainer/LeftPage/PreviousPageButton
@onready var next_page_button: TextureButton = $BookContainer/RightPage/NextPageButton
@onready var true_section_button: BaseButton = $BookContainer/TrueSectionButton
@onready var uncertain_section_button: BaseButton = $BookContainer/UncertainSectionButton
@onready var false_section_button: BaseButton = $BookContainer/FalseSectionButton

var current_section := MemoryManager.BOOK_SECTION_TRUE
var current_spread := 0

var _section_ids: Array[String] = []
var _pages: Array = []
var _section_buttons: Dictionary = {}
var _refresh_queued := false
var _page_sound_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_page_sound_player()

	_section_buttons = {
		MemoryManager.BOOK_SECTION_TRUE: true_section_button,
		MemoryManager.BOOK_SECTION_UNCERTAIN: uncertain_section_button,
		MemoryManager.BOOK_SECTION_FALSE: false_section_button,
	}

	for section_id in _section_buttons.keys():
		var button := _section_buttons[section_id] as BaseButton
		if button != null:
			button.pressed.connect(
				Callable(self, "_on_section_button_pressed").bind(str(section_id))
			)

	previous_page_button.pressed.connect(Callable(self, "_previous_spread"))
	next_page_button.pressed.connect(Callable(self, "_next_spread"))

	MemoryManager.memory_discovered.connect(Callable(self, "_on_memory_discovered"))
	MemoryManager.memory_classified.connect(Callable(self, "_on_memory_classified"))
	MemoryManager.pending_changed.connect(Callable(self, "_on_pending_changed"))

	_refresh_sections()
	_update_book_texture()
	_update_section_button_states()


func open_book() -> void:
	if visible:
		return

	visible = true
	_play_page_sound(true)
	_queue_refresh()
	memory_book_opened.emit()


func close_book() -> void:
	if not visible:
		return

	visible = false
	_close_open_move_popups()
	memory_book_closed.emit()


func toggle_book() -> void:
	if visible:
		close_book()
	else:
		open_book()


func refresh_book() -> void:
	_queue_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed(&"ui_cancel"):
		close_book()
		get_viewport().set_input_as_handled()


func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	call_deferred(&"_refresh_book")


func _refresh_book() -> void:
	_refresh_queued = false

	if not visible:
		return

	_refresh_sections()
	_update_book_texture()
	_update_section_button_states()
	_clear_children(left_page_content)
	_clear_children(right_page_content)

	if current_section.is_empty():
		_show_empty_section()
		return

	_pages = _paginate_section(current_section)

	if _pages.is_empty():
		_show_empty_section()
		return

	var maximum_spread := floori(float(maxi(_pages.size() - 1, 0)) / 2.0)
	current_spread = clampi(current_spread, 0, maximum_spread)

	var left_page_index := current_spread * 2
	var right_page_index := left_page_index + 1

	_render_page(left_page_content, _pages[left_page_index])

	if right_page_index < _pages.size():
		_render_page(right_page_content, _pages[right_page_index])

	previous_page_button.visible = current_spread > 0
	next_page_button.visible = right_page_index + 1 < _pages.size()
	page_changed.emit(current_spread)


func _refresh_sections() -> void:
	var sections: Array = MemoryManager.get_book_sections()
	var normalized: Array[String] = []
	for section in sections:
		normalized.append(str(section))

	_section_ids = normalized

	if current_section.is_empty() or current_section not in _section_ids:
		current_section = _section_ids[0] if not _section_ids.is_empty() else ""
		current_spread = 0


func _update_book_texture() -> void:
	if book_texture == null:
		return

	book_texture.texture = _texture_for_section(current_section)


func _texture_for_section(section_id: String) -> Texture2D:
	match section_id:
		MemoryManager.BOOK_SECTION_UNCERTAIN:
			return UNCERTAIN_BOOK_TEXTURE
		MemoryManager.BOOK_SECTION_FALSE:
			return FALSE_BOOK_TEXTURE
		_:
			return TRUE_BOOK_TEXTURE


func _update_section_button_states() -> void:
	for section_id in _section_buttons.keys():
		var button := _section_buttons[section_id] as BaseButton
		if button == null:
			continue

		button.visible = str(section_id) in _section_ids
		button.disabled = str(section_id) == current_section


func _paginate_section(section_id: String) -> Array:
	var memory_ids := MemoryManager.get_discovered_ids_for_section(section_id)
	var pages: Array = []
	var per_page := maxi(entries_per_page, 1)

	for start in range(0, memory_ids.size(), per_page):
		var page: Array[String] = []
		var page_end := mini(start + per_page, memory_ids.size())
		for index in range(start, page_end):
			page.append(str(memory_ids[index]))
		pages.append(page)

	return pages


func _render_page(parent: VBoxContainer, memory_ids: Array) -> void:
	parent.add_theme_constant_override("separation", int(entry_gap))

	var page_size := _get_page_content_size()
	var entry_slot_height := _get_entry_slot_height(page_size.y)

	for memory_id in memory_ids:
		var entry := MEMORY_ENTRY_SCENE.instantiate() as Control
		if entry == null:
			continue

		parent.add_child(entry)
		_setup_entry(entry, str(memory_id), Vector2(page_size.x, entry_slot_height))


func _setup_entry(entry: Control, memory_id: String, page_size: Vector2) -> void:
	var memory := GameDB.get_memory(memory_id)
	var belief := MemoryManager.get_belief(memory_id)
	var has_conflict := not MemoryManager.get_marked_true_conflict_ids(memory_id).is_empty()

	if entry.has_method(&"setup"):
		entry.call(&"setup", memory, belief, true, has_conflict)
	if entry.has_method(&"fit_to_page_width"):
		entry.call(&"fit_to_page_width", page_size.x, page_size.y)
	if entry.has_signal(&"classification_requested"):
		entry.connect(
			&"classification_requested",
			Callable(self, "_on_entry_classification_requested")
		)
	if entry.has_signal(&"move_popup_opened"):
		entry.connect(&"move_popup_opened", Callable(self, "_on_entry_move_popup_opened"))


func _show_empty_section() -> void:
	_clear_children(left_page_content)
	_clear_children(right_page_content)

	previous_page_button.visible = false
	next_page_button.visible = false


func _get_page_content_size() -> Vector2:
	var size := left_page_content.size

	if size.x <= 0.0:
		size.x = 620.0
	if size.y <= 0.0:
		size.y = 540.0

	return size


func _get_entry_slot_height(page_height: float) -> float:
	var per_page := maxi(entries_per_page, 1)
	var total_gap := maxf(float(per_page - 1), 0.0) * entry_gap
	return maxf((page_height - total_gap) / float(per_page), MIN_ENTRY_HEIGHT)


func _build_page_sound_player() -> void:
	_ensure_audio_bus(SFX_BUS)

	_page_sound_player = AudioStreamPlayer.new()
	_page_sound_player.name = "PageSoundPlayer"
	_page_sound_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_page_sound_player.stream = PAGE_TURN_SOUND
	_page_sound_player.bus = SFX_BUS
	add_child(_page_sound_player)


func _play_page_sound(opening_book: bool = false) -> void:
	if not is_instance_valid(_page_sound_player):
		_build_page_sound_player()

	_page_sound_player.stop()
	_page_sound_player.volume_db = linear_to_db(maxf(page_turn_volume, 0.001))
	_page_sound_player.pitch_scale = book_open_pitch if opening_book else page_turn_pitch
	_page_sound_player.play()


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var bus_index := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)


func _on_section_button_pressed(section_id: String) -> void:
	if section_id == current_section:
		return

	current_section = section_id
	current_spread = 0
	_play_page_sound()
	_update_book_texture()
	_update_section_button_states()
	_queue_refresh()
	section_changed.emit(current_section)


func _previous_spread() -> void:
	if current_spread <= 0:
		return

	current_spread -= 1
	_play_page_sound()
	_queue_refresh()


func _next_spread() -> void:
	if (current_spread * 2) + 2 >= _pages.size():
		return

	current_spread += 1
	_play_page_sound()
	_queue_refresh()


func _on_entry_move_popup_opened(opened_entry: Control) -> void:
	for entry in _get_rendered_entries():
		if entry != opened_entry and entry.has_method(&"close_move_popup"):
			entry.call(&"close_move_popup")


func _on_entry_classification_requested(memory_id: String, classification: int) -> void:
	_close_open_move_popups()
	memory_classification_requested.emit(memory_id, classification)


func _on_memory_discovered(_memory_id: String) -> void:
	_queue_refresh()


func _on_memory_classified(_memory_id: String, _belief: int) -> void:
	_queue_refresh()


func _on_pending_changed(_memory_ids: Array) -> void:
	_queue_refresh()


func _close_open_move_popups() -> void:
	for entry in _get_rendered_entries():
		if entry.has_method(&"close_move_popup"):
			entry.call(&"close_move_popup")


func _get_rendered_entries() -> Array[Control]:
	var entries: Array[Control] = []
	for parent in [left_page_content, right_page_content]:
		for child in parent.get_children():
			if child is Control:
				entries.append(child)

	return entries


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
