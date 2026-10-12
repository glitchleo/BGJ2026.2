extends Node

const NPC_VISUAL_ASSETS = preload("res://scripts/npc_visual_assets.gd")
const NPC_BODY_PATH := "res://assets/npc/body/bb.png"
const NO_BACK_HAIR := ""
const FRONT_TO_BACK_HAIR_OPTIONS := {
	"fhl": ["bhl", "bhm"],
	"fhm": ["bhl", "bhm", "bhs"],
	"fhs": ["bhs", NO_BACK_HAIR],
}

var _used_names: Dictionary = {}
var _next_npc_number := 1
var _hair_cache_built := false
var _hair_combinations: Array[Dictionary] = []


func _ready() -> void:
	randomize()


func reset_run() -> void:
	_used_names.clear()
	_next_npc_number = 1
	_hair_cache_built = false
	_hair_combinations.clear()


func generate_npc(force_profile_id: String = "") -> Dictionary:
	var config := GameDB.get_npc_generation()
	var profile := _pick_profile(config, force_profile_id)
	var profile_id := str(profile.get("id", "STRANGER"))
	var memory_ids := _pick_memories_for_profile(profile)

	var npc := {
		"id": "npc_%04d" % _next_npc_number,
		"name": generate_name(),
		"profile": profile_id,
		"attitude": _pick_attitude(profile_id),
		"appearance": generate_appearance(),
		"memory_ids": memory_ids
	}

	_next_npc_number += 1
	return npc


func generate_name() -> String:
	var config := GameDB.get_npc_generation()
	var patterns: Array = config.get("name_patterns", [])
	var forbidden: Array = config.get("forbidden_names", [])

	for _attempt in range(500):
		var pattern_data := _weighted_pick(patterns)
		var pattern := str(pattern_data.get("pattern", "CVC"))
		var raw := _build_name_from_pattern(pattern, config).to_lower()

		if raw.length() != 3:
			continue
		if raw in forbidden:
			continue
		if _used_names.has(raw):
			continue

		_used_names[raw] = true
		return raw.left(1).to_upper() + raw.substr(1)

	var fallback := "Z%02d" % (_used_names.size() % 100)
	return fallback.left(3)


func generate_appearance() -> Dictionary:
	var combinations := _get_hair_combinations()
	if combinations.is_empty():
		return {
			"body": NPC_BODY_PATH,
			"back_hair": "",
			"bottom": _pick_bottom_path(),
			"top": _pick_top_path(),
			"front_hair": ""
		}

	var hair: Dictionary = combinations.pick_random()
	return {
		"body": NPC_BODY_PATH,
		"back_hair": str(hair.get("back_hair", "")),
		"bottom": _pick_bottom_path(),
		"top": _pick_top_path(),
		"front_hair": str(hair.get("front_hair", ""))
	}


func _build_name_from_pattern(pattern: String, config: Dictionary) -> String:
	var consonants: Array = config.get("consonants", ["v", "z", "k", "r", "n"])
	var vowels: Array = config.get("vowels", ["a", "e", "i", "o", "u"])
	var clusters: Array = config.get("clusters", ["vr", "zr", "kr"])

	match pattern:
		"CVC":
			return str(consonants.pick_random()) + str(vowels.pick_random()) + str(consonants.pick_random())
		"VCV":
			return str(vowels.pick_random()) + str(consonants.pick_random()) + str(vowels.pick_random())
		"CVV":
			return str(consonants.pick_random()) + str(vowels.pick_random()) + str(vowels.pick_random())
		"CCV":
			return str(clusters.pick_random()) + str(vowels.pick_random())
		_:
			return str(consonants.pick_random()) + str(vowels.pick_random()) + str(consonants.pick_random())


func _pick_profile(config: Dictionary, force_profile_id: String) -> Dictionary:
	var profiles: Array = config.get("profiles", [])

	if not force_profile_id.is_empty():
		for profile in profiles:
			if str(profile.get("id", "")) == force_profile_id:
				return profile

	return _weighted_pick(profiles)


func _pick_memories_for_profile(profile: Dictionary) -> Array[String]:
	var minimum := int(profile.get("memory_min", 0))
	var maximum := int(profile.get("memory_max", 0))
	var memory_count := randi_range(minimum, maximum)

	if memory_count <= 0:
		return []

	var allowed_categories: Array = profile.get("allowed_categories", [])
	var candidates: Array = []

	for memory in GameDB.get_all_memories():
		if str(memory.get("category", "")) in allowed_categories:
			candidates.append(memory)

	candidates.shuffle()

	var chosen_ids: Array[String] = []
	var used_conflict_groups: Dictionary = {}

	for memory in candidates:
		if chosen_ids.size() >= memory_count:
			break

		var conflict_group := str(memory.get("conflict_group", ""))

		if not conflict_group.is_empty() and used_conflict_groups.has(conflict_group):
			continue

		chosen_ids.append(str(memory.get("id", "")))

		if not conflict_group.is_empty():
			used_conflict_groups[conflict_group] = true

	return chosen_ids


func _pick_attitude(profile_id: String) -> String:
	var dialogue_generation := GameDB.get_dialogue_generation()
	var attitudes_by_profile: Dictionary = dialogue_generation.get("profile_attitudes", {})
	var attitudes: Array = attitudes_by_profile.get(profile_id, [])

	if attitudes.is_empty():
		return "friendly"

	var picked := _weighted_pick(attitudes)
	return str(picked.get("id", "friendly"))


func _get_hair_combinations() -> Array[Dictionary]:
	if _hair_cache_built:
		return _hair_combinations

	_hair_cache_built = true

	var back_paths_by_prefix: Dictionary = NPC_VISUAL_ASSETS.get_back_hair_paths_by_prefix()
	var front_paths_by_prefix: Dictionary = NPC_VISUAL_ASSETS.get_front_hair_paths_by_prefix()

	for front_prefix in FRONT_TO_BACK_HAIR_OPTIONS.keys():
		var front_paths: Array = front_paths_by_prefix.get(front_prefix, [])
		var back_options: Array = FRONT_TO_BACK_HAIR_OPTIONS.get(front_prefix, [])

		for front_path in front_paths:
			for back_prefix in back_options:
				if str(back_prefix) == NO_BACK_HAIR:
					_hair_combinations.append({
						"back_hair": "",
						"front_hair": str(front_path)
					})
					continue

				var back_paths: Array = back_paths_by_prefix.get(str(back_prefix), [])
				for back_path in back_paths:
					_hair_combinations.append({
						"back_hair": str(back_path),
						"front_hair": str(front_path)
					})

	if _hair_combinations.is_empty():
		push_warning("NpcGenerator: No valid hair combinations were found.")

	return _hair_combinations


func _pick_top_path() -> String:
	var top_paths: Array[String] = NPC_VISUAL_ASSETS.get_top_paths()
	if top_paths.is_empty():
		push_warning("NpcGenerator: No top clothing textures were found.")
		return ""

	return str(top_paths.pick_random())


func _pick_bottom_path() -> String:
	var bottom_paths: Array[String] = NPC_VISUAL_ASSETS.get_bottom_paths()
	if bottom_paths.is_empty():
		push_warning("NpcGenerator: No bottom clothing textures were found.")
		return ""

	return str(bottom_paths.pick_random())


func _weighted_pick(items: Array) -> Dictionary:
	if items.is_empty():
		return {}

	var total := 0.0
	for item in items:
		total += float(item.get("weight", 1.0))

	var roll := randf() * total
	var running := 0.0

	for item in items:
		running += float(item.get("weight", 1.0))
		if roll <= running:
			return item

	return items.back()
