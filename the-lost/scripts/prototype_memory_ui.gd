extends CanvasLayer

signal final_dialog_finished

const BOOK_ACTION: StringName = &"memory_book"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const MEMORY_BOOK_SCENE = preload("res://scenes/memory_book.tscn")
const MEMORY_BOOK_ICON_SCENE = preload("res://scenes/memory_book_icon.tscn")
const DIALOG_WINDOW_SCENE = preload("res://scenes/dialog_window.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/pause_menu.tscn")
const SETTINGS_MENU_SCENE = preload("res://scenes/settings_menu.tscn")
const NEW_MEMORY_CARD_SCENE = preload("res://scenes/new_memory_card.tscn")
const LOST_METER_SCENE = preload("res://scenes/lost_meter.tscn")
const LOST_METER_SIZE := Vector2(392.0, 71.0)

var root: Control

var lost_meter: Control

var dialog_window: Control

var pending_holder: HBoxContainer

var book_icon: TextureButton
var memory_book: Control
var pause_menu: Control
var settings_menu: Control

var _has_book_action := false
var _settings_return_to_pause := false
var _final_dialog_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_has_book_action = InputMap.has_action(BOOK_ACTION)

	_build_root()
	_build_lost_meter()
	_build_book_icon()
	_build_pending_cards()
	_build_dialog()
	_build_book()
	_build_pause_and_settings()

	MemoryManager.lost_changed.connect(_on_lost_changed)
	MemoryManager.pending_changed.connect(_on_pending_changed)
	MemoryManager.memory_classified.connect(_on_memory_classified)

	_on_lost_changed(MemoryManager.lost_value, 0.0)
	_rebuild_pending_cards()
	_refresh_book_icon()
	_render_book()
	_refresh_pause_state()


func reset_ui_for_run() -> void:
	if root == null:
		return

	if dialog_window != null:
		dialog_window.visible = false

	if memory_book != null:
		memory_book.visible = false
	if pause_menu != null:
		pause_menu.visible = false
	if settings_menu != null:
		settings_menu.visible = false
	_settings_return_to_pause = false
	_final_dialog_active = false

	_on_lost_changed(MemoryManager.lost_value, 0.0)
	_rebuild_pending_cards()
	_refresh_book_icon()
	_render_book()
	_refresh_pause_state()


func set_game_ui_visible(is_visible: bool) -> void:
	if root != null:
		root.visible = is_visible
	if not is_visible:
		_hide_runtime_overlays()
	_refresh_pause_state()


func _build_root() -> void:
	root = Control.new()
	root.name = "MemoryUI"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)


func _build_lost_meter() -> void:
	lost_meter = LOST_METER_SCENE.instantiate() as Control
	if lost_meter == null:
		push_error("Lost meter scene could not be loaded.")
		return

	lost_meter.anchor_left = 0.02
	lost_meter.anchor_top = 0.02
	lost_meter.anchor_right = 0.02
	lost_meter.anchor_bottom = 0.02
	lost_meter.offset_right = LOST_METER_SIZE.x
	lost_meter.offset_bottom = LOST_METER_SIZE.y
	lost_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lost_meter)


func _build_book_icon() -> void:
	book_icon = MEMORY_BOOK_ICON_SCENE.instantiate() as TextureButton
	if book_icon == null:
		push_error("Memory book icon scene could not be loaded.")
		return

	root.add_child(book_icon)
	book_icon.pressed.connect(Callable(self, "toggle_book"))


func _build_dialog() -> void:
	dialog_window = DIALOG_WINDOW_SCENE.instantiate() as Control
	if dialog_window == null:
		push_error("Dialog window scene could not be loaded.")
		return

	root.add_child(dialog_window)
	if dialog_window.has_signal(&"dialog_finished"):
		dialog_window.connect(&"dialog_finished", Callable(self, "_on_dialog_finished"))
	if dialog_window.has_signal(&"option_selected"):
		dialog_window.connect(&"option_selected", Callable(self, "_on_dialog_option_selected"))
	dialog_window.visibility_changed.connect(Callable(self, "_on_overlay_visibility_changed"))


func _build_pending_cards() -> void:
	pending_holder = HBoxContainer.new()
	pending_holder.anchor_left = 0.04
	pending_holder.anchor_top = 0.42
	pending_holder.anchor_right = 0.96
	pending_holder.anchor_bottom = 0.96
	pending_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	pending_holder.add_theme_constant_override("separation", 18)
	root.add_child(pending_holder)


