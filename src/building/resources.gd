class_name ResourceLedger
extends RefCounted

## Placement depends on this service, so survival can be added without rewriting the builder.
var game_mode := GameModeState.new()
var creative: bool:
	get:
		return game_mode.is_creative()
	set(value):
		game_mode.mode = GameModeState.Mode.CREATIVE if value else GameModeState.Mode.SURVIVAL
var inventory: Dictionary = {}

func can_afford(cost: Dictionary) -> bool:
	if creative:
		return true
	for resource in cost:
		if inventory.get(resource, 0) < cost[resource]:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	if not creative:
		for resource in cost:
			inventory[resource] = inventory.get(resource, 0) - cost[resource]
	return true

func refund(cost: Dictionary) -> void:
	if not creative:
		for resource in cost:
			inventory[resource] = inventory.get(resource, 0) + cost[resource]
