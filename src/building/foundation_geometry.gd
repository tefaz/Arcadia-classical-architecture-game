extends RefCounted

## Flush masonry modules and decorative paving share the existing socket dimensions.
static func masonry(parts: Array, size: Vector3, bottom: float, rows: int, block_width: float = 2.0) -> void:
	# A solid core backs shallow face stones. The joints are real recesses, never
	# projecting shelves or repeated foundation mouldings between the courses.
	ClassicalGeometry.box(parts,Vector3(size.x-0.04,size.y,size.z-0.04),Vector3(0,bottom+size.y/2,0))
	parts.back().shape.size = size
	var course := size.y/rows
	for axis in [0,2]:
		var width := size.x if axis == 2 else size.z
		var depth := size.z if axis == 2 else size.x
		for side in [-1,1]:
			for row in range(rows):
				var start := -width/2
				while start < width/2-0.001:
					var span := minf(block_width/2 if row%2 == 1 and is_equal_approx(start,-width/2) else block_width,width/2-start)
					var stone_size := Vector3(span-0.018,course-0.018,0.025) if axis == 2 else Vector3(0.025,course-0.018,span-0.018)
					var pos := Vector3(start+span/2,bottom+(row+0.5)*course,side*(depth/2-0.0125)) if axis == 2 else Vector3(side*(depth/2-0.0125),bottom+(row+0.5)*course,start+span/2)
					ClassicalGeometry.box(parts,stone_size,pos,false)
					start += span

static func paving(parts: Array, size: Vector3, courtyard: bool) -> void:
	ClassicalGeometry.box(parts,Vector3(size.x,0.32,size.z),Vector3(0,0.16,0),false)
	var border := minf(0.48 if courtyard else 0.26,minf(size.x,size.z)*0.22)
	for side in [-1,1]:
		ClassicalGeometry.box(parts,Vector3(size.x,0.08,border),Vector3(0,0.36,side*(size.z-border)/2),false)
		ClassicalGeometry.box(parts,Vector3(border,0.08,size.z-border*2),Vector3(side*(size.x-border)/2,0.36,0),false)
	var inner := Vector2(size.x,size.z)-Vector2.ONE*(border*2+0.02)
	var columns := 4
	var rows := 4 if courtyard else 2
	var tile := inner/Vector2(columns,rows)
	for x in range(columns):
		for z in range(rows):
			if courtyard and x in [1,2] and z in [1,2]: continue
			ClassicalGeometry.box(parts,Vector3(tile.x-0.018,0.08,tile.y-0.018),Vector3(-inner.x/2+(x+0.5)*tile.x,0.36,-inner.y/2+(z+0.5)*tile.y),false)
	if courtyard:
		var radius := tile.x-0.012
		var panels: Array = [PackedVector2Array([Vector2(0,-radius),Vector2(radius,0),Vector2(0,radius),Vector2(-radius,0)])]
		for x in [-1,1]:
			for z in [-1,1]:
				panels.append(PackedVector2Array([Vector2(x*radius,z*radius),Vector2(x*radius,0),Vector2(0,z*radius)]))
		for panel in panels:
			var centre := Vector2.ZERO
			for point in panel: centre += point
			centre /= panel.size()
			var area := 0.0
			for i in range(panel.size()):
				area += panel[i].cross(panel[(i+1)%panel.size()])
				panel[i] = panel[i].move_toward(centre,0.012)
			if area < 0: panel.reverse()
			var part := ClassicalGeometry._prism(panel,0.32,0.4)
			part.erase("shape")
			parts.append(part)
	# The paving joints remain walkable and every support socket has the same top height.
	ClassicalGeometry.box(parts,size,Vector3(0,size.y/2,0))
	parts.back().erase("mesh")

static func recipe(id: String, fitted_size: Vector3 = Vector3.ZERO) -> Array:
	var parts: Array = []
	var size: Vector3 = BuildCatalogue.get_piece(id).size if fitted_size == Vector3.ZERO else fitted_size
	match id:
		"foundation", "foundation_raised", "foundation_podium":
			# Flush ashlar modules share a 40 cm course. No projecting feet or
			# crowns leave shelves when blocks repeat sideways or vertically.
			masonry(parts,size,0,roundi(size.y/0.4))
		"foundation_long", "foundation_large":
			paving(parts,size,id == "foundation_large")
		"step_support":
			masonry(parts,size,0,1)
	return parts
