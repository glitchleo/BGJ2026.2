extends Node

const DATA_PATH := "res://data/game_data.json"
const DIALOGUE_DATA_PATH := "res://data/dialogue_data.json"

var data: Dictionary = {}
var dialogue_data: Dictionary = {}
var memories_by_id: Dictionary = {}
var memory_dialogues_by_id: Dictionary = {}


func _ready() -> void:
	load_database()


func load_database() -> void:
	var loaded_data := _load_json_dictionary(DATA_PATH)
	if loaded_data.is_empty():
		return

	data = loaded_data
	_rebuild_memory_index()
	_load_dialogue_database()


func _load_dialogue_database() -> void:
	dialogue_data = _load_json_dictionary(DIALOGUE_DATA_PATH)
	memory_dialogues_by_id.clear()

	var memory_dialogues: Dictionary = dialogue_data.get("memory_dialogues", {})
	for raw_id in memory_dialogues.keys():
		memory_dialogues_by_id[str(raw_id)] = memory_dialogues[raw_id]


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameDB: Missing data file at %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameDB: Could not open %s" % path)
		return {}

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error(
			"GameDB: JSON parse error on line %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("GameDB: Root JSON value must be a Dictionary: %s" % path)
		return {}

	return json.data


func _rebuild_memory_index() -> void:
	memories_by_id.clear()

	for memory in data.get("memories", []):
		var id := str(memory.get("id", ""))
		if id.is_empty():
			continue
		memories_by_id[id] = memory


func get_memory(memory_id: String) -> Dictionary:
	return memories_by_id.get(memory_id, {}).duplicate(true)


func get_all_memories() -> Array:
	return data.get("memories", []).duplicate(true)


func get_world() -> Dictionary:
	return data.get("world", {}).duplicate(true)


func get_characters() -> Dictionary:
	return data.get("characters", {}).duplicate(true)


func get_npc_generation() -> Dictionary:
	return data.get("npc_generation", {}).duplicate(true)


func get_lost_settings() -> Dictionary:
	return data.get("lost_meter", {}).duplicate(true)


func get_dialogue_generation() -> Dictionary:
	return dialogue_data.get("dialogue_generation", {}).duplicate(true)


func get_final_dialogue() -> Dictionary:
	return dialogue_data.get("final_dialogue", {}).duplicate(true)


func get_npc_dialogue(npc_data: Dictionary) -> Dictionary:
	var profile := str(npc_data.get("profile", "STRANGER"))
	var attitude := str(npc_data.get("attitude", "friendly"))
	var memory_ids := _string_array(npc_data.get("memory_ids", []))
	var introduction_lines := _pick_introduction_lines(profile, attitude, npc_data)

	if memory_ids.is_empty():
		return _get_no_memory_dialogue(profile, attitude, npc_data, introduction_lines)

	var memory_entries: Array[Dictionary] = []
	var discovered_memory_ids: Array[String] = []

	for raw_memory_id in memory_ids:
		var memory_id := str(raw_memory_id)
		var memory := get_memory(memory_id)
		if memory.is_empty():
			continue

		var variant := _pick_memory_dialogue(memory_id, profile, attitude)
		if variant.is_empty():
			variant = _build_fallback_memory_dialogue(memory)

		memory_entries.append({
			"memory_id": memory_id,
			"memory": memory,
			"variant": variant
		})
		discovered_memory_ids.append(memory_id)

	if memory_entries.is_empty():
		return _get_no_memory_dialogue(profile, attitude, npc_data, introduction_lines)

	var memory_lines := _build_memory_lines(memory_entries, npc_data)
	if memory_lines.is_empty():
		return _get_no_memory_dialogue(profile, attitude, npc_data, introduction_lines)

	if _needs_uncertainty_prompt(memory_entries):
		return _build_uncertain_memory_dialogue(
			profile,
			attitude,
			npc_data,
			introduction_lines,
			memory_entries,
			memory_lines,
			discovered_memory_ids
		)

	var lines: Array[String] = []
	lines.append_array(introduction_lines)
	lines.append_array(memory_lines)

	return {
		"speaker_name": str(npc_data.get("name", "???")),
		"lines": lines,
		"options": [],
		"memory_ids": discovered_memory_ids
	}


func _get_no_memory_dialogue(
	profile: String,
	attitude: String,
	npc_data: Dictionary,
	introduction_lines: Array[String]
) -> Dictionary:
	var variants: Array = dialogue_data.get("no_memory_dialogues", [])
	var variant := _pick_dialogue_variant(variants, profile, attitude)
	if variant.is_empty():
		variant = {
			"lines": [
				"I am sorry.",
				"I do not know you well enough to give you anything useful."
			]
		}

	var lines: Array[String] = []
	lines.append_array(introduction_lines)
	lines.append_array(_format_dialogue_lines(variant.get("lines", []), npc_data, variant))

	return {
		"speaker_name": str(npc_data.get("name", "???")),
		"lines": lines,
		"options": _format_options(_array_duplicate(variant.get("options", [])), npc_data, variant),
		"memory_ids": []
	}


func _pick_introduction_lines(
	profile: String,
	attitude: String,
	npc_data: Dictionary
) -> Array[String]:
	var generation := get_dialogue_generation()
	var variants: Array = generation.get("introduction_dialogues", [])
	var variant := _pick_dialogue_variant(variants, profile, attitude)

	if variant.is_empty():
		return _format_dialogue_lines(
			[
				"I'm {npc_name}.",
				"I will tell you what I can, but please hold it gently."
			],
			npc_data
		)

	return _format_dialogue_lines(variant.get("lines", []), npc_data, variant)


func _build_memory_lines(
	memory_entries: Array[Dictionary],
	npc_data: Dictionary
) -> Array[String]:
	var lines: Array[String] = []

	for entry in memory_entries:
		var variant: Dictionary = entry.get("variant", {})
		if not lines.is_empty():
			lines.append(_pick_memory_bridge_line())

		lines.append_array(_format_dialogue_lines(variant.get("lines", []), npc_data, variant))

	return lines


func _build_uncertain_memory_dialogue(
	profile: String,
	attitude: String,
	npc_data: Dictionary,
	introduction_lines: Array[String],
	memory_entries: Array[Dictionary],
	memory_lines: Array[String],
	discovered_memory_ids: Array[String]
) -> Dictionary:
	var prompt := _pick_uncertainty_prompt(profile, attitude)
	var prompt_context := prompt.duplicate(true)
	prompt_context["source"] = _summarize_uncertain_sources(memory_entries)

	var lines: Array[String] = []
	lines.append_array(introduction_lines)
	lines.append_array(_format_dialogue_lines(prompt.get("lines", []), npc_data, prompt_context))

	var accept_lines: Array[String] = []
	accept_lines.append_array(_format_dialogue_lines(prompt.get("accept_prefix_lines", []), npc_data, prompt_context))
	accept_lines.append_array(memory_lines)

	var decline_lines := _format_dialogue_lines(prompt.get("decline_lines", []), npc_data, prompt_context)
	if decline_lines.is_empty():
		decline_lines = [
			"Okay.",
			"Maybe that is the wiser choice."
		]

	return {
		"speaker_name": str(npc_data.get("name", "???")),
		"lines": lines,
		"options": [
			{
				"text": _format_dialogue_line(str(prompt.get("accept_text", "Tell me anyway.")), npc_data, prompt_context),
				"lines": accept_lines,
				"memory_ids": discovered_memory_ids
			},
			{
				"text": _format_dialogue_line(str(prompt.get("decline_text", "Leave it.")), npc_data, prompt_context),
				"lines": decline_lines,
				"memory_ids": []
			}
		],
		"memory_ids": []
	}


func _pick_uncertainty_prompt(profile: String, attitude: String) -> Dictionary:
	var generation := get_dialogue_generation()
	var prompts: Array = generation.get("uncertainty_prompts", [])
	var prompt := _pick_dialogue_variant(prompts, profile, attitude)

	if prompt.is_empty():
		return {
			"lines": [
				"I should warn you first.",
				"This might be wrong. Do you still want to hear it?"
			],
			"accept_text": "Tell me anyway.",
			"decline_text": "Leave it.",
			"decline_lines": [
				"Okay.",
				"Maybe that is the wiser choice."
			]
		}

	return prompt


func _needs_uncertainty_prompt(memory_entries: Array[Dictionary]) -> bool:
	for entry in memory_entries:
		var variant: Dictionary = entry.get("variant", {})
		if _variant_needs_uncertainty_prompt(variant):
			return true

	return false


func _variant_needs_uncertainty_prompt(variant: Dictionary) -> bool:
	var certainty := str(variant.get("certainty", "")).to_lower()
	if certainty == "low":
		return true

	var source := str(variant.get("source", "")).to_lower()
	var uncertain_fragments := [
		"rumor",
		"secondhand",
		"assumption",
		"misread",
		"confusion",
		"confused",
		"mistaken",
		"indirect",
		"outdated"
	]

	for fragment in uncertain_fragments:
		if source.find(fragment) != -1:
			return true

	return false


func _summarize_uncertain_sources(memory_entries: Array[Dictionary]) -> String:
	var source_labels: Array[String] = []

	for entry in memory_entries:
		var variant: Dictionary = entry.get("variant", {})
		if not _variant_needs_uncertainty_prompt(variant):
			continue

		var source := str(variant.get("source", "something indirect"))
		if source not in source_labels:
			source_labels.append(source)

	if source_labels.is_empty():
		return "something indirect"
	if source_labels.size() == 1:
		return source_labels[0]

	return "a few uncertain places"


func _pick_memory_dialogue(
	memory_id: String,
	profile: String,
	attitude: String
) -> Dictionary:
	var variants: Array = memory_dialogues_by_id.get(memory_id, [])
	return _pick_dialogue_variant(variants, profile, attitude)


func _pick_dialogue_variant(
	variants: Array,
	profile: String,
	attitude: String
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var best_specificity := -1

	for raw_variant in variants:
		if not (raw_variant is Dictionary):
			continue

		var exact_variant := raw_variant as Dictionary
		if not _variant_matches(exact_variant, "profiles", profile):
			continue
		if not _variant_matches(exact_variant, "attitudes", attitude):
			continue

		var specificity := _variant_specificity(exact_variant)
		if specificity < best_specificity:
			continue
		if specificity > best_specificity:
			best_specificity = specificity
			candidates.clear()

		candidates.append(exact_variant)

	if candidates.is_empty():
		for raw_variant in variants:
			if not (raw_variant is Dictionary):
				continue

			var profile_variant := raw_variant as Dictionary
			if _variant_matches(profile_variant, "profiles", profile):
				candidates.append(profile_variant)

	if candidates.is_empty():
		for raw_variant in variants:
			if raw_variant is Dictionary:
				candidates.append(raw_variant as Dictionary)

	if candidates.is_empty():
		return {}

	return _weighted_dialogue_pick(candidates).duplicate(true)


func _variant_specificity(variant: Dictionary) -> int:
	var specificity := 0
	if not _string_array(variant.get("profiles", [])).is_empty():
		specificity += 1
	if not _string_array(variant.get("attitudes", [])).is_empty():
		specificity += 1

	return specificity


func _variant_matches(variant: Dictionary, key: String, value: String) -> bool:
	var values: Array = variant.get(key, [])
	return values.is_empty() or value in _string_array(values)


func _weighted_dialogue_pick(items: Array[Dictionary]) -> Dictionary:
	if items.is_empty():
		return {}

	var total := 0.0
	for item in items:
		total += maxf(float(item.get("weight", 1.0)), 0.0)

	if total <= 0.0:
		return items.pick_random()

	var roll := randf() * total
	var running := 0.0

	for item in items:
		running += maxf(float(item.get("weight", 1.0)), 0.0)
		if roll <= running:
			return item

	return items.back()


func _pick_memory_bridge_line() -> String:
	var generation := get_dialogue_generation()
	var bridge_lines := _string_array(generation.get("memory_bridge_lines", []))
	if bridge_lines.is_empty():
		return "There is another thing."

	return bridge_lines.pick_random()


func _build_fallback_memory_dialogue(memory: Dictionary) -> Dictionary:
	return {
		"lines": [
			"This may not sound graceful, but it is the piece I remember.",
			str(memory.get("npc_text", memory.get("text", "..."))),
			"I wish I knew how much of that still feels like you."
		]
	}


func _format_options(options: Array, npc_data: Dictionary, context: Dictionary = {}) -> Array:
	var result: Array = []

	for raw_option in options:
		if raw_option is Dictionary:
			var option := (raw_option as Dictionary).duplicate(true)

			if option.has("text"):
				option["text"] = _format_dialogue_line(str(option.get("text", "")), npc_data, context)
			if option.has("lines"):
				option["lines"] = _format_dialogue_lines(option.get("lines", []), npc_data, context)
			if option.has("memory_ids"):
				option["memory_ids"] = _string_array(option.get("memory_ids", []))

			result.append(option)
		else:
			result.append({
				"text": _format_dialogue_line(str(raw_option), npc_data, context)
			})

	return result


func _format_dialogue_lines(value, npc_data: Dictionary, context: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result

	for item in value:
		result.append(_format_dialogue_line(str(item), npc_data, context))

	return result


func _format_dialogue_line(line: String, npc_data: Dictionary, context: Dictionary = {}) -> String:
	var world := get_world()
	var characters := get_characters()
	var mc: Dictionary = characters.get("mc", {})
	var girlfriend: Dictionary = characters.get("girlfriend", {})

	var formatted := line
	formatted = formatted.replace("{npc_name}", str(npc_data.get("name", "???")))
	formatted = formatted.replace("{mc_name}", str(mc.get("name", "Lamb")))
	formatted = formatted.replace("{city}", str(world.get("city", "Merun City")))
	formatted = formatted.replace("{university}", str(world.get("university", "Sorel Academy")))
	formatted = formatted.replace("{girlfriend_name}", str(girlfriend.get("name", "Saeli")))

	for raw_key in context.keys():
		var key := str(raw_key)
		formatted = formatted.replace("{%s}" % key, str(context[raw_key]))

	return formatted


func _array_duplicate(value) -> Array:
	if value is Array:
		return value.duplicate(true)

	return []


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result

	for item in value:
		result.append(str(item))

	return result
