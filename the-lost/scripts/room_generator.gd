extends Node2D

const ROOM_WIDTH := 20
const ROOM_HEIGHT := 15
const TILE_SIZE := 256.0
const HALF_TILE_SIZE := TILE_SIZE / 2.0
const MAX_GENERATION_ATTEMPTS := 100
const ROOM_MARGIN_LEFT := 2
const ROOM_MARGIN_RIGHT := 2
const ROOM_MARGIN_TOP := 3
const ROOM_MARGIN_BOTTOM := 2
const MIN_VERTICAL_SIDE_WALL_HEIGHT := 3

const ENTRY_START_OFFSET := Vector2(0.0, 1500.0)
const ENTRY_MOVE_DURATION := 1.2
const ENTRY_FADE_DURATION := 0.3

const INITIAL_SPAWN_CELL := Vector2i(9, 10)
const FINAL_HOME_DOOR_CELL := Vector2i(9, 3)
const FINAL_EXIT_TARGET_OFFSET := Vector2(0.0, -64.0)
const FINAL_EXIT_MOVE_DURATION := 0.9
const FINAL_EXIT_FADE_DURATION := 0.35

const ROOM_SCENE = preload("res://scenes/rooms/room.tscn")
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const DOOR_SCENE = preload("res://scenes/door.tscn")
const END_MENU_SCENE = preload("res://scenes/end_menu.tscn")
const DOOR_SOUND = preload("res://assets/SFX/door.mp3")
const TUTORIAL_OVERLAY_SCENE = preload("res://scenes/tutorial_overlay.tscn")
const SFX_BUS := "SFX"

const CARDINAL_DIRECTIONS := [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]

enum CellType {
	EMPTY,
	FLOOR,
	DOOR,
	HOME_DOOR,
}

enum RoomShape {
	RECTANGLE,
	L_SHAPE,
	U_SHAPE,
	PLUS_SHAPE,
	T_SHAPE,
	H_SHAPE,
	MANUAL,
	INITIAL_SPAWN,
	FINAL_APPROACH,
}

const NORMAL_ROOM_SHAPES := [
	RoomShape.RECTANGLE,
	RoomShape.L_SHAPE,
	RoomShape.U_SHAPE,
	RoomShape.PLUS_SHAPE,
	RoomShape.T_SHAPE,
	RoomShape.H_SHAPE,
]

@export_group("Home Path")
@export_range(0.0, 1.0, 0.01) var home_chance_when_fully_lost: float = 0.01
@export_range(0.0, 1.0, 0.01) var home_chance_when_not_lost: float = 0.22
@export_range(0, 20, 1) var minimum_normal_rooms_before_home: int = 3
@export_range(0.0, 100.0, 1.0) var lost_reduction_per_normal_room: float = 0.0
@export_range(0.0, 1.0, 0.01) var home_memory_bonus_per_correct: float = 0.03
@export_range(0.0, 1.0, 0.01) var home_memory_bonus_per_uncertain: float = 0.01
@export_range(0.0, 1.0, 0.01) var maximum_home_memory_bonus: float = 0.16
@export_range(0.0, 1.0, 0.01) var pity_increase_per_failed_room: float = 0.02
@export_range(0.0, 1.0, 0.01) var maximum_pity_bonus: float = 0.18
@export_range(0.0, 1.0, 0.01) var maximum_home_chance: float = 0.65

@export_group("Room Size")
@export_range(5, 15, 1) var minimum_room_width: int = 5
@export_range(5, 15, 1) var maximum_room_width: int = 15
@export_range(4, 10, 1) var minimum_room_height: int = 4
@export_range(4, 10, 1) var maximum_room_height: int = 10
@export_range(8, 120, 1) var minimum_walkable_floor_tiles: int = 14

@export_group("Normal Doors")
@export_range(1, 10, 1) var valid_positions_per_door: int = 3
@export_range(1, 6, 1) var max_normal_doors: int = 3
@export_range(1, 10, 1) var minimum_door_spacing_cells: int = 3

@export_group("Generated NPCs")
@export var npc_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var npc_spawn_chance: float = 1.0
@export_range(0, 200, 1) var medium_room_floor_tiles: int = 36
@export_range(0, 200, 1) var large_room_floor_tiles: int = 70
@export_range(0, 6, 1) var small_room_min_npcs: int = 0
@export_range(0, 6, 1) var small_room_max_npcs: int = 1
@export_range(0, 6, 1) var medium_room_min_npcs: int = 1
@export_range(0, 6, 1) var medium_room_max_npcs: int = 2
@export_range(0, 6, 1) var large_room_min_npcs: int = 1
@export_range(0, 6, 1) var large_room_max_npcs: int = 3
@export_range(0, 10, 1) var npc_clearance_cells: int = 2

@export_group("Audio")
@export_range(0.0, 1.0, 0.01) var door_sound_volume := 0.55
@export_range(0.5, 2.0, 0.01) var door_sound_pitch := 1.18

