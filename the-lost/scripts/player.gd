extends CharacterBody2D

@export var speed: float = 800.0
@export_range(0.01, 1.0, 0.01) var walk_frame_duration := 0.15
@export_range(0.01, 2.0, 0.01) var idle_frame_duration := 0.45
@export_range(0.0, 1.0, 0.01) var walking_sound_volume := 0.35

const WASD_BINDINGS := {
	&"ui_left": KEY_A,
	&"ui_right": KEY_D,
	&"ui_up": KEY_W,
	&"ui_down": KEY_S,
}
const ANIMATION_IDLE := "idle"
const ANIMATION_FRONT_WALK := "front_walk"
const ANIMATION_BACK_WALK := "back_walk"
const ANIMATION_LEFT_WALK := "left_walk"
const ANIMATION_RIGHT_WALK := "right_walk"
const NORMAL_FRAME_SCALE := Vector2.ONE
const DOUBLE_RES_FRAME_SCALE := Vector2(0.5, 0.5)
const WALKING_SOUND = preload("res://assets/SFX/walking.mp3")
const SFX_BUS := "SFX"

const IDLE_FRAMES := [
	preload("res://assets/animations/idle/idle-1.png"),
	preload("res://assets/animations/idle/idle-2.png"),
	preload("res://assets/animations/idle/idle-3.png"),
	preload("res://assets/animations/idle/idle-4.png"),
	preload("res://assets/animations/idle/idle-5.png"),
	preload("res://assets/animations/idle/idle-6.png"),
]
const FRONT_WALK_FRAMES := [
	preload("res://assets/animations/front-walk/front-1.png"),
	preload("res://assets/animations/front-walk/front-2.png"),
	preload("res://assets/animations/front-walk/front-3.png"),
	preload("res://assets/animations/front-walk/front-4.png"),
	preload("res://assets/animations/front-walk/front-5.png"),
	preload("res://assets/animations/front-walk/front-6.png"),
]
const BACK_WALK_FRAMES := [
	preload("res://assets/animations/back-walk/back-1.png"),
	preload("res://assets/animations/back-walk/back-2.png"),
	preload("res://assets/animations/back-walk/back-3.png"),
	preload("res://assets/animations/back-walk/back-4.png"),
	preload("res://assets/animations/back-walk/back-5.png"),
	preload("res://assets/animations/back-walk/back-6.png"),
]
const LEFT_WALK_FRAMES := [
	preload("res://assets/animations/left-walk/left-1.png"),
	preload("res://assets/animations/left-walk/left-2.png"),
	preload("res://assets/animations/left-walk/left-3.png"),
	preload("res://assets/animations/left-walk/left-4.png"),
	preload("res://assets/animations/left-walk/left-5.png"),
	preload("res://assets/animations/left-walk/left-6.png"),
]
const RIGHT_WALK_FRAMES := [
	preload("res://assets/animations/right-walk/right-1.png"),
	preload("res://assets/animations/right-walk/right-2.png"),
	preload("res://assets/animations/right-walk/right-3.png"),
	preload("res://assets/animations/right-walk/right-4.png"),
	preload("res://assets/animations/right-walk/right-5.png"),
	preload("res://assets/animations/right-walk/right-6.png"),
]

var movement_enabled: bool = true
var _current_animation := ""
var _frame_index := 0
var _frame_timer := 0.0
var _force_animation := false
var _forced_animation_direction := Vector2.ZERO
var _walking_sound_player: AudioStreamPlayer2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_in_group(&"player"):
		add_to_group(&"player")
	_ensure_wasd_bindings()
	_build_walking_sound_player()
	_play_animation(ANIMATION_IDLE)


func _physics_process(delta: float) -> void:
	if get_tree().paused and not _force_animation:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO, delta)
		_update_walking_sound(false)
		return

	if not movement_enabled:
		velocity = Vector2.ZERO
		var animation_direction := _forced_animation_direction if _force_animation else Vector2.ZERO
		_update_animation(animation_direction, delta)
		_update_walking_sound(animation_direction.length_squared() > 0.001)
		return

	var input_direction := Input.get_vector(
		&"ui_left",
		&"ui_right",
		&"ui_up",
		&"ui_down"
	)

	velocity = input_direction * speed
	_update_animation(input_direction, delta)
	_update_walking_sound(input_direction.length_squared() > 0.001)
	move_and_slide()