func _build_book() -> void:
	memory_book = MEMORY_BOOK_SCENE.instantiate() as Control
	if memory_book == null:
		push_error("Memory book scene could not be loaded.")
		return

	root.add_child(memory_book)

	if memory_book.has_signal(&"memory_book_opened"):
		memory_book.connect(&"memory_book_opened", Callable(self, "_on_memory_book_visibility_changed"))
	if memory_book.has_signal(&"memory_book_closed"):
		memory_book.connect(&"memory_book_closed", Callable(self, "_on_memory_book_visibility_changed"))
	if memory_book.has_signal(&"memory_classification_requested"):
		memory_book.connect(
			&"memory_classification_requested",
			Callable(self, "_on_book_memory_classification_requested")
		)


func _build_pause_and_settings() -> void:
	pause_menu = PAUSE_MENU_SCENE.instantiate() as Control
	if pause_menu != null:
		root.add_child(pause_menu)
		pause_menu.connect(&"resume_requested", Callable(self, "_on_pause_resume_requested"))
		pause_menu.connect(&"settings_requested", Callable(self, "_on_pause_settings_requested"))
		pause_menu.connect(&"main_menu_requested", Callable(self, "_on_pause_main_menu_requested"))
		pause_menu.connect(&"leave_requested", Callable(self, "_on_pause_leave_requested"))
		pause_menu.connect(&"back_requested", Callable(self, "_on_pause_back_requested"))
		pause_menu.visibility_changed.connect(Callable(self, "_on_overlay_visibility_changed"))
	else:
		push_error("Pause menu scene could not be loaded.")

	settings_menu = SETTINGS_MENU_SCENE.instantiate() as Control
	if settings_menu != null:
		root.add_child(settings_menu)
		settings_menu.connect(&"back_requested", Callable(self, "_on_settings_back_requested"))
		settings_menu.visibility_changed.connect(Callable(self, "_on_overlay_visibility_changed"))
	else:
		push_error("Settings menu scene could not be loaded.")


func start_npc_dialog(npc_data: Dictionary) -> void:
	if _is_dialog_visible() or _is_pause_menu_visible() or _is_settings_menu_visible():
		return
	if _final_dialog_active:
		return

	var dialogue := GameDB.get_npc_dialogue(npc_data)
	var lines := _string_array(dialogue.get("lines", []))
	var memory_ids := _string_array(dialogue.get("memory_ids", []))
	var options: Array = dialogue.get("options", [])

	if dialog_window != null and dialog_window.has_method(&"start_dialog"):
		dialog_window.call(
			&"start_dialog",
			str(dialogue.get("speaker_name", npc_data.get("name", "???"))),
			lines,
			options,
			memory_ids
		)

	_rebuild_pending_cards()
	_refresh_pause_state()


func start_final_dialog() -> void:
	if dialog_window == null:
		final_dialog_finished.emit()
		return
	if _is_dialog_visible():
		return

	var final_dialogue := GameDB.get_final_dialogue()
	var thresholds: Dictionary = final_dialogue.get("accuracy_thresholds", {})
	var accuracy_state := MemoryManager.capture_final_accuracy_state(
		float(thresholds.get("high", 0.7)),
		float(thresholds.get("mixed", 0.4))
	)
	var opening_lines := _string_array(final_dialogue.get("opening_lines", []))
	var choices := _build_final_confidence_options(final_dialogue, accuracy_state)

	_final_dialog_active = true
	dialog_window.call(
		&"start_dialog",
		str(final_dialogue.get("speaker_name", "Lamb")),
		opening_lines,
		choices,
		[]
	)
	_rebuild_pending_cards()
	_refresh_pause_state()


func _on_dialog_finished(memory_ids: Array) -> void:
	if _final_dialog_active:
		_final_dialog_active = false
		_rebuild_pending_cards()
		_refresh_pause_state()
		final_dialog_finished.emit()
		return

	if not memory_ids.is_empty():
		MemoryManager.discover_memories(memory_ids)

	_rebuild_pending_cards()
	_refresh_pause_state()


