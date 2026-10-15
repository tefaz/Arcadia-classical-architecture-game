extends RefCounted

## Fit wall centre lines inside the exposed perimeter of a connected platform.
const Layout := preload("res://src/building/column_layout.gd")
const INSET := 0.22 # Half the wall foot/coping depth, shared by plain/window walls.
const EDGE_REACH := 0.7

static func intervals(rectangles: Array[Rect2], axis: int, sign_value: int, edge: float) -> Array[Vector2]:
	var exposed: Array[Vector2] = []
	for rect in rectangles:
		var boundary := rect.end.y if axis == 0 else rect.end.x
		if sign_value < 0: boundary = rect.position.y if axis == 0 else rect.position.x
		if absf(boundary-edge) > 0.005: continue
		var segments: Array[Vector2] = [Vector2(rect.position.x,rect.end.x) if axis == 0 else Vector2(rect.position.y,rect.end.y)]
		for peer in rectangles:
			var normal_low := peer.position.y if axis == 0 else peer.position.x
			var normal_high := peer.end.y if axis == 0 else peer.end.x
			var covers := normal_low <= edge+0.005 and normal_high > edge+0.005 if sign_value > 0 else normal_high >= edge-0.005 and normal_low < edge-0.005
			if not covers: continue
			var cut := Vector2(peer.position.x,peer.end.x) if axis == 0 else Vector2(peer.position.y,peer.end.y)
			var remaining: Array[Vector2] = []
			for segment in segments:
				if cut.y <= segment.x+0.005 or cut.x >= segment.y-0.005:
					remaining.append(segment)
					continue
				if cut.x > segment.x+0.005: remaining.append(Vector2(segment.x,cut.x))
				if cut.y < segment.y-0.005: remaining.append(Vector2(cut.y,segment.y))
			segments = remaining
		exposed.append_array(segments)
	exposed.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x)
	var merged: Array[Vector2] = []
	for segment in exposed:
		if merged.is_empty() or segment.x > merged[-1].y+0.005:
			merged.append(segment)
		else:
			merged[-1].y = maxf(merged[-1].y,segment.y)
	return merged

static func corner_offset(rectangles: Array[Rect2], axis: int, side: int, edge: float, along: float, end: int) -> float:
	var u := along+end*0.01
	var v := edge-side*0.01
	var point := Vector2(u,v) if axis == 0 else Vector2(v,u)
	# At a re-entrant corner the inset lines meet beyond, rather than inside,
	# the exposed segment. This also closes stepped and L-shaped platforms.
	for rect in rectangles:
		if rect.has_point(point): return end*INSET
	return -end*INSET

static func solve(kind: String, basis: Basis, hit: Dictionary, pieces: Array, anchor: int, length: float) -> Dictionary:
	var surface := hit.collider as BuildPiece
	if kind not in BuildCatalogue.WALL_KINDS or surface == null or surface.kind not in BuildCatalogue.FOUNDATION_KINDS: return {}
	if hit.normal.y < 0.95 or anchor != 0 or length != 0: return {}
	var alignment := absf(surface.basis.x.dot(basis.x))
	if alignment > 0.001 and alignment < 0.999: return {}
	var axis := 0 if alignment > 0.999 else 1
	var frame := surface.transform
	var local: Vector3 = frame.affine_inverse()*hit.position
	var point := Vector2(local.x,local.z)
	var rect := Layout.rect_of(surface,frame)
	var rectangles := Layout.platform(surface,pieces)
	var along := point.x if axis == 0 else point.y
	var across := point.y if axis == 0 else point.x
	var best := INF
	var result := {}
	for side in [-1,1]:
		var edge := rect.end.y if axis == 0 else rect.end.x
		if side < 0: edge = rect.position.y if axis == 0 else rect.position.x
		if absf(across-edge) > EDGE_REACH: continue
		for interval in intervals(rectangles,axis,side,edge):
			if along < interval.x-0.005 or along > interval.y+0.005: continue
			var bay := clampi(floori((along-interval.x)/BuildCatalogue.BAY),0,ceili((interval.y-interval.x)/BuildCatalogue.BAY)-1)
			var low := interval.x+bay*BuildCatalogue.BAY
			var high := minf(low+BuildCatalogue.BAY,interval.y)
			# Only the two exposed run ends are inset; interior bay seams stay put.
			if is_equal_approx(low,interval.x): low += corner_offset(rectangles,axis,side,edge,interval.x,-1)
			if is_equal_approx(high,interval.y): high += corner_offset(rectangles,axis,side,edge,interval.y,1)
			var span := snappedf(high-low,0.01)
			if span < BuildCatalogue.MIN_SPAN: continue
			var u := (low+high)/2
			var v: float = edge-side*INSET
			var height := BuildCatalogue.piece_size(surface.kind).y
			var position := frame*Vector3(u if axis == 0 else v,height,v if axis == 0 else u)
			var distance := absf(across-edge)
			if distance >= best: continue
			best = distance
			result = {"position":position,"length":span,"snapped":true,"target":surface,"socket":frame*Vector3(along if axis == 0 else edge,height,edge if axis == 0 else along),"label":"Foundation perimeter · flush outer face · %.2f m" % span,"score":0.0}
	return result
