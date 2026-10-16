extends RefCounted
## Discover closed wall rectangles and tile their outer coping footprint.
## Panel origins retain normal bay spacing; only the last edge panel is fitted.

const EPS := 0.005
const KINDS := ["flat_roof"]+BuildCatalogue.FOUNDATION_KINDS
const WALLS := BuildCatalogue.WALL_KINDS+["arch"]
static var room_cache: Dictionary = {}
static var recipe_cache: Dictionary = {}

static func _point(point: Vector2) -> Vector2:
	return point.snapped(Vector2.ONE*0.001)

static func _covered(intervals: Array[Vector2], low: float, high: float) -> bool:
	intervals.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	var end := low
	for interval in intervals:
		if interval.x > end+EPS: return false
		end = maxf(end,interval.y)
	return end >= high-EPS

static func rooms(basis: Basis, height: float, pieces: Array) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	var stamp: Array = [basis,height]
	var inverse := basis.inverse()
	for peer in pieces:
		if peer.kind not in WALLS or absf(peer.position.y+BuildCatalogue.piece_size(peer.kind).y-height) > EPS: continue
		var along: Vector3 = inverse*peer.basis.x
		if maxf(absf(along.x),absf(along.z)) < 0.9999: continue
		var centre: Vector3 = inverse*peer.position
		var a := Vector2(centre.x-along.x*peer.span_length/2,centre.z-along.z*peer.span_length/2)
		var b := Vector2(centre.x+along.x*peer.span_length/2,centre.z+along.z*peer.span_length/2)
		walls.append({"a":a,"b":b,"id":peer.get_instance_id(),"pad":0.35 if peer.kind == "arch" else 0.22})
		stamp.append([peer.get_instance_id(),peer.transform,peer.span_length])
	if walls.size() < 4: return []
	var key := stamp.hash()
	if room_cache.has(key): return room_cache[key]
	var endpoints := {}
	for i in range(walls.size()):
		for point in [walls[i].a,walls[i].b]:
			var p := _point(point)
			if not endpoints.has(p): endpoints[p] = []
			endpoints[p].append(i)
	var visited := {}
	var result: Array[Dictionary] = []
	for start in range(walls.size()):
		if visited.has(start): continue
		var pending: Array[int] = [start]
		var members: Array[Dictionary] = []
		visited[start] = true
		while not pending.is_empty():
			var index: int = pending.pop_back()
			members.append(walls[index])
			for point in [walls[index].a,walls[index].b]:
				for neighbor in endpoints[_point(point)]:
					if visited.has(neighbor): continue
					visited[neighbor] = true
					pending.append(neighbor)
		if members.size() < 4: continue
		var low: Vector2 = members[0].a
		var high := low
		for wall in members:
			low = low.min(wall.a).min(wall.b)
			high = high.max(wall.a).max(wall.b)
		if (high-low).x < 0.5 or (high-low).y < 0.5: continue
		var padding_low := Vector2.ZERO
		var padding_high := Vector2.ZERO
		var complete := true
		for axis in range(2):
			for side in [-1,1]:
				var edge: float = low[axis] if side < 0 else high[axis]
				var intervals: Array[Vector2] = []
				var padding := 0.0
				for wall in members:
					if absf(wall.a[axis]-edge) > EPS or absf(wall.b[axis]-edge) > EPS: continue
					intervals.append(Vector2(minf(wall.a[1-axis],wall.b[1-axis]),maxf(wall.a[1-axis],wall.b[1-axis])))
					padding = maxf(padding,wall.pad)
				complete = complete and _covered(intervals,low[1-axis],high[1-axis])
				if side < 0: padding_low[axis] = padding
				else: padding_high[axis] = padding
		if complete:
			result.append({"rect":Rect2(low-padding_low,high-low+padding_low+padding_high),"members":members.map(func(wall): return wall.id)})
	if room_cache.size() >= 64: room_cache.clear()
	room_cache[key] = result
	return result