func _on_dialog_option_selected(_option_index: int, _option_data: Dictionary) -> void:
	_rebuild_pending_cards()
	_refresh_pause_state()


func _on_pending_changed(_memory_ids: Array) -> void:
	_rebuild_pending_cards()
	_refresh_book_icon()
	_render_book()
	_refresh_pause_state()


func _on_memory_classified(_memory_id: String, _belief: int) -> void:
	_rebuild_pending_cards()
	_refresh_book_icon()
	_render_book()
	_refresh_pause_state()


func _rebuild_pending_cards() -> void:
	_clear_children(pending_holder)

	var pending := MemoryManager.get_pending_ids()

	if not pending.is_empty():
		var memory_id := str(pending[0])
		var memory := GameDB.get_memory(memory_id)
		if not memory.is_empty():
			var card := NEW_MEMORY_CARD_SCENE.instantiate() as Control
			if card != null:
				pending_holder.add_child(card)
				if card.has_method(&"setup"):
					card.call(&"setup", memory, MemoryManager.get_belief(memory_id))
				if card.has_signal(&"classification_requested"):
					card.connect(
						&"classification_requested",
						Callable(self, "_on_pending_memory_classification_requested")
					)

	pending_holder.visible = (
		not pending.is_empty()
		and not _is_book_visible()
		and not _is_dialog_visible()
		and not _is_pause_menu_visible()
		and not _is_settings_menu_visible()
	)


func _on_pending_memory_classification_requested(memory_id: String, belief: int) -> void:
	MemoryManager.classify_memory(memory_id, belief)


func _unhandled_input(event: InputEvent) -> void:
	if root == null or not root.visible:
		return

	if _is_cancel_pressed(event):
		if _is_settings_menu_visible():
			_close_settings_menu()
			get_viewport().set_input_as_handled()
			return
		if _is_pause_menu_visible():
			_hide_pause_menu()
			get_viewport().set_input_as_handled()
			return
		if _is_book_visible():
			toggle_book()
			get_viewport().set_input_as_handled()
			return
		if _is_dialog_visible() or not MemoryManager.get_pending_ids().is_empty():
			return

		_show_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if _is_dialog_visible() or _is_pause_menu_visible() or _is_settings_menu_visible():
		return

	if not _is_book_toggle_pressed(event):
		return

	toggle_book()
	get_viewport().set_input_as_handled()


func _is_book_toggle_pressed(event: InputEvent) -> bool:
	if _has_book_action:
		return event.is_action_pressed(BOOK_ACTION)

	if event is InputEventKey:
		return (
			event.pressed
			and not event.echo
			and event.physical_keycode == KEY_Q
		)

	return false


func _is_cancel_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel"):
		return true

	if event is InputEventKey:
		return (
			event.pressed
			and not event.echo
			and event.physical_keycode == KEY_ESCAPE
		)

	return false


func toggle_book() -> void:
	if memory_book == null:
		return

	if memory_book.has_method(&"toggle_book"):
		memory_book.call(&"toggle_book")
	else:
		memory_book.visible = not memory_book.visible

	_rebuild_pending_cards()
	_refresh_pause_state()


func _render_book() -> void:
	if memory_book == null:
		return

	if memory_book.has_method(&"refresh_book"):
		memory_book.call(&"refresh_book")


func _on_lost_changed(new_value: float, _delta: float) -> void:
	if lost_meter == null:
		return

	if lost_meter.has_method(&"set_lost_value"):
		lost_meter.call(
			&"set_lost_value",
			new_value,
			MemoryManager.get_minimum_lost(),
			MemoryManager.get_maximum_lost()
		)


func _refresh_book_icon() -> void:
	if book_icon == null:
		return

	if book_icon.has_method(&"set_conflict_visible"):
		book_icon.call(&"set_conflict_visible", MemoryManager.has_marked_true_conflicts())


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _build_final_confidence_options(
	final_dialogue: Dictionary,
	accuracy_state: String
) -> Array:
	var choices: Array = []
	var response_data: Dictionary = final_dialogue.get("responses", {})
	var thank_you_lines := _string_array(final_dialogue.get("thank_you_lines", []))
	var final_lines_by_state: Dictionary = final_dialogue.get("final_lines", {})
	var final_lines := _string_array(final_lines_by_state.get(accuracy_state, []))

	for raw_choice in final_dialogue.get("confidence_choices", []):
		if not (raw_choice is Dictionary):
			continue

		var choice := raw_choice as Dictionary
		var confidence_id := str(choice.get("id", "UNSURE"))
		var response_key := "%s_%s" % [accuracy_state, confidence_id]
		var option_lines := _string_array(response_data.get(response_key, []))
		option_lines.append_array(thank_you_lines)
		option_lines.append_array(final_lines)

		choices.append({
			"id": confidence_id,
			"text": str(choice.get("text", "...")),
			"lines": option_lines
		})

	return choices


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result

	for item in value:
		result.append(str(item))

	return result


