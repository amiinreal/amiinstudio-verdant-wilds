extends RefCounted
## Pure world/progression rules shared by the host, clients, and tests.
const VERSION: int = 2
const NOTES: Array[String] = ["DO", "RE", "MI", "SOL", "LA"]
const COLORS: Array[Color] = [Color("a3df89"), Color("78d9e9"), Color("f0ce7b"), Color("baa5ed"), Color("f39987")]
const CENTERS: Array[Vector2] = [Vector2(-95,155),Vector2(-225,-180),Vector2(-53,120),Vector2(170,-280),Vector2(-270,-300),Vector2(160,160),Vector2(40,400)]
const NAMES: Array[String] = ["Aldermead Valley", "Whisperwood Forest", "Mirrorwater Basin", "Greycrown Mountains", "Elderwood Deep Forest", "Sunfold Hills", "Southshore Coast"]
const THEMES: Array[String] = ["meadow", "pine", "water", "stone", "autumn", "spirit", "heart"]
const DESCRIPTIONS: Array[String] = ["An optional melody teaches Bloom. Listen with Q, then answer with 1–5.", "The forest answers backwards. Read the runes from right to left.", "The lakeside bells remember a falling song. Learn Reveal here.", "The mountain stones teach Ward. All roads remain open.", "An ancient tree holds a forgotten melody.", "Play the phrase, then let your Echo answer with R. Friends can share the phrase too.", "The coast carries one more voice. Restore it whenever you discover it."]
const EDGES: Array[Vector3i] = []
const SPELLS: Array[Array] = [[0, 1, 2], [4, 2, 0], [1, 3, 1], [0, 2, 4]]
const SPELL_NAMES: Array[String] = ["Bloom", "Gust", "Reveal", "Ward"]

static func melodies(seed_value: int) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 5029
	var result: Array = [[0, 1, 2]]
	for i in range(1, 7):
		var phrase: Array = []
		for j in range(4 if i < 6 else 5):
			phrase.append(rng.randi_range(0, 4))
		if i == 2:
			phrase.sort()
			phrase.reverse()
		result.append(phrase)
	return result

static func required_phrase(seed_value: int, site: int) -> Array:
	var phrase: Array = melodies(seed_value)[site].duplicate()
	if site == 1:
		phrase.reverse()
	return phrase

static func prerequisites(_site: int, _solved: Array) -> bool:
	return true

static func phrase_text(phrase: Array) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for note: int in phrase:
		labels.append(str(note + 1))
	return "  ·  ".join(labels)

static func fresh_state(seed_value: int) -> Dictionary:
	return {"version": VERSION, "seed": seed_value, "solved": [false, false, false, false, false, false, false], "collected": [], "shards": 0, "expedition": 1}

static func validate_state(state: Dictionary) -> bool:
	if state.get("version", -1) != VERSION or not state.get("seed") is int:
		return false
	if not state.get("solved") is Array or state["solved"].size() != 7:
		return false
	for flag: Variant in state["solved"]:
		if not flag is bool:
			return false
	return state.get("collected") is Array and state.get("shards") is int
