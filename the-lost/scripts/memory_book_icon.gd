extends TextureButton

@onready var conflict_badge: TextureRect = $ConflictBadge


func _ready() -> void:
	conflict_badge.visible = false


func set_conflict_visible(is_visible: bool) -> void:
	if conflict_badge != null:
		conflict_badge.visible = is_visible