func _refresh_pause_state() -> void:
	var should_pause := (
		root != null
		and root.visible
		and (
			_is_book_visible()
			or _is_dialog_visible()
			or _is_pause_menu_visible()
			or _is_settings_menu_visible()
			or not MemoryManager.get_pending_ids().is_empty()
		)
	)

	get_tree().paused = should_pause


func _is_dialog_visible() -> bool:
	return dialog_window != null and dialog_window.visible


func _is_pause_menu_visible() -> bool:
	return pause_menu != null and pause_menu.visible


func _is_settings_menu_visible() -> bool:
	return settings_menu != null and settings_menu.visible


func _show_pause_menu() -> void:
	if pause_menu != null and pause_menu.has_method(&"show_menu"):
		pause_menu.call(&"show_menu")
	elif pause_menu != null:
		pause_menu.visible = true

	_rebuild_pending_cards()
	_refresh_pause_state()


func _hide_pause_menu() -> void:
	if pause_menu != null and pause_menu.has_method(&"hide_menu"):
		pause_menu.call(&"hide_menu")
	elif pause_menu != null:
		pause_menu.visible = false

	_rebuild_pending_cards()
	_refresh_pause_state()


func _show_settings_menu(return_to_pause: bool) -> void:
	_settings_return_to_pause = return_to_pause
	if settings_menu != null and settings_menu.has_method(&"show_menu"):
		settings_menu.call(&"show_menu")
	elif settings_menu != null:
		settings_menu.visible = true

	_rebuild_pending_cards()
	_refresh_pause_state()


func _close_settings_menu() -> void:
	if settings_menu != null and settings_menu.has_method(&"hide_menu"):
		settings_menu.call(&"hide_menu")
	elif settings_menu != null:
		settings_menu.visible = false

	if _settings_return_to_pause:
		_settings_return_to_pause = false
		_show_pause_menu()
	else:
		_settings_return_to_pause = false
		_rebuild_pending_cards()
		_refresh_pause_state()


func _hide_runtime_overlays() -> void:
	if dialog_window != null:
		dialog_window.visible = false
	if memory_book != null:
		memory_book.visible = false
	if pause_menu != null:
		pause_menu.visible = false
	if settings_menu != null:
		settings_menu.visible = false
	_settings_return_to_pause = false
	_final_dialog_active = false


func _on_pause_resume_requested() -> void:
	_hide_pause_menu()


func _on_pause_settings_requested() -> void:
	if pause_menu != null and pause_menu.has_method(&"hide_menu"):
		pause_menu.call(&"hide_menu")
	elif pause_menu != null:
		pause_menu.visible = false

	_show_settings_menu(true)


func _on_pause_main_menu_requested() -> void:
	_hide_runtime_overlays()
	get_tree().paused = false
	set_game_ui_visible(false)
	var result := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if result != OK:
		push_error("MemoryUI: Could not load main menu scene %s" % MAIN_MENU_SCENE_PATH)


func _on_pause_leave_requested() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_pause_back_requested() -> void:
	_hide_pause_menu()


func _on_settings_back_requested() -> void:
	if _settings_return_to_pause:
		_settings_return_to_pause = false
		_show_pause_menu()
	else:
		_rebuild_pending_cards()
		_refresh_pause_state()


func _on_overlay_visibility_changed() -> void:
	_rebuild_pending_cards()
	_refresh_pause_state()


func _is_book_visible() -> bool:
	return memory_book != null and memory_book.visible


func _on_memory_book_visibility_changed() -> void:
	_rebuild_pending_cards()
	_refresh_pause_state()


func _on_book_memory_classification_requested(memory_id: String, belief: int) -> void:
	MemoryManager.classify_memory(memory_id, belief)