var grid: Array[Array] = []
var player_instance: CharacterBody2D
var current_room: Node2D
var actors_root: Node2D
var tutorial_overlay: CanvasLayer

var normal_rooms_visited: int = 0
var home_room_failures: int = 0
var _room_transition_in_progress: bool = false
var _ending_shown: bool = false
var _end_menu_instance: CanvasLayer
var _door_sound_player: AudioStreamPlayer


func _ready() -> void:
	randomize()
	_build_door_sound_player()

	if MusicManager.has_method(&"play_gameplay_music"):
		MusicManager.call(&"play_gameplay_music")

	_start_new_run()
	generate_room(RoomShape.INITIAL_SPAWN)
	_show_tutorial()


func _start_new_run() -> void:
	get_tree().paused = false
	normal_rooms_visited = 0
	home_room_failures = 0
	_room_transition_in_progress = false
	_ending_shown = false
	if is_instance_valid(_end_menu_instance):
		_end_menu_instance.queue_free()
	_end_menu_instance = null
	_ensure_actors_root()
	_clear_generated_actors()

	MemoryManager.reset_run()
	NpcGenerator.reset_run()

	if MemoryUI.has_method(&"set_game_ui_visible"):
		MemoryUI.call(&"set_game_ui_visible", true)
	if MemoryUI.has_method(&"reset_ui_for_run"):
		MemoryUI.call(&"reset_ui_for_run")


func generate_room(force_shape: int = -1) -> void:
	if _room_transition_in_progress or _ending_shown:
		return

	_room_transition_in_progress = true

	var shape_type := force_shape
	var room_is_valid := false
	var attempts := 0

	while not room_is_valid and attempts < MAX_GENERATION_ATTEMPTS:
		create_empty_grid()

		shape_type = force_shape if force_shape != -1 else _get_random_room_shape()
		_generate_shape(shape_type)

		room_is_valid = validate_room(shape_type)
		attempts += 1

		if force_shape != -1 and not room_is_valid:
			break

	if not room_is_valid:
		push_error(
			"Failed to generate a valid room after %d attempt(s). Shape: %d" % [
				attempts,
				shape_type,
			]
		)
		_room_transition_in_progress = false
		return

	_replace_current_room()
	if current_room == null:
		_room_transition_in_progress = false
		return

	var doors_placed := 0
	if shape_type == RoomShape.FINAL_APPROACH:
		doors_placed = 1 if _place_home_door() else 0
	else:
		doors_placed = place_normal_doors_in_grid()

	if doors_placed == 0:
		push_error("Room passed validation but no door could be placed.")
		_room_transition_in_progress = false
		return

	current_room.call(&"render", grid)

	if _is_normal_generated_room(shape_type):
		normal_rooms_visited += 1
		MemoryManager.decrease_lost(lost_reduction_per_normal_room)
		_spawn_generated_npcs()

	handle_player_spawn(shape_type)


func _replace_current_room() -> void:
	_clear_generated_actors()

	if is_instance_valid(current_room):
		current_room.process_mode = Node.PROCESS_MODE_DISABLED
		current_room.queue_free()
		current_room = null

	var room := ROOM_SCENE.instantiate() as Node2D
	if room == null:
		push_error("ROOM_SCENE root must inherit from Node2D.")
		return

	current_room = room
	add_child(current_room)
	_ensure_actors_root()
	move_child(actors_root, get_child_count() - 1)


func place_normal_doors_in_grid() -> int:
	var valid_spots := get_valid_top_door_spots()
	if valid_spots.is_empty():
		return 0

	var desired_count := _get_normal_door_count(valid_spots.size())
	var chosen_spots := _choose_spaced_door_spots(valid_spots, desired_count)

	for spot in chosen_spots:
		grid[spot.y][spot.x] = CellType.DOOR
		_spawn_door_interaction(spot, false)

	return chosen_spots.size()


func _get_normal_door_count(valid_position_count: int) -> int:
	if valid_position_count <= 0:
		return 0

	var calculated := ceili(float(valid_position_count) / float(valid_positions_per_door))
	return clampi(calculated, 1, mini(max_normal_doors, valid_position_count))