static func _count(extent: float, bay: float) -> int:
	# A centre-line room can be one coping depth wider than standard modules.
	# Absorb that small remainder in the edge panel instead of adding a sliver.
	return maxi(1,ceili((extent-0.44-EPS)/bay))

static func _cell(rect: Rect2, size: Vector2, index: Vector2i) -> Rect2:
	var low := rect.position+Vector2(index)*size
	var high := low+size
	if index.x == _count(rect.size.x,size.x)-1: high.x = rect.end.x
	if index.y == _count(rect.size.y,size.y)-1: high.y = rect.end.y
	return Rect2(low,high-low)

static func candidates(kind: String, basis: Basis, hit: Dictionary, pieces: Array, anchor: int) -> Array[Dictionary]:
	var surface := hit.collider as BuildPiece
	if kind not in KINDS or surface == null: return []
	if kind == "flat_roof" and anchor != 1: return []
	var height := 0.0
	var from_wall := surface.kind in WALLS
	if from_wall:
		height = surface.position.y+BuildCatalogue.piece_size(surface.kind).y
		if hit.normal.y < -0.1 or hit.position.y < height-0.8: return []
	elif surface.kind in KINDS and absf(hit.normal.y) < 0.1:
		height = surface.position.y
	else: return []
	var local: Vector3 = basis.inverse()*(hit.position if from_wall else hit.position+hit.normal*0.15)
	var size3 := BuildCatalogue.piece_size(kind)
	var size := Vector2(size3.x,size3.z)
	for room in rooms(basis,height,pieces):
		if from_wall and surface.get_instance_id() not in room.members: continue
		var rect: Rect2 = room.rect
		if not from_wall and not rect.grow(EPS).has_point(Vector2(local.x,local.z)): continue
		var index := Vector2i(floori((local.x-rect.position.x)/size.x),floori((local.z-rect.position.y)/size.y))
		index.x = clampi(index.x,0,_count(rect.size.x,size.x)-1)
		index.y = clampi(index.y,0,_count(rect.size.y,size.y)-1)
		var centre := rect.position+Vector2(index)*size+size/2
		var position := basis*Vector3(centre.x,height,centre.y)
		var label := "Flush wall cover · fitted to outer faces · "+("T manual anchors" if kind == "flat_roof" else "Alt free placement")
		return [{"position":position,"length":BuildCatalogue.BAY,"snapped":true,"target":surface,"socket":Vector3(hit.position.x,height,hit.position.z),"label":label,"score":0.0}]
	return []

static func rectangle(kind: String, frame: Transform3D, pieces: Array) -> Rect2:
	var size3 := BuildCatalogue.piece_size(kind)
	var size := Vector2(size3.x,size3.z)
	var original := Rect2(-size/2,size)
	if kind not in KINDS: return original
	var local: Vector3 = frame.basis.inverse()*frame.origin
	for room in rooms(frame.basis,frame.origin.y,pieces):
		var rect: Rect2 = room.rect
		var coordinate := (Vector2(local.x,local.z)-rect.position-size/2)/size
		var index := Vector2i(roundi(coordinate.x),roundi(coordinate.y))
		if index.x < 0 or index.x >= _count(rect.size.x,size.x) or index.y < 0 or index.y >= _count(rect.size.y,size.y): continue
		if (coordinate-Vector2(index)).length() > 0.001: continue
		var cell := _cell(rect,size,index)
		return Rect2(cell.position-Vector2(local.x,local.z),cell.size)
	return original

static func foundation_recipe(kind: String, rect: Rect2) -> Array:
	var key := "%s:%.4f:%.4f:%.4f:%.4f" % [kind,rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	if recipe_cache.has(key): return recipe_cache[key]
	var parts: Array = preload("res://src/building/foundation_geometry.gd").recipe(kind,Vector3(rect.size.x,BuildCatalogue.piece_size(kind).y,rect.size.y))
	for part in parts:
		part.transform.origin += Vector3(rect.get_center().x,0,rect.get_center().y)
	if recipe_cache.size() >= 128: recipe_cache.clear()
	recipe_cache[key] = parts
	return parts
