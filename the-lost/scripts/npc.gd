extends Area2D

const NPC_VISUAL_ASSETS = preload("res://scripts/npc_visual_assets.gd")
const DEFAULT_BODY_PATH := "res://assets/npc/body/bb.png"
const DEFAULT_BODY_TEXTURE = preload("res://assets/npc/body/bb.png")
const BACK_HAIR_SPRITE_NAME := "BackHairSprite"
const BOTTOM_SPRITE_NAME := "BottomSprite"
const TOP_SPRITE_NAME := "TopSprite"
const FRONT_HAIR_SPRITE_NAME := "FrontHairSprite"
const NPC_WORLD_Z_INDEX := 1
const SPRITE_LAYER_Z_INDEX := 0

@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "E  Talk"

var npc_data: Dictionary = {}
var player_in_range := false
var conversation_used := false

@onready var body_sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = get_node_or_null("NameLabel") as Label
@onready var prompt_label: Label = get_node_or_null("PromptLabel") as Label
@onready var prompt_sprite: Sprite2D = get_node_or_null("PromptSprite") as Sprite2D

var _has_interact_action := false
var _back_hair_sprite: Sprite2D
var _bottom_sprite: Sprite2D
var _top_sprite: Sprite2D
var _front_hair_sprite: Sprite2D


func setup_generated_data(data: Dictionary) -> void:
	npc_data = data.duplicate(true)
	if body_sprite != null:
		_ensure_appearance_sprites()
		_apply_appearance()


func _ready() -> void:
	if npc_data.is_empty():
		npc_data = NpcGenerator.generate_npc()

	z_index = NPC_WORLD_Z_INDEX
	_has_interact_action = InputMap.has_action(interact_action)
	_ensure_appearance_sprites()
	_apply_appearance()

	if name_label != null:
		name_label.text = str(npc_data.get("name", "???"))
		name_label.visible = false
		name_label.z_index = 10
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.z_index = 10
	if prompt_sprite != null:
		prompt_sprite.z_index = 10
	_refresh_prompt()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return

	player_in_range = true
	_refresh_prompt()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return

	player_in_range = false
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or conversation_used:
		return

	if not _is_interact_pressed(event):
		return

	conversation_used = true
	_refresh_prompt()
	MemoryUI.start_npc_dialog(npc_data)
	get_viewport().set_input_as_handled()


func _is_interact_pressed(event: InputEvent) -> bool:
	if _has_interact_action:
		return event.is_action_pressed(interact_action)

	if event is InputEventKey:
		return (
			event.pressed
			and not event.echo
			and event.physical_keycode == KEY_E
		)

	return false


func _refresh_prompt() -> void:
	var should_show := player_in_range and not conversation_used
	if prompt_sprite != null and prompt_sprite.texture != null:
		prompt_sprite.visible = should_show
		if prompt_label != null:
			prompt_label.visible = false
	elif prompt_label != null:
		prompt_label.visible = should_show


func _ensure_appearance_sprites() -> void:
	_back_hair_sprite = _get_or_create_sprite(BACK_HAIR_SPRITE_NAME)
	_bottom_sprite = _get_or_create_sprite(BOTTOM_SPRITE_NAME)
	_top_sprite = _get_or_create_sprite(TOP_SPRITE_NAME)
	_front_hair_sprite = _get_or_create_sprite(FRONT_HAIR_SPRITE_NAME)

	_back_hair_sprite.z_index = SPRITE_LAYER_Z_INDEX
	body_sprite.z_index = SPRITE_LAYER_Z_INDEX
	_bottom_sprite.z_index = SPRITE_LAYER_Z_INDEX
	_top_sprite.z_index = SPRITE_LAYER_Z_INDEX
	_front_hair_sprite.z_index = SPRITE_LAYER_Z_INDEX

	move_child(_back_hair_sprite, 0)
	move_child(body_sprite, 1)
	move_child(_bottom_sprite, 2)
	move_child(_top_sprite, 3)
	move_child(_front_hair_sprite, 4)


func _get_or_create_sprite(sprite_name: String) -> Sprite2D:
	var sprite := get_node_or_null(sprite_name) as Sprite2D
	if sprite != null:
		return sprite

	sprite = Sprite2D.new()
	sprite.name = sprite_name
	add_child(sprite)
	return sprite


func _apply_appearance() -> void:
	if body_sprite == null:
		return

	var appearance: Dictionary = npc_data.get("appearance", {})
	var body_path := str(appearance.get("body", DEFAULT_BODY_PATH))
	var body_texture := _load_texture(body_path)
	body_sprite.texture = body_texture if body_texture != null else DEFAULT_BODY_TEXTURE
	body_sprite.z_index = SPRITE_LAYER_Z_INDEX

	_set_optional_sprite_texture(
		_back_hair_sprite,
		str(appearance.get("back_hair", "")),
		SPRITE_LAYER_Z_INDEX
	)
	_set_optional_sprite_texture(
		_bottom_sprite,
		str(appearance.get("bottom", "")),
		SPRITE_LAYER_Z_INDEX
	)
	_set_optional_sprite_texture(
		_top_sprite,
		str(appearance.get("top", "")),
		SPRITE_LAYER_Z_INDEX
	)
	_set_optional_sprite_texture(
		_front_hair_sprite,
		str(appearance.get("front_hair", "")),
		SPRITE_LAYER_Z_INDEX
	)


func _set_optional_sprite_texture(
	sprite: Sprite2D,
	texture_path: String,
	z_index: int
) -> void:
	if sprite == null:
		return

	sprite.z_index = z_index

	if texture_path.is_empty():
		sprite.texture = null
		sprite.visible = false
		return

	var texture := _load_texture(texture_path)
	sprite.texture = texture
	sprite.visible = texture != null


func _load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null

	var texture: Texture2D = NPC_VISUAL_ASSETS.get_texture(texture_path)
	if texture != null:
		return texture

	texture = load(texture_path) as Texture2D
	if texture == null:
		push_warning("NPC: Could not load texture %s" % texture_path)

	return texture