func _choose_spaced_door_spots(
	valid_spots: Array[Vector2i],
	desired_count: int
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = valid_spots.duplicate()
	candidates.shuffle()

	var chosen: Array[Vector2i] = []

	for candidate in candidates:
		if _is_far_enough_from_chosen_doors(candidate, chosen):
			chosen.append(candidate)

		if chosen.size() >= desired_count:
			return chosen

	for candidate in candidates:
		if candidate in chosen:
			continue

		chosen.append(candidate)
		if chosen.size() >= desired_count:
			break

	return chosen


func _is_far_enough_from_chosen_doors(
	candidate: Vector2i,
	chosen: Array[Vector2i]
) -> bool:
	for existing in chosen:
		var distance: int = (
			abs(candidate.x - existing.x)
			+ abs(candidate.y - existing.y)
		)
		if distance < minimum_door_spacing_cells:
			return false

	return true


func _place_home_door() -> bool:
	var valid_spots := get_valid_top_door_spots()
	if FINAL_HOME_DOOR_CELL not in valid_spots:
		push_error(
			"FINAL_HOME_DOOR_CELL is not a valid top-wall door position: %s"
			% FINAL_HOME_DOOR_CELL
		)
		return false

	grid[FINAL_HOME_DOOR_CELL.y][FINAL_HOME_DOOR_CELL.x] = CellType.HOME_DOOR
	_spawn_door_interaction(FINAL_HOME_DOOR_CELL, true)
	return true


func _spawn_door_interaction(cell: Vector2i, is_home_door: bool) -> void:
	var door := DOOR_SCENE.instantiate() as Area2D
	if door == null:
		push_error("DOOR_SCENE root must inherit from Area2D.")
		return

	current_room.add_child(door)
	door.position = Vector2(
		cell.x * TILE_SIZE + HALF_TILE_SIZE,
		cell.y * TILE_SIZE
	)

	if door.has_method(&"set_prompt_text"):
		door.call(
			&"set_prompt_text",
			"Enter Home" if is_home_door else "Enter"
		)

	if is_home_door:
		door.connect(&"entered_door", Callable(self, "_on_home_door_entered"))
	else:
		door.connect(&"entered_door", Callable(self, "_on_normal_door_entered"))


func _on_normal_door_entered() -> void:
	if _room_transition_in_progress or _ending_shown:
		return

	_play_door_sound()

	if _should_enter_final_approach():
		generate_room(RoomShape.FINAL_APPROACH)
	else:
		generate_room()


func _should_enter_final_approach() -> bool:
	if normal_rooms_visited < minimum_normal_rooms_before_home:
		return false

	if randf() < get_home_path_chance():
		return true

	home_room_failures += 1
	return false


func get_home_path_chance() -> float:
	var lost_ratio := MemoryManager.get_lost_ratio()
	var fully_lost_chance := clampf(home_chance_when_fully_lost, 0.0, 1.0)
	var not_lost_chance := clampf(home_chance_when_not_lost, 0.0, 1.0)
	var lost_based_chance := lerpf(not_lost_chance, fully_lost_chance, lost_ratio)
	var home_memory_bonus := MemoryManager.get_home_probability_bonus(
		home_memory_bonus_per_correct,
		home_memory_bonus_per_uncertain,
		maximum_home_memory_bonus
	)
	var pity_bonus := minf(
		float(home_room_failures) * pity_increase_per_failed_room,
		maximum_pity_bonus
	)

	return clampf(
		lost_based_chance + home_memory_bonus + pity_bonus,
		0.0,
		maximum_home_chance
	)


func _on_home_door_entered() -> void:
	if _ending_shown:
		return

	_play_door_sound()

	_ending_shown = true
	_room_transition_in_progress = true
	_set_player_movement_enabled(false)
	get_tree().paused = false

	if MemoryUI.has_method(&"set_game_ui_visible"):
		MemoryUI.call(&"set_game_ui_visible", true)

	if MemoryUI.has_method(&"start_final_dialog") and MemoryUI.has_signal(&"final_dialog_finished"):
		var callback := Callable(self, "_on_final_dialog_finished")
		if MemoryUI.is_connected(&"final_dialog_finished", callback):
			MemoryUI.disconnect(&"final_dialog_finished", callback)
		MemoryUI.connect(&"final_dialog_finished", callback, CONNECT_ONE_SHOT)
		MemoryUI.call(&"start_final_dialog")
		return

	_on_final_dialog_finished()


func _on_final_dialog_finished() -> void:
	get_tree().paused = false

	if MemoryUI.has_method(&"set_game_ui_visible"):
		MemoryUI.call(&"set_game_ui_visible", false)

	if is_instance_valid(current_room):
		current_room.process_mode = Node.PROCESS_MODE_DISABLED

	_play_final_exit_sequence()


func _play_final_exit_sequence() -> void:
	if not is_instance_valid(player_instance):
		_show_end_menu()
		return

	var target_position := _cell_center_global(FINAL_HOME_DOOR_CELL) + FINAL_EXIT_TARGET_OFFSET
	var walk_direction := target_position - player_instance.global_position

	_set_player_movement_enabled(false)
	player_instance.visible = true

	if player_instance.has_method(&"play_auto_walk"):
		player_instance.call(&"play_auto_walk", walk_direction)

	var tween := create_tween()
	tween.tween_property(
		player_instance,
		"global_position",
		target_position,
		FINAL_EXIT_MOVE_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		player_instance,
		"modulate:a",
		0.0,
		FINAL_EXIT_FADE_DURATION
	)

	tween.tween_callback(Callable(self, "_finish_final_exit_sequence"))


func _finish_final_exit_sequence() -> void:
	if is_instance_valid(player_instance):
		if player_instance.has_method(&"play_auto_idle"):
			player_instance.call(&"play_auto_idle")
		player_instance.visible = false

	_show_end_menu()


func _show_end_menu() -> void:
	if is_instance_valid(_end_menu_instance):
		return

	var end_menu := END_MENU_SCENE.instantiate() as CanvasLayer
	if end_menu == null:
		push_error("END_MENU_SCENE root must inherit from CanvasLayer.")
		return

	_end_menu_instance = end_menu
	add_child(end_menu)


func _build_door_sound_player() -> void:
	_ensure_audio_bus(SFX_BUS)

	_door_sound_player = AudioStreamPlayer.new()
	_door_sound_player.name = "DoorSoundPlayer"
	_door_sound_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_door_sound_player.stream = DOOR_SOUND
	_door_sound_player.bus = SFX_BUS
	_door_sound_player.volume_db = linear_to_db(maxf(door_sound_volume, 0.001))
	_door_sound_player.pitch_scale = door_sound_pitch
	add_child(_door_sound_player)


func _play_door_sound() -> void:
	if not is_instance_valid(_door_sound_player):
		_build_door_sound_player()

	_door_sound_player.stop()
	_door_sound_player.volume_db = linear_to_db(maxf(door_sound_volume, 0.001))
	_door_sound_player.pitch_scale = door_sound_pitch
	_door_sound_player.play()


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var bus_index := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)


