class_name GameModeState
extends RefCounted

## Stable mode names are saved with each sanctuary. Survival is reserved for a later update.
enum Mode { CREATIVE, SURVIVAL }
const SURVIVAL_AVAILABLE := false

var mode: Mode = Mode.CREATIVE

func is_creative() -> bool:
	return mode == Mode.CREATIVE

func allows_flight() -> bool:
	return is_creative()

func display_name() -> String:
	return "Creative" if is_creative() else "Survival"

func serialize() -> String:
	return "creative" if is_creative() else "survival"

func restore(value: Variant) -> void:
	mode = Mode.SURVIVAL if value == "survival" and SURVIVAL_AVAILABLE else Mode.CREATIVE
