extends RefCounted
## Pure world/progression rules shared by the host, clients, and tests.
const VERSION: int = 1
const NOTES: Array[String] = ["DO", "RE", "MI", "SOL", "LA"]
const COLORS: Array[Color] = [Color("a3df89"), Color("78d9e9"), Color("f0ce7b"), Color("baa5ed"), Color("f39987")]
const CENTERS: Array[Vector2] = [Vector2(0, 32), Vector2(-72, -30), Vector2(72, -30), Vector2(0, -108), Vector2(-76, -186), Vector2(76, -186), Vector2(0, -268)]
const NAMES: Array[String] = ["Firstlight Camp", "Canopy of Winds", "The Sunken Choir", "Stonewake Crossing", "Lanternwood", "The Echo Observatory", "Heart of the World"]
const THEMES: Array[String] = ["meadow", "pine", "water", "stone", "autumn", "spirit", "heart"]
const DESCRIPTIONS: Array[String] = ["Answer the three notes. Your song will grow the first bridges.", "The wind returns every melody backwards. Read the runes from right to left.", "The drowned bells remember a falling song. Restore them to uncover hidden treasures.", "Bring the wind and tide voices here. A stone canon will raise the northern crossings.", "Discord stalks the lanterns. Use the Ward song to quiet the sentinels, then restore the grove.", "A voice needs an answer. Complete the phrase, then press R so your Echo answers it. Friends can share the phrase instead.", "Every restored voice belongs in the final song. Awaken the Heart, then begin a new expedition."]
const EDGES: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, 2, 0), Vector3i(1, 3, 1), Vector3i(2, 3, 2), Vector3i(3, 4, 3), Vector3i(3, 5, 3), Vector3i(4, 6, 4), Vector3i(5, 6, 5)]
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

static func prerequisites(site: int, solved: Array) -> bool:
	if site == 0:
		return true
	if site <= 2:
		return bool(solved[0])
	if site == 3:
		return bool(solved[1]) and bool(solved[2])
	if site <= 5:
		return bool(solved[3])
	for i in range(6):
		if not solved[i]:
			return false
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