func _spawn_generated_npcs() -> void:
	if npc_scene == null:
		return

	if randf() > clampf(npc_spawn_chance, 0.0, 1.0):
		return

	var valid_spots := get_valid_npc_spawn_spots()
	if valid_spots.is_empty():
		return

	valid_spots.shuffle()

	var count := _get_npc_count_for_current_room(valid_spots.size())
	if count <= 0:
		return

	for i in range(count):
		_spawn_generated_npc(valid_spots[i])


func _spawn_generated_npc(cell: Vector2i) -> void:
	var npc := npc_scene.instantiate() as Area2D
	if npc == null:
		push_error("NPC scene root must inherit from Area2D.")
		return

	if npc.has_method(&"setup_generated_data"):
		npc.call(&"setup_generated_data", NpcGenerator.generate_npc())

	_ensure_actors_root()
	actors_root.add_child(npc)
	npc.global_position = _cell_center_global(cell)


func _get_npc_count_for_current_room(valid_spot_count: int) -> int:
	var floor_count := _count_floor_tiles()
	var min_count := small_room_min_npcs
	var max_count := small_room_max_npcs
	var medium_threshold := maxi(0, medium_room_floor_tiles)
	var large_threshold := maxi(medium_threshold + 1, large_room_floor_tiles)

	if floor_count >= large_threshold:
		min_count = large_room_min_npcs
		max_count = large_room_max_npcs
	elif floor_count >= medium_threshold:
		min_count = medium_room_min_npcs
		max_count = medium_room_max_npcs

	min_count = clampi(min_count, 0, valid_spot_count)
	max_count = clampi(max_count, min_count, valid_spot_count)

	if max_count <= 0:
		return 0

	return randi_range(min_count, max_count)


func get_valid_npc_spawn_spots() -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var blocked_cells := _get_npc_blocked_reference_cells()

	for y in range(ROOM_HEIGHT):
		for x in range(ROOM_WIDTH):
			var cell := Vector2i(x, y)
			if grid[y][x] != CellType.FLOOR:
				continue

			if not _is_cell_clear_of_references(cell, blocked_cells):
				continue

			spots.append(cell)

	return spots


func _get_npc_blocked_reference_cells() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = get_valid_bottom_spawn_spots()

	for y in range(ROOM_HEIGHT):
		for x in range(ROOM_WIDTH):
			if grid[y][x] == CellType.DOOR or grid[y][x] == CellType.HOME_DOOR:
				blocked.append(Vector2i(x, y))

	return blocked


func _is_cell_clear_of_references(
	candidate: Vector2i,
	references: Array[Vector2i]
) -> bool:
	for reference in references:
		var distance: int = (
			abs(candidate.x - reference.x)
			+ abs(candidate.y - reference.y)
		)

		if distance <= npc_clearance_cells:
			return false

	return true


func handle_player_spawn(shape_type: int) -> void:
	if not _ensure_player_exists():
		_room_transition_in_progress = false
		return

	if shape_type == RoomShape.INITIAL_SPAWN:
		player_instance.global_position = _cell_center_global(INITIAL_SPAWN_CELL)
		player_instance.modulate.a = 1.0
		_finish_room_transition()
		return

	var valid_spawns := get_valid_bottom_spawn_spots()
	if valid_spawns.is_empty():
		push_error("Generated room has no valid player entrance.")
		_finish_room_transition()
		return

	var chosen_spawn: Vector2i = valid_spawns.pick_random()
	var target_position := _cell_center_global(chosen_spawn)

	_set_player_movement_enabled(false)
	player_instance.global_position = target_position + ENTRY_START_OFFSET
	player_instance.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(
		player_instance,
		"global_position",
		target_position,
		ENTRY_MOVE_DURATION
	).set_trans(Tween.TRANS_SINE)

	tween.tween_property(
		player_instance,
		"modulate:a",
		1.0,
		ENTRY_FADE_DURATION
	)

	tween.tween_callback(Callable(self, "_finish_room_transition"))


