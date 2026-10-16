extends RefCounted

## A real floor-level opening. No hidden full-wall collider or threshold spans it.
const OPENING_WIDTH := 1.8
const OPENING_HEIGHT := 2.7

static func recipe(length: float) -> Array:
	var parts: Array = []
	var scale_x := minf(1.0,length/4)
	var half_opening := OPENING_WIDTH*scale_x/2
	var pier := length/2-half_opening
	for side in [-1,1]:
		var centre: float = side*(half_opening+pier/2)
		ClassicalGeometry.box(parts,Vector3(pier,4.1,0.32),Vector3(centre,2.05,0))
		# A split moulded foot leaves the walking surface completely unobstructed.
		ClassicalGeometry.box(parts,Vector3(pier,0.15,0.44),Vector3(centre,0.075,0),false)
		for row in range(8):
			var start := half_opening
			while start < length/2-0.001:
				var width := minf(0.5 if row%2 == 1 and is_equal_approx(start,half_opening) else 1.0,length/2-start)
				ClassicalGeometry.box(parts,Vector3(maxf(width-0.025,0.01),0.47,0.37),Vector3(side*(start+width/2),0.28+row*0.5,0),false)
				start += width
	ClassicalGeometry.box(parts,Vector3(half_opening*2,4.1-OPENING_HEIGHT,0.32),Vector3(0,(4.1+OPENING_HEIGHT)/2,0))
	ClassicalGeometry.box(parts,Vector3(length,0.14,0.44),Vector3(0,4.03,0),false)
	# Dress the head above the doorway without putting masonry across the aperture.
	for row in [0,1]:
		ClassicalGeometry.box(parts,Vector3(half_opening*2-0.012,0.47,0.37),Vector3(0,2.99+row*0.5,0),false)
	for face in [-1,1]:
		var z: float = face*0.24
		var jamb := 0.19*scale_x
		for side in [-1,1]:
			var x: float = side*(half_opening+jamb/2)
			ClassicalGeometry.box(parts,Vector3(jamb,OPENING_HEIGHT,0.18),Vector3(x,OPENING_HEIGHT/2,z),false)
			ClassicalGeometry.box(parts,Vector3(jamb*0.45,OPENING_HEIGHT-0.16,0.035),Vector3(x+side*jamb*0.14,OPENING_HEIGHT/2,z+face*0.105),false)
			ClassicalGeometry.box(parts,Vector3(jamb,0.16,0.22),Vector3(x,0.08,z),false)
		# Layered lintel and cornice support a recessed triangular tympanum.
		ClassicalGeometry.box(parts,Vector3(2.22*scale_x,0.16,0.20),Vector3(0,2.78,z),false)
		ClassicalGeometry.box(parts,Vector3(2.34*scale_x,0.07,0.22),Vector3(0,2.91,z),false)
		ClassicalGeometry.box(parts,Vector3(2.55*scale_x,0.10,0.24),Vector3(0,3.02,z),false)
		ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(-1.18*scale_x,3.07),Vector2(1.18*scale_x,3.07),Vector2(0,3.77)]),0.12,Vector3(0,0,z),false,false)
		for side in [-1,1]:
			ClassicalGeometry.beam(parts,Vector3(side*1.22*scale_x,3.08,z+face*0.035),Vector3(0,3.82,z+face*0.035),0.11*scale_x,0.17)
			ClassicalGeometry.beam(parts,Vector3(side*1.10*scale_x,3.12,z+face*0.045),Vector3(0,3.74,z+face*0.045),0.035*scale_x,0.12)
	return parts
