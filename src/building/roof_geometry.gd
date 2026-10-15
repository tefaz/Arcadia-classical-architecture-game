extends RefCounted

## Thin tiled shells share the pediments' 0.6 pitch and exact module boundaries.
static func recipe(id: String, back_gable: bool = false, front_gable: bool = false) -> Array:
	var parts: Array = []
	var size := BuildCatalogue.piece_size(id)
	var left := BuildCatalogue.roof_profile(id) in ["left","left_half"]
	var stone := id in BuildCatalogue.STONE_ROOF_KINDS
	var slope := 0.6 if left else -0.6
	var a := Vector2(-size.x/2,0 if left else size.y)
	var b := Vector2(size.x/2,size.y if left else 0)
	# Keep logical depth bays at four metres while cutting the end shell back
	# to a gable's inside face, leaving its cornice and ridge finial clear.
	var z_min := -2.0+(0.35 if back_gable else 0.0)
	var z_max := 2.0-(0.35 if front_gable else 0.0)
	var depth := z_max-z_min
	var centre := (z_min+z_max)/2
	# The shell rests above the eave support plane, leaving the room empty.
	strip(parts,a,b,0,0.10,depth,centre,true,not stone)
	if stone:
		# Broad staggered slabs sit on a continuous shell, so the recessed
		# joints remain walkable and share exactly the tiled roof's pitch.
		for row in range(4):
			var low_z := maxf(z_min,-2+row+0.009)
			var high_z := minf(z_max,-1+row-0.009)
			if high_z <= low_z: continue
			var x := a.x
			while x < b.x-0.001:
				var width := minf(0.5 if row%2 == 1 and is_equal_approx(x,a.x) else 1.0,b.x-x)
				var p := Vector2(x+0.009,a.y+(x+0.009-a.x)*slope)
				var q := Vector2(x+width-0.009,a.y+(x+width-0.009-a.x)*slope)
				strip(parts,p,q,0.10,0.14,high_z-low_z,(high_z+low_z)/2,false,false)
				x += width
		return parts
	# Tile courses and cover ribs stop at the module planes, so repetition
	# never doubles an overhang or opens a gap along the pitch or depth.
	for i in range(roundi(size.x/0.25)):
		var x := a.x+(i+0.5)*0.25
		var y := a.y+(x-a.x)*slope
		strip(parts,Vector2(x-0.02,y-0.02*slope),Vector2(x+0.02,y+0.02*slope),0.10,0.13,depth,centre,false)
	for i in range(12):
		var z := -2+(i+0.5)/3.0
		var low := maxf(z_min,z-0.025)
		var high := minf(z_max,z+0.025)
		if high > low: strip(parts,a,b,0.10,0.15,high-low,(high+low)/2,false)
	return parts

static func strip(parts: Array, a: Vector2, b: Vector2, low: float, high: float, depth: float, z: float, collision: bool, tile: bool = true) -> void:
	var points := PackedVector2Array([a+Vector2(0,low),b+Vector2(0,low),b+Vector2(0,high),a+Vector2(0,high)])
	ClassicalGeometry.polygon(parts,points,depth,Vector3(0,0,z),tile,collision)