func _ensure_player_exists() -> bool:
	if is_instance_valid(player_instance):
		return true

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	if player == null:
		push_error("PLAYER_SCENE root must inherit from CharacterBody2D.")
		return false

	player_instance = player
	_ensure_actors_root()
	actors_root.add_child(player_instance)
	return true


func _ensure_actors_root() -> void:
	if is_instance_valid(actors_root):
		return

	actors_root = Node2D.new()
	actors_root.name = "Actors"
	actors_root.y_sort_enabled = true
	add_child(actors_root)


func _show_tutorial() -> void:
	if not is_instance_valid(tutorial_overlay):
		tutorial_overlay = get_node_or_null("TutorialOverlay") as CanvasLayer

	if not is_instance_valid(tutorial_overlay):
		tutorial_overlay = TUTORIAL_OVERLAY_SCENE.instantiate() as CanvasLayer
		if tutorial_overlay == null:
			push_error("Tutorial overlay scene root must inherit from CanvasLayer.")
			return
		add_child(tutorial_overlay)

	move_child(tutorial_overlay, get_child_count() - 1)

	if tutorial_overlay.has_method(&"start_tutorial"):
		tutorial_overlay.call(&"start_tutorial")


func _clear_generated_actors() -> void:
	if not is_instance_valid(actors_root):
		return

	for child in actors_root.get_children():
		if child == player_instance:
			continue

		actors_root.remove_child(child)
		child.queue_free()


func _set_player_movement_enabled(enabled: bool) -> void:
	if not is_instance_valid(player_instance):
		return

	if player_instance.has_method(&"set_movement_enabled"):
		player_instance.call(&"set_movement_enabled", enabled)
	else:
		player_instance.set_physics_process(enabled)
		if not enabled:
			player_instance.velocity = Vector2.ZERO


func _finish_room_transition() -> void:
	_set_player_movement_enabled(true)
	_room_transition_in_progress = false


func create_empty_grid() -> void:
	grid.clear()

	for _y in range(ROOM_HEIGHT):
		var row: Array[int] = []
		row.resize(ROOM_WIDTH)
		row.fill(CellType.EMPTY)
		grid.append(row)


func _get_random_room_shape() -> int:
	return int(NORMAL_ROOM_SHAPES.pick_random())


func _generate_shape(shape_type: int) -> void:
	match shape_type:
		RoomShape.RECTANGLE:
			generate_rectangle()
		RoomShape.L_SHAPE:
			generate_l_shape()
		RoomShape.U_SHAPE:
			generate_u_shape()
		RoomShape.PLUS_SHAPE:
			generate_plus_shape()
		RoomShape.T_SHAPE:
			generate_t_shape()
		RoomShape.H_SHAPE:
			generate_h_shape()
		RoomShape.MANUAL:
			generate_manual_shape()
		RoomShape.INITIAL_SPAWN:
			generate_initial_spawn()
		RoomShape.FINAL_APPROACH:
			generate_final_approach()
		_:
			push_error("Unknown room shape: %d" % shape_type)


func _is_normal_generated_room(shape_type: int) -> bool:
	return shape_type in NORMAL_ROOM_SHAPES


func generate_initial_spawn() -> void:
	for y in range(6, 12):
		for x in range(7, 13):
			grid[y][x] = CellType.FLOOR


func generate_rectangle() -> void:
	_fill_room_rect(_get_random_room_bounds(5, 4))


func generate_l_shape() -> void:
	var bounds := _get_random_room_bounds(6, 5)
	var vertical_width := _random_arm_thickness(bounds.size.x)
	var horizontal_height := _random_arm_thickness(bounds.size.y)

	match randi_range(0, 3):
		0:
			_fill_room_rect(Rect2i(
				bounds.position,
				Vector2i(vertical_width, bounds.size.y)
			))
			_fill_room_rect(Rect2i(
				bounds.position,
				Vector2i(bounds.size.x, horizontal_height)
			))
		1:
			_fill_room_rect(Rect2i(
				Vector2i(bounds.end.x - vertical_width, bounds.position.y),
				Vector2i(vertical_width, bounds.size.y)
			))
			_fill_room_rect(Rect2i(
				bounds.position,
				Vector2i(bounds.size.x, horizontal_height)
			))
		2:
			_fill_room_rect(Rect2i(
				bounds.position,
				Vector2i(vertical_width, bounds.size.y)
			))
			_fill_room_rect(Rect2i(
				Vector2i(bounds.position.x, bounds.end.y - horizontal_height),
				Vector2i(bounds.size.x, horizontal_height)
			))
		_:
			_fill_room_rect(Rect2i(
				Vector2i(bounds.end.x - vertical_width, bounds.position.y),
				Vector2i(vertical_width, bounds.size.y)
			))
			_fill_room_rect(Rect2i(
				Vector2i(bounds.position.x, bounds.end.y - horizontal_height),
				Vector2i(bounds.size.x, horizontal_height)
			))


