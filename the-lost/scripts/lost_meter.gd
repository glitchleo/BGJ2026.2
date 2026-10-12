extends Control

@export var meter_size := Vector2(392.0, 71.0)

@onready var container_texture: TextureRect = $Container
@onready var fill_clip: Control = $FillClip
@onready var fill_texture: TextureRect = $FillClip/Filling

var _minimum := 0.0
var _maximum := 100.0
var _value := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = meter_size
	resized.connect(Callable(self, "_refresh_layout"))
	_refresh_layout()


func get_meter_size() -> Vector2:
	return meter_size


func set_lost_value(value: float, minimum: float, maximum: float) -> void:
	_minimum = minimum
	_maximum = maxf(maximum, minimum + 0.001)
	_value = clampf(value, _minimum, _maximum)

	if is_node_ready():
		_refresh_fill()


func _refresh_layout() -> void:
	var current_size := size
	if current_size.x <= 0.0 or current_size.y <= 0.0:
		current_size = meter_size
		size = current_size

	container_texture.position = Vector2.ZERO
	container_texture.size = current_size
	fill_clip.position = Vector2.ZERO
	fill_texture.position = Vector2.ZERO
	fill_texture.size = current_size
	_refresh_fill()


func _refresh_fill() -> void:
	if fill_clip == null:
		return

	var ratio := (_value - _minimum) / (_maximum - _minimum)
	ratio = clampf(ratio, 0.0, 1.0)
	fill_clip.visible = ratio > 0.001
	fill_clip.size = Vector2(size.x * ratio, size.y)
