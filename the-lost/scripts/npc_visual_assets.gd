extends RefCounted

const BODY_PATH := "res://assets/npc/body/bb.png"
const BODY_TEXTURE = preload("res://assets/npc/body/bb.png")

const BACK_HAIR_TEXTURES_BY_PREFIX := {
	"bhl": [
		preload("res://assets/npc/hair/back/bhl.png"),
	],
	"bhm": [
		preload("res://assets/npc/hair/back/bhm.png"),
	],
	"bhs": [
		preload("res://assets/npc/hair/back/bhs.png"),
	],
}

const FRONT_HAIR_TEXTURES_BY_PREFIX := {
	"fhl": [
		preload("res://assets/npc/hair/front/fhl1.png"),
		preload("res://assets/npc/hair/front/fhl2.png"),
		preload("res://assets/npc/hair/front/fhl3.png"),
		preload("res://assets/npc/hair/front/fhl4.png"),
		preload("res://assets/npc/hair/front/fhl5.png"),
	],
	"fhm": [
		preload("res://assets/npc/hair/front/fhm1.png"),
		preload("res://assets/npc/hair/front/fhm2.png"),
		preload("res://assets/npc/hair/front/fhm3.png"),
		preload("res://assets/npc/hair/front/fhm4.png"),
		preload("res://assets/npc/hair/front/fhm5.png"),
		preload("res://assets/npc/hair/front/fhm6.png"),
	],
	"fhs": [
		preload("res://assets/npc/hair/front/fhs1.png"),
		preload("res://assets/npc/hair/front/fhs2.png"),
		preload("res://assets/npc/hair/front/fhs3.png"),
		preload("res://assets/npc/hair/front/fhs4.png"),
		preload("res://assets/npc/hair/front/fhs5.png"),
		preload("res://assets/npc/hair/front/fhs6.png"),
	],
}

const BOTTOM_TEXTURES := [
	preload("res://assets/npc/bottom/bot2.png"),
	preload("res://assets/npc/bottom/bot3.png"),
	preload("res://assets/npc/bottom/bot4.png"),
	preload("res://assets/npc/bottom/bot5.png"),
	preload("res://assets/npc/bottom/bot6.png"),
	preload("res://assets/npc/bottom/bot7.png"),
	preload("res://assets/npc/bottom/bot8.png"),
	preload("res://assets/npc/bottom/bot9.png"),
	preload("res://assets/npc/bottom/bot10.png"),
	preload("res://assets/npc/bottom/bot11.png"),
	preload("res://assets/npc/bottom/bot12.png"),
	preload("res://assets/npc/bottom/bot13.png"),
]

const TOP_TEXTURES := [
	preload("res://assets/npc/top/top1.png"),
	preload("res://assets/npc/top/top2.png"),
	preload("res://assets/npc/top/top3.png"),
	preload("res://assets/npc/top/top4.png"),
	preload("res://assets/npc/top/top5.png"),
	preload("res://assets/npc/top/top6.png"),
	preload("res://assets/npc/top/top7.png"),
	preload("res://assets/npc/top/top8.png"),
	preload("res://assets/npc/top/top9.png"),
	preload("res://assets/npc/top/top10.png"),
	preload("res://assets/npc/top/top11.png"),
	preload("res://assets/npc/top/top12.png"),
	preload("res://assets/npc/top/top13.png"),
	preload("res://assets/npc/top/top14.png"),
	preload("res://assets/npc/top/top15.png"),
	preload("res://assets/npc/top/top16.png"),
	preload("res://assets/npc/top/top17.png"),
	preload("res://assets/npc/top/top18.png"),
	preload("res://assets/npc/top/top19.png"),
	preload("res://assets/npc/top/top20.png"),
	preload("res://assets/npc/top/top21.png"),
	preload("res://assets/npc/top/top22.png"),
	preload("res://assets/npc/top/top23.png"),
	preload("res://assets/npc/top/top24.png"),
]


static func get_texture(texture_path: String) -> Texture2D:
	if texture_path == BODY_PATH:
		return BODY_TEXTURE

	var texture := _find_texture_in_groups(texture_path, BACK_HAIR_TEXTURES_BY_PREFIX)
	if texture != null:
		return texture

	texture = _find_texture_in_groups(texture_path, FRONT_HAIR_TEXTURES_BY_PREFIX)
	if texture != null:
		return texture

	texture = _find_texture_in_list(texture_path, BOTTOM_TEXTURES)
	if texture != null:
		return texture

	return _find_texture_in_list(texture_path, TOP_TEXTURES)


static func get_back_hair_paths_by_prefix() -> Dictionary:
	return _paths_by_prefix(BACK_HAIR_TEXTURES_BY_PREFIX)


static func get_front_hair_paths_by_prefix() -> Dictionary:
	return _paths_by_prefix(FRONT_HAIR_TEXTURES_BY_PREFIX)


static func get_bottom_paths() -> Array[String]:
	return _paths_for(BOTTOM_TEXTURES)


static func get_top_paths() -> Array[String]:
	return _paths_for(TOP_TEXTURES)


static func _paths_by_prefix(textures_by_prefix: Dictionary) -> Dictionary:
	var result := {}
	for prefix in textures_by_prefix.keys():
		var textures: Array = textures_by_prefix[prefix]
		result[str(prefix)] = _paths_for(textures)

	return result


static func _paths_for(textures: Array) -> Array[String]:
	var paths: Array[String] = []
	for raw_texture in textures:
		var texture := raw_texture as Texture2D
		if texture != null:
			paths.append(texture.resource_path)

	return paths


static func _find_texture_in_groups(
	texture_path: String,
	textures_by_prefix: Dictionary
) -> Texture2D:
	for raw_textures in textures_by_prefix.values():
		var textures: Array = raw_textures
		var texture := _find_texture_in_list(texture_path, textures)
		if texture != null:
			return texture

	return null


static func _find_texture_in_list(texture_path: String, textures: Array) -> Texture2D:
	for raw_texture in textures:
		var texture := raw_texture as Texture2D
		if texture != null and texture.resource_path == texture_path:
			return texture

	return null