func generate_u_shape() -> void:
	var bounds := _get_random_room_bounds(7, 6)
	var orientation := randi_range(0, 3)

	if orientation == 0 or orientation == 1:
		var side_width := _random_side_thickness(bounds.size.x)
		var bridge_height := _random_arm_thickness(bounds.size.y)

		_fill_room_rect(Rect2i(
			bounds.position,
			Vector2i(side_width, bounds.size.y)
		))
		_fill_room_rect(Rect2i(
			Vector2i(bounds.end.x - side_width, bounds.position.y),
			Vector2i(side_width, bounds.size.y)
		))

		var bridge_y := bounds.end.y - bridge_height if orientation == 0 else bounds.position.y
		_fill_room_rect(Rect2i(
			Vector2i(bounds.position.x, bridge_y),
			Vector2i(bounds.size.x, bridge_height)
		))
		return

	var side_height := _random_side_thickness(bounds.size.y)
	var bridge_width := _random_arm_thickness(bounds.size.x)

	_fill_room_rect(Rect2i(
		bounds.position,
		Vector2i(bounds.size.x, side_height)
	))
	_fill_room_rect(Rect2i(
		Vector2i(bounds.position.x, bounds.end.y - side_height),
		Vector2i(bounds.size.x, side_height)
	))

	var bridge_x := bounds.end.x - bridge_width if orientation == 2 else bounds.position.x
	_fill_room_rect(Rect2i(
		Vector2i(bridge_x, bounds.position.y),
		Vector2i(bridge_width, bounds.size.y)
	))


func generate_plus_shape() -> void:
	var bounds := _get_random_room_bounds(7, 7)
	var vertical_width := _random_arm_thickness(bounds.size.x)
	var horizontal_height := _random_arm_thickness(bounds.size.y)
	var vertical_x := _random_band_start(
		bounds.position.x,
		bounds.size.x,
		vertical_width,
		2
	)
	var horizontal_y := _random_band_start(
		bounds.position.y,
		bounds.size.y,
		horizontal_height,
		2
	)

	_fill_room_rect(Rect2i(
		Vector2i(vertical_x, bounds.position.y),
		Vector2i(vertical_width, bounds.size.y)
	))
	_fill_room_rect(Rect2i(
		Vector2i(bounds.position.x, horizontal_y),
		Vector2i(bounds.size.x, horizontal_height)
	))


func generate_t_shape() -> void:
	var bounds := _get_random_room_bounds(7, 6)

	match randi_range(0, 3):
		0:
			var top_stem_width := _random_arm_thickness(bounds.size.x)
			var top_cross_height := _random_arm_thickness(bounds.size.y)
			var top_stem_x := _random_band_start(
				bounds.position.x,
				bounds.size.x,
				top_stem_width,
				2
			)
			_fill_room_rect(Rect2i(
				bounds.position,
				Vector2i(bounds.size.x, top_cross_height)
			))
			_fill_room_rect(Rect2i(
				Vector2i(top_stem_x, bounds.position.y),
				Vector2i(top_stem_width, bounds.size.y)
			))
		1:
			var bottom_stem_width := _random_arm_thickness(bounds.size.x)
			var bottom_cross_height := _random_arm_thickness(bounds.size.y)
			var bottom_stem_x := _random_band_start(
				bounds.position.x,
				bounds.size.x,
				bottom_stem_width,
				2
			)
			_fill_room_rect(Rect2i(
				Vector2i(bounds.position.x, bounds.end.y - bottom_cross_height),
				Vector2i(bounds.size.x, bottom_cross_height)
			))
			_fill_room_rect(Rect2i(
				Vector2i(bottom_stem_x, bounds.position.y),
				Vector2i(bottom_stem_width, bounds.size.y)
			))
		2:
			var left_stem_height := _random_arm_thickness(bounds.size.y)
			var left_cross_width := _random_arm_thickness(bounds.size.x)
			var left_stem_y := _random_band_start(
				bounds.position.y,
				bounds.size.y,
				left_stem_height,
				2
			)
			_fill_room_rect(Rect2i(
				bounds.position,
				Vector2i(left_cross_width, bounds.size.y)
			))
			_fill_room_rect(Rect2i(
				Vector2i(bounds.position.x, left_stem_y),
				Vector2i(bounds.size.x, left_stem_height)
			))
		_:
			var right_stem_height := _random_arm_thickness(bounds.size.y)
			var right_cross_width := _random_arm_thickness(bounds.size.x)
			var right_stem_y := _random_band_start(
				bounds.position.y,
				bounds.size.y,
				right_stem_height,
				2
			)
			_fill_room_rect(Rect2i(
				Vector2i(bounds.end.x - right_cross_width, bounds.position.y),
				Vector2i(right_cross_width, bounds.size.y)
			))
			_fill_room_rect(Rect2i(
				Vector2i(bounds.position.x, right_stem_y),
				Vector2i(bounds.size.x, right_stem_height)
			))


