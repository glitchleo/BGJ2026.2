extends Node

signal lost_changed(new_value: float, delta: float)
signal memory_discovered(memory_id: String)
signal memory_classified(memory_id: String, belief: int)
signal pending_changed(memory_ids: Array)

enum Belief {
	UNCLASSIFIED,
	TRUE,
	UNCERTAIN,
	FALSE
}

const BOOK_SECTION_TRUE := "True"
const BOOK_SECTION_UNCERTAIN := "Uncertain"
const BOOK_SECTION_FALSE := "False"
const BOOK_SECTIONS := [
	BOOK_SECTION_TRUE,
	BOOK_SECTION_UNCERTAIN,
	BOOK_SECTION_FALSE,
]

const HOME_CONFLICT_GROUPS := [
	"current_household",
	"highschool_housing",
	"university_housing",
	"girlfriend_visit_pattern",
]

var lost_value: float = 70.0

var belief_by_memory: Dictionary = {}
var discovered_memories: Dictionary = {}
var discovered_memory_order: Array[String] = []
var contribution_by_memory: Dictionary = {}
var pending_memory_ids: Array[String] = []

var final_accuracy_state: String = ""
var final_accuracy_ratio: float = 0.0


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	var old_lost := lost_value
	lost_value = clampf(
		float(GameDB.get_lost_settings().get("starting_value", 70.0)),
		get_minimum_lost(),
		get_maximum_lost()
	)

	belief_by_memory.clear()
	discovered_memories.clear()
	discovered_memory_order.clear()
	contribution_by_memory.clear()
	pending_memory_ids.clear()
	final_accuracy_state = ""
	final_accuracy_ratio = 0.0

	for memory in GameDB.get_all_memories():
		var id := str(memory.get("id", ""))
		if id.is_empty():
			continue
		belief_by_memory[id] = Belief.UNCLASSIFIED

	lost_changed.emit(lost_value, lost_value - old_lost)
	pending_changed.emit(get_pending_ids())


func discover_memories(memory_ids: Array) -> void:
	for raw_id in memory_ids:
		var memory_id := str(raw_id)

		if discovered_memories.has(memory_id):
			continue

		var memory := GameDB.get_memory(memory_id)
		if memory.is_empty():
			push_warning("MemoryManager: Unknown memory id %s" % memory_id)
			continue

		discovered_memories[memory_id] = true
		discovered_memory_order.append(memory_id)
		belief_by_memory[memory_id] = Belief.UNCLASSIFIED
		contribution_by_memory[memory_id] = 0.0

		pending_memory_ids.append(memory_id)
		memory_discovered.emit(memory_id)

	pending_changed.emit(get_pending_ids())


func classify_memory(memory_id: String, new_belief: int) -> void:
	if not discovered_memories.has(memory_id):
		push_warning("MemoryManager: Cannot classify undiscovered memory %s" % memory_id)
		return

	if new_belief not in [
		Belief.TRUE,
		Belief.UNCERTAIN,
		Belief.FALSE
	]:
		push_warning("MemoryManager: Invalid belief value %s" % new_belief)
		return

	var memory := GameDB.get_memory(memory_id)
	if memory.is_empty():
		return

	var old_score := float(contribution_by_memory.get(memory_id, 0.0))
	var new_score := _score_for_belief(memory, new_belief)

	_apply_contribution_delta(new_score - old_score)

	contribution_by_memory[memory_id] = new_score
	belief_by_memory[memory_id] = new_belief
	pending_memory_ids.erase(memory_id)

	memory_classified.emit(memory_id, new_belief)
	pending_changed.emit(get_pending_ids())


func decrease_lost(amount: float) -> void:
	if amount <= 0.0:
		return

	_set_lost(lost_value - amount)


func set_lost(value: float) -> void:
	_set_lost(value)


func get_minimum_lost() -> float:
	return float(GameDB.get_lost_settings().get("minimum", 0.0))


func get_maximum_lost() -> float:
	return maxf(float(GameDB.get_lost_settings().get("maximum", 100.0)), 1.0)


func get_lost_ratio() -> float:
	return clampf(lost_value / get_maximum_lost(), 0.0, 1.0)


func get_book_sections() -> Array:
	return BOOK_SECTIONS.duplicate()


func get_belief(memory_id: String) -> int:
	return int(belief_by_memory.get(memory_id, Belief.UNCLASSIFIED))


func get_pending_ids() -> Array:
	return pending_memory_ids.duplicate()


func get_discovered_ids_for_section(section: String) -> Array[String]:
	var result: Array[String] = []
	var section_belief := _belief_for_book_section(section)
	if section_belief == Belief.UNCLASSIFIED:
		return result

	for memory_id in discovered_memory_order:
		if not discovered_memories.has(memory_id):
			continue
		if get_belief(memory_id) == section_belief:
			result.append(memory_id)

	return result


func get_conflicting_ids(memory_id: String, discovered_only: bool = true) -> Array[String]:
	var result: Array[String] = []
	var memory := GameDB.get_memory(memory_id)
	var conflict_group := str(memory.get("conflict_group", ""))

	if conflict_group.is_empty():
		return result

	for other in GameDB.get_all_memories():
		var other_id := str(other.get("id", ""))
		if other_id == memory_id or other_id.is_empty():
			continue
		if discovered_only and not discovered_memories.has(other_id):
			continue
		if str(other.get("conflict_group", "")) == conflict_group:
			result.append(other_id)

	return result


