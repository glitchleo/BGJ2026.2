extends Control

signal back_requested

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

@onready var fullscreen_button: Button = $FullscreenButton
@onready var back_button: Button = $BackButton
@onready var master_slider: Control = $MasterVolumeSlider
@onready var music_slider: Control = $MusicVolumeSlider
@onready var sfx_slider: Control = $SfxVolumeSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	fullscreen_button.pressed.connect(Callable(self, "_on_fullscreen_pressed"))
	back_button.pressed.connect(Callable(self, "_on_back_pressed"))

	_ensure_audio_bus(MUSIC_BUS)
	_ensure_audio_bus(SFX_BUS)
	_connect_slider(master_slider, MASTER_BUS)
	_connect_slider(music_slider, MUSIC_BUS)
	_connect_slider(sfx_slider, SFX_BUS)
	_sync_sliders_from_audio()


func show_menu() -> void:
	_sync_sliders_from_audio()
	visible = true


func hide_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _connect_slider(slider: Control, bus_name: String) -> void:
	if slider == null:
		return
	if slider.has_signal(&"value_changed"):
		slider.connect(
			&"value_changed",
			Callable(self, "_on_volume_slider_changed").bind(bus_name)
		)


func _sync_sliders_from_audio() -> void:
	_set_slider_without_signal(master_slider, _get_bus_linear_volume(MASTER_BUS))
	_set_slider_without_signal(music_slider, _get_bus_linear_volume(MUSIC_BUS))
	_set_slider_without_signal(sfx_slider, _get_bus_linear_volume(SFX_BUS))


func _set_slider_without_signal(slider: Control, next_value: float) -> void:
	if slider != null and slider.has_method(&"set_value"):
		slider.call(&"set_value", next_value, false)


func _on_volume_slider_changed(value: float, bus_name: String) -> void:
	_apply_bus_volume(bus_name, value)


func _on_fullscreen_pressed() -> void:
	var current_mode := DisplayServer.window_get_mode()
	var fullscreen := (
		current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	var next_mode := DisplayServer.WINDOW_MODE_WINDOWED
	if not fullscreen:
		next_mode = DisplayServer.WINDOW_MODE_FULLSCREEN

	DisplayServer.window_set_mode(next_mode)


func _on_back_pressed() -> void:
	hide_menu()
	back_requested.emit()


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var bus_index := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)


func _get_bus_linear_volume(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 1.0
	if AudioServer.is_bus_mute(bus_index):
		return 0.0

	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.0, 1.0)


func _apply_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	var clamped_value := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped_value <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clamped_value, 0.001)))
