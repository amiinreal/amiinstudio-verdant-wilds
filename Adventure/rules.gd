extends RefCounted
const VERSION: int=3
const CENTERS: Array[Vector2] = [Vector2(-95,155),Vector2(-225,-180),Vector2(-53,120),Vector2(170,-280),Vector2(-270,-300),Vector2(160,160),Vector2(40,400)]
const NAMES: Array[String] = ["Aldermead Valley", "Whisperwood Forest", "Mirrorwater Basin", "Greycrown Mountains", "Elderwood Deep Forest", "Sunfold Hills", "Southshore Coast"]
static func fresh_state(seed_value: int) -> Dictionary:
	return {"version":VERSION,"seed":seed_value,"day_time":0.32,"landscape_version":2}
static func validate_state(state: Dictionary) -> bool:
	return state.get("version",-1)==VERSION and state.get("seed") is int and is_finite(float(state.get("day_time",0.32)))
