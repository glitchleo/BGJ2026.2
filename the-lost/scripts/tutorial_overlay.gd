extends CanvasLayer

signal tutorial_finished

@export var frames: Array[Texture2D] = []
@export var pause_game := true

@onready var root: Control = $Root
@onready var frame_texture: TextureRect = $Root/FrameTexture

var _frame_index := 0
var _is_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_STOP


func start_tutorial() -> void:
	if frames.is_empty():
		_finish_tutorial()
		return

	_frame_index = 0
	_is_active = true
	visible = true
	root.visible = true

	if pause_game:
		get_tree().paused = true

	_refresh_frame()


func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	if not _should_advance(event):
		return

	get_viewport().set_input_as_handled()
	_advance_frame()


func _advance_frame() -> void:
	_frame_index += 1
	if _frame_index >= frames.size():
		_finish_tutorial()
		return

	_refresh_frame()


func _refresh_frame() -> void:
	frame_texture.texture = frames[_frame_index]


func _finish_tutorial() -> void:
	_is_active = false
	visible = false
	if root != null:
		root.visible = false

	if pause_game:
		get_tree().paused = false

	tutorial_finished.emit()


func _should_advance(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed

	return false