func get_marked_true_conflict_ids(memory_id: String) -> Array[String]:
	var result: Array[String] = []
	if get_belief(memory_id) != Belief.TRUE:
		return result

	for other_id in get_conflicting_ids(memory_id):
		if get_belief(other_id) == Belief.TRUE:
			result.append(other_id)

	return result


func has_marked_true_conflicts() -> bool:
	for memory_id in discovered_memory_order:
		if not get_marked_true_conflict_ids(memory_id).is_empty():
			return true

	return false


func is_classification_correct(memory_id: String) -> bool:
	var belief := get_belief(memory_id)
	if belief != Belief.TRUE and belief != Belief.FALSE:
		return false

	var memory := GameDB.get_memory(memory_id)
	if memory.is_empty():
		return false

	var player_says_true := belief == Belief.TRUE
	return player_says_true == bool(memory.get("actual_truth", false))


func get_home_probability_bonus(
	per_correct_home_memory: float,
	per_uncertain_home_memory: float,
	maximum_bonus: float
) -> float:
	var bonus := 0.0

	for memory_id in discovered_memories.keys():
		var id := str(memory_id)
		var memory := GameDB.get_memory(id)
		if not _is_home_memory(memory):
			continue

		var belief := get_belief(id)
		if belief == Belief.UNCERTAIN:
			bonus += per_uncertain_home_memory
		elif is_classification_correct(id):
			bonus += per_correct_home_memory

	return clampf(bonus, 0.0, maximum_bonus)


func get_final_accuracy_ratio() -> float:
	var total := 0
	var correct := 0

	for memory_id in discovered_memory_order:
		if not discovered_memories.has(memory_id):
			continue

		total += 1
		if is_classification_correct(memory_id):
			correct += 1

	if total <= 0:
		return 0.0

	return float(correct) / float(total)


func capture_final_accuracy_state(
	high_threshold: float = 0.7,
	mixed_threshold: float = 0.4
) -> String:
	final_accuracy_ratio = get_final_accuracy_ratio()
	final_accuracy_state = _accuracy_state_for_ratio(
		final_accuracy_ratio,
		high_threshold,
		mixed_threshold
	)
	return final_accuracy_state


func _accuracy_state_for_ratio(
	ratio: float,
	high_threshold: float,
	mixed_threshold: float
) -> String:
	var normalized_high := clampf(high_threshold, 0.0, 1.0)
	var normalized_mixed := clampf(mixed_threshold, 0.0, normalized_high)

	if ratio >= normalized_high:
		return "HIGH"
	if ratio >= normalized_mixed:
		return "MIXED"

	return "LOW"


func _score_for_belief(memory: Dictionary, belief: int) -> float:
	var base := _rank_value(memory)

	if belief == Belief.UNCERTAIN:
		return base * _belief_multiplier("UNCERTAIN")

	var actual_truth := bool(memory.get("actual_truth", false))
	var player_says_true := belief == Belief.TRUE
	var is_correct := player_says_true == actual_truth

	if is_correct:
		return base * _belief_multiplier("CORRECT")

	return base * _belief_multiplier("WRONG")


func _rank_value(memory: Dictionary) -> float:
	var values: Dictionary = GameDB.get_lost_settings().get("rank_values", {})
	return float(values.get(str(memory.get("rank", "MINOR")), 3.0))


func _belief_multiplier(key: String) -> float:
	var multipliers: Dictionary = GameDB.get_lost_settings().get("belief_multipliers", {})
	return float(multipliers.get(key, 0.0))


func _apply_contribution_delta(score_delta: float) -> void:
	if is_zero_approx(score_delta):
		return

	_set_lost(lost_value - score_delta)


func _set_lost(value: float) -> void:
	var old_lost := lost_value
	lost_value = clampf(value, get_minimum_lost(), get_maximum_lost())

	if is_equal_approx(lost_value, old_lost):
		return

	lost_changed.emit(lost_value, lost_value - old_lost)


func _is_home_memory(memory: Dictionary) -> bool:
	if memory.is_empty():
		return false

	var category := str(memory.get("category", ""))
	var topic := str(memory.get("topic", "")).to_lower()
	var text := str(memory.get("text", "")).to_lower()
	var conflict_group := str(memory.get("conflict_group", ""))

	if conflict_group in HOME_CONFLICT_GROUPS:
		return true
	if _contains_any(topic + " " + text, ["home", "household", "housing", "lived", "live with"]):
		return true

	return category == "PLACES" and _contains_any(text, ["apartment", "dorm", "room"])


func _belief_for_book_section(section: String) -> int:
	match section:
		BOOK_SECTION_TRUE:
			return Belief.TRUE
		BOOK_SECTION_UNCERTAIN:
			return Belief.UNCERTAIN
		BOOK_SECTION_FALSE:
			return Belief.FALSE
		_:
			return Belief.UNCLASSIFIED


func _contains_any(value: String, fragments: Array) -> bool:
	for fragment in fragments:
		if value.find(str(fragment)) != -1:
			return true

	return false
