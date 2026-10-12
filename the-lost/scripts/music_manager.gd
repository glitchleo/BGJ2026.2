extends Node

const MUSIC_BUS := "Music"

@export var music_stream: AudioStream
@export_range(0.0, 1.0, 0.01) var menu_volume := 0.22
@export_range(0.0, 1.0, 0.01) var gameplay_volume := 0.08

@onready var music_player: AudioStreamPlayer = $BackgroundMusicPlayer

var _loop_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_bus(MUSIC_BUS)

	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.bus = MUSIC_BUS
	music_player.stream = music_stream

	if not music_player.finished.is_connected(Callable(self, "_on_music_finished")):
		music_player.finished.connect(Callable(self, "_on_music_finished"))


func play_menu_music() -> void:
	_play_music(menu_volume)


func play_gameplay_music() -> void:
	_play_music(gameplay_volume)


func _play_music(linear_volume: float) -> void:
	if music_player == null:
		return

	if music_player.stream == null:
		music_player.stream = music_stream
	if music_player.stream == null:
		return

	_loop_enabled = true
	_set_music_volume(linear_volume)

	if not music_player.playing:
		music_player.play()


func _set_music_volume(linear_volume: float) -> void:
	var clamped_volume := clampf(linear_volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(maxf(clamped_volume, 0.001))


func _on_music_finished() -> void:
	if _loop_enabled and music_player != null:
		music_player.play()


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var bus_index := AudioServer.get_bus_count()
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, bus_name)