func generate_h_shape() -> void:
	var bounds := _get_random_room_bounds(8, 6)

	if randf() < 0.5:
		var side_width := _random_side_thickness(bounds.size.x)
		var bridge_height := _random_arm_thickness(bounds.size.y)
		var bridge_y := _random_band_start(
			bounds.position.y,
			bounds.size.y,
			bridge_height,
			2
		)

		_fill_room_rect(Rect2i(
			bounds.position,
			Vector2i(side_width, bounds.size.y)
		))
		_fill_room_rect(Rect2i(
			Vector2i(bounds.end.x - side_width, bounds.position.y),
			Vector2i(side_width, bounds.size.y)
		))
		_fill_room_rect(Rect2i(
			Vector2i(bounds.position.x, bridge_y),
			Vector2i(bounds.size.x, bridge_height)
		))
		return

	var side_height := _random_side_thickness(bounds.size.y)
	var bridge_width := _random_arm_thickness(bounds.size.x)
	var bridge_x := _random_band_start(
		bounds.position.x,
		bounds.size.x,
		bridge_width,
		2
	)

	_fill_room_rect(Rect2i(
		bounds.position,
		Vector2i(bounds.size.x, side_height)
	))
	_fill_room_rect(Rect2i(
		Vector2i(bounds.position.x, bounds.end.y - side_height),
		Vector2i(bounds.size.x, side_height)
	))
	_fill_room_rect(Rect2i(
		Vector2i(bridge_x, bounds.position.y),
		Vector2i(bridge_width, bounds.size.y)
	))


func generate_manual_shape() -> void:
	for y in range(5, 8):
		for x in range(5, 8):
			grid[y][x] = CellType.FLOOR


func generate_final_approach() -> void:
	for y in range(4, 12):
		for x in range(7, 13):
			grid[y][x] = CellType.FLOOR


func _get_random_room_bounds(required_width: int, required_height: int) -> Rect2i:
	var available_width := ROOM_WIDTH - ROOM_MARGIN_LEFT - ROOM_MARGIN_RIGHT
	var available_height := ROOM_HEIGHT - ROOM_MARGIN_TOP - ROOM_MARGIN_BOTTOM

	var min_width := clampi(
		maxi(required_width, minimum_room_width),
		1,
		available_width
	)
	var min_height := clampi(
		maxi(required_height, minimum_room_height),
		1,
		available_height
	)
	var max_width := clampi(
		maxi(maximum_room_width, min_width),
		min_width,
		available_width
	)
	var max_height := clampi(
		maxi(maximum_room_height, min_height),
		min_height,
		available_height
	)

	var width := randi_range(min_width, max_width)
	var height := randi_range(min_height, max_height)
	var x := randi_range(
		ROOM_MARGIN_LEFT,
		ROOM_WIDTH - ROOM_MARGIN_RIGHT - width
	)
	var y := randi_range(
		ROOM_MARGIN_TOP,
		ROOM_HEIGHT - ROOM_MARGIN_BOTTOM - height
	)

	return Rect2i(x, y, width, height)


func _fill_room_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or x >= ROOM_WIDTH:
				continue
			if y < 0 or y >= ROOM_HEIGHT:
				continue

			grid[y][x] = CellType.FLOOR


func _random_arm_thickness(span: int) -> int:
	var max_thickness := maxi(2, mini(4, span - 2))
	return randi_range(2, max_thickness)


func _random_side_thickness(span: int) -> int:
	var max_thickness := maxi(2, mini(3, floori(float(span - 2) / 2.0)))
	return randi_range(2, max_thickness)


func _random_band_start(
	origin: int,
	total_size: int,
	band_size: int,
	preferred_side_space: int
) -> int:
	var free_space := maxi(0, total_size - band_size)
	var side_space := mini(preferred_side_space, floori(float(free_space) / 2.0))
	var minimum_start := origin + side_space
	var maximum_start := origin + total_size - band_size - side_space

	if maximum_start < minimum_start:
		return origin + floori(float(free_space) / 2.0)

	return randi_range(minimum_start, maximum_start)


func validate_room(shape_type: int) -> bool:
	var floor_count := _count_floor_tiles()
	if floor_count == 0:
		return false
	if _is_normal_generated_room(shape_type) and floor_count < minimum_walkable_floor_tiles:
		return false

	if not _is_floor_connected(floor_count):
		return false

	if not _has_valid_inner_corner_heights():
		return false
	if not _has_valid_vertical_side_wall_heights():
		return false

	var valid_door_spots := get_valid_top_door_spots()
	if valid_door_spots.is_empty():
		return false

	if (
		shape_type == RoomShape.FINAL_APPROACH
		and FINAL_HOME_DOOR_CELL not in valid_door_spots
	):
		return false

	if (
		shape_type != RoomShape.INITIAL_SPAWN
		and get_valid_bottom_spawn_spots().is_empty()
	):
		return false

	return true


