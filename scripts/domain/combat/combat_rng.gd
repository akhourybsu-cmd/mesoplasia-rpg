class_name CombatRng
extends RefCounted

const UINT32_MASK := 0xFFFFFFFF

var _state := 1
var _draw_count := 0


func configure(seed: int, draw_count: int = 0) -> void:
	_state = seed & UINT32_MASK
	if _state == 0:
		_state = 1
	_draw_count = maxi(draw_count, 0)


func next_u32() -> int:
	_state = (_state * 1664525 + 1013904223) & UINT32_MASK
	_draw_count += 1
	return _state


func range_inclusive(minimum: int, maximum: int) -> int:
	if maximum <= minimum:
		return minimum
	return minimum + int(next_u32() % (maximum - minimum + 1))


func choose_index(count: int) -> int:
	return range_inclusive(0, count - 1) if count > 0 else -1


func get_state() -> Dictionary:
	return {"state": _state, "draw_count": _draw_count}


func restore_state(snapshot: Dictionary) -> bool:
	if not snapshot.has("state") or not snapshot.has("draw_count"):
		return false
	configure(int(snapshot.state), int(snapshot.draw_count))
	return true