func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled

	if enabled:
		_force_animation = false
		_forced_animation_direction = Vector2.ZERO

	if not enabled:
		velocity = Vector2.ZERO
		if not _force_animation:
			_play_animation(ANIMATION_IDLE)
			_update_walking_sound(false)


func play_auto_walk(direction: Vector2) -> void:
	_force_animation = true
	_forced_animation_direction = direction.normalized()
	_play_animation(_get_animation_for_direction(_forced_animation_direction))
	_update_walking_sound(_forced_animation_direction.length_squared() > 0.001)


func play_auto_idle() -> void:
	_force_animation = false
	_forced_animation_direction = Vector2.ZERO
	_play_animation(ANIMATION_IDLE)
	_update_walking_sound(false)


func _ensure_wasd_bindings() -> void:
	for action in WASD_BINDINGS.keys():
		var keycode := int(WASD_BINDINGS[action])
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if _action_has_physical_key(action, keycode):
			continue

		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


func _build_walking_sound_player() -> void:
	_ensure_audio_bus(SFX_BUS)

	_walking_sound_player = AudioStreamPlayer2D.new()
	_walking_sound_player.name = "WalkingSoundPlayer"
	_walking_sound_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_walking_sound_player.stream = WALKING_SOUND
	_walking_sound_player.bus = SFX_BUS
	_walking_sound_player.max_distance = 1600.0
	add_child(_walking_sound_player)


func _update_walking_sound(should_play: bool) -> void:
	if not is_instance_valid(_walking_sound_player):
		_build_walking_sound_player()

	_walking_sound_player.volume_db = linear_to_db(maxf(walking_sound_volume, 0.001))

	if should_play:
		if not _walking_sound_player.playing:
			_walking_sound_player.play()
	else:
		_walking_sound_player.stop()


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var bus_index := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)


func _action_has_physical_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true

	return false


func _update_animation(input_direction: Vector2, delta: float) -> void:
	var next_animation := _get_animation_for_direction(input_direction)
	_play_animation(next_animation)

	var frames := _get_frames_for_animation(_current_animation)
	if frames.is_empty():
		return

	_frame_timer += delta
	var frame_duration := _get_frame_duration(_current_animation)

	while _frame_timer >= frame_duration:
		_frame_timer -= frame_duration
		_frame_index = (_frame_index + 1) % frames.size()
		_apply_animation_frame()


func _play_animation(animation_name: String) -> void:
	if _current_animation == animation_name:
		return

	_current_animation = animation_name
	_frame_index = 0
	_frame_timer = 0.0
	_apply_animation_frame()


func _apply_animation_frame() -> void:
	if sprite == null:
		return

	var frames := _get_frames_for_animation(_current_animation)
	if frames.is_empty():
		return

	_frame_index = clampi(_frame_index, 0, frames.size() - 1)
	sprite.texture = frames[_frame_index]
	sprite.scale = _get_scale_for_animation(_current_animation)


func _get_animation_for_direction(input_direction: Vector2) -> String:
	if input_direction.length_squared() <= 0.001:
		return ANIMATION_IDLE

	if absf(input_direction.x) > absf(input_direction.y):
		return ANIMATION_RIGHT_WALK if input_direction.x > 0.0 else ANIMATION_LEFT_WALK

	return ANIMATION_FRONT_WALK if input_direction.y > 0.0 else ANIMATION_BACK_WALK


func _get_frames_for_animation(animation_name: String) -> Array:
	match animation_name:
		ANIMATION_FRONT_WALK:
			return FRONT_WALK_FRAMES
		ANIMATION_BACK_WALK:
			return BACK_WALK_FRAMES
		ANIMATION_LEFT_WALK:
			return LEFT_WALK_FRAMES
		ANIMATION_RIGHT_WALK:
			return RIGHT_WALK_FRAMES
		_:
			return IDLE_FRAMES


func _get_frame_duration(animation_name: String) -> float:
	if animation_name == ANIMATION_IDLE:
		return idle_frame_duration

	return walk_frame_duration


func _get_scale_for_animation(animation_name: String) -> Vector2:
	match animation_name:
		ANIMATION_BACK_WALK, ANIMATION_LEFT_WALK, ANIMATION_RIGHT_WALK:
			return DOUBLE_RES_FRAME_SCALE
		_:
			return NORMAL_FRAME_SCALE