func _count_floor_tiles() -> int:
	var count := 0

	for y in range(ROOM_HEIGHT):
		for x in range(ROOM_WIDTH):
			if grid[y][x] == CellType.FLOOR:
				count += 1

	return count


func _is_floor_connected(expected_floor_count: int) -> bool:
	var start := _find_first_floor()
	if start == Vector2i(-1, -1):
		return false

	var to_check: Array[Vector2i] = []
	to_check.append(start)

	var visited: Dictionary = {}
	visited[start] = true

	while not to_check.is_empty():
		var current: Vector2i = to_check.pop_back()

		for direction in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction

			if not is_floor(neighbor.x, neighbor.y):
				continue
			if visited.has(neighbor):
				continue

			visited[neighbor] = true
			to_check.append(neighbor)

	return visited.size() == expected_floor_count


func _find_first_floor() -> Vector2i:
	for y in range(ROOM_HEIGHT):
		for x in range(ROOM_WIDTH):
			if grid[y][x] == CellType.FLOOR:
				return Vector2i(x, y)

	return Vector2i(-1, -1)


func _has_valid_inner_corner_heights() -> bool:
	for y in range(ROOM_HEIGHT):
		for x in range(ROOM_WIDTH):
			if grid[y][x] != CellType.EMPTY:
				continue

			var floor_down := is_floor(x, y + 1)
			var floor_left := is_floor(x - 1, y)
			var floor_right := is_floor(x + 1, y)

			if floor_down and floor_left:
				if not _has_side_wall_extension(x, y, -1):
					return false
			if floor_down and floor_right:
				if not _has_side_wall_extension(x, y, 1):
					return false

	return true


func _has_side_wall_extension(x: int, y: int, side_direction: int) -> bool:
	var extension_y := y - 1
	if extension_y < 0:
		return false
	if grid[extension_y][x] != CellType.EMPTY:
		return false

	return is_floor(x + side_direction, extension_y)


func _has_valid_vertical_side_wall_heights() -> bool:
	for x in range(ROOM_WIDTH):
		var y := 0
		while y < ROOM_HEIGHT:
			if grid[y][x] != CellType.EMPTY:
				y += 1
				continue

			var start_y := y
			while y < ROOM_HEIGHT and grid[y][x] == CellType.EMPTY:
				y += 1

			var end_y := y
			var run_height := end_y - start_y
			if run_height >= MIN_VERTICAL_SIDE_WALL_HEIGHT:
				continue
			if not is_floor(x, start_y - 1) or not is_floor(x, end_y):
				continue
			if _empty_run_touches_side_floor(x, start_y, end_y):
				return false

	return true


func _empty_run_touches_side_floor(x: int, start_y: int, end_y: int) -> bool:
	for y in range(start_y, end_y):
		if is_floor(x - 1, y) or is_floor(x + 1, y):
			return true

	return false


func get_valid_top_door_spots() -> Array[Vector2i]:
	var spots: Array[Vector2i] = []

	for y in range(1, ROOM_HEIGHT - 1):
		for x in range(1, ROOM_WIDTH - 1):
			if grid[y][x] != CellType.EMPTY:
				continue
			if not is_floor(x, y + 1):
				continue

			if is_floor(x - 1, y) or is_floor(x + 1, y):
				continue

			spots.append(Vector2i(x, y))

	return spots


func get_valid_bottom_spawn_spots() -> Array[Vector2i]:
	var spots: Array[Vector2i] = []

	for y in range(1, ROOM_HEIGHT - 1):
		for x in range(1, ROOM_WIDTH - 1):
			if not is_floor(x, y):
				continue
			if grid[y + 1][x] != CellType.EMPTY:
				continue

			var wall_x := x
			var wall_y := y + 1

			var wall_floor_up := is_floor(wall_x, wall_y - 1)
			var wall_floor_down := is_floor(wall_x, wall_y + 1)
			var wall_floor_left := is_floor(wall_x - 1, wall_y)
			var wall_floor_right := is_floor(wall_x + 1, wall_y)

			var is_inner_corner := (
				(wall_floor_up or wall_floor_down)
				and (wall_floor_left or wall_floor_right)
			)

			if not is_inner_corner:
				spots.append(Vector2i(x, y))

	return spots


func is_floor(x: int, y: int) -> bool:
	if x < 0 or x >= ROOM_WIDTH:
		return false
	if y < 0 or y >= ROOM_HEIGHT:
		return false

	return grid[y][x] == CellType.FLOOR


func _cell_center_local(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + HALF_TILE_SIZE,
		cell.y * TILE_SIZE + HALF_TILE_SIZE
	)


func _cell_center_global(cell: Vector2i) -> Vector2:
	if current_room == null:
		return _cell_center_local(cell)

	return current_room.to_global(_cell_center_local(cell))
