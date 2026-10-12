extends Area2D

signal entered_door

@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "Enter"

@onready var prompt_label: Label = $Label
@onready var prompt_sprite: Sprite2D = $PromptSprite

var _player_in_range: bool = false
var _has_interact_action: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_has_interact_action = InputMap.has_action(interact_action)
	if not _has_interact_action:
		push_warning(
			"Input action '%s' does not exist. Falling back to the E key. " % interact_action
			+ "Add the action in Project Settings > Input Map when you can."
		)

	_refresh_prompt()
	_set_player_in_range(false)


func set_prompt_text(value: String) -> void:
	prompt_text = value
	if is_node_ready():
		_refresh_prompt()


func _refresh_prompt() -> void:
	prompt_label.text = prompt_text


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return

	_set_player_in_range(true)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return

	_set_player_in_range(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return

	var interact_pressed := false

	if _has_interact_action:
		interact_pressed = event.is_action_pressed(interact_action)
	elif event is InputEventKey:
		interact_pressed = (
			event.pressed
			and not event.echo
			and event.physical_keycode == KEY_E
		)

	if not interact_pressed:
		return

	_set_player_in_range(false)
	entered_door.emit()
	get_viewport().set_input_as_handled()


func _set_player_in_range(in_range: bool) -> void:
	_player_in_range = in_range
	if prompt_sprite != null and prompt_sprite.texture != null:
		prompt_sprite.visible = in_range
		prompt_label.visible = false
	else:
		prompt_label.visible = in_range
