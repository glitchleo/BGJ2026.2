extends Control

signal resume_requested
signal settings_requested
signal main_menu_requested
signal leave_requested
signal back_requested

@onready var resume_button: Button = $ResumeButton
@onready var settings_button: Button = $SettingsButton
@onready var main_menu_button: Button = $MainMenuButton
@onready var leave_button: Button = $LeaveButton
@onready var back_button: Button = $BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	resume_button.pressed.connect(Callable(self, "_on_resume_pressed"))
	settings_button.pressed.connect(Callable(self, "_on_settings_pressed"))
	main_menu_button.pressed.connect(Callable(self, "_on_main_menu_pressed"))
	leave_button.pressed.connect(Callable(self, "_on_leave_pressed"))
	back_button.pressed.connect(Callable(self, "_on_back_pressed"))


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	hide_menu()
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()


func _on_leave_pressed() -> void:
	leave_requested.emit()


func _on_back_pressed() -> void:
	hide_menu()
	back_requested.emit()
