extends RefCounted

## Real openings, with solid reveals and classical surrounds on both wall faces.
static func recipe(id: String, length: float) -> Array:
	var parts: Array = []
	var scale_x := minf(1.0,length/4)
	var opening := 0.8*scale_x
	var sill := 1.0
	var spring := 2.55 if id == "wall_window_ellipse" else 2.85
	var pier := length/2-opening
	for side in [-1,1]:
		ClassicalGeometry.box(parts,Vector3(pier,4.1,0.32),Vector3(side*(opening+pier/2),2.05,0))
		for row in range(8):
			var start := opening
			while start < length/2-0.001:
				var width := minf(0.5 if row%2 else 1.0,length/2-start)
				ClassicalGeometry.box(parts,Vector3(maxf(width-0.025,0.01),0.47,0.37),Vector3(side*(start+width/2),0.28+row*0.5,0),false)
				start += width
	ClassicalGeometry.box(parts,Vector3(opening*2,sill,0.32),Vector3(0,sill/2,0))
	for row in range(2):
		ClassicalGeometry.box(parts,Vector3(opening*2-0.012,0.47,0.37),Vector3(0,0.28+row*0.5,0),false)
	if id == "wall_window_ellipse":
		# Each strip above the elliptical opening is a convex solid; no hidden
		# full-wall collider blocks the hole or the curved intrados.
		for i in range(24):
			var a := PI*i/24.0
			var b := PI*(i+1)/24.0
			var p := Vector2(opening*cos(a),spring+0.65*sin(a))
			var q := Vector2(opening*cos(b),spring+0.65*sin(b))
			ClassicalGeometry.polygon(parts,PackedVector2Array([p,q,Vector2(q.x,3.3),Vector2(p.x,3.3)]),0.32,Vector3.ZERO,false,true)
		ClassicalGeometry.box(parts,Vector3(opening*2,0.8,0.32),Vector3(0,3.7,0))
	else:
		ClassicalGeometry.box(parts,Vector3(opening*2,4.1-spring,0.32),Vector3(0,(4.1+spring)/2,0))
	ClassicalGeometry.box(parts,Vector3(length,0.15,0.44),Vector3(0,0.075,0),false)
	ClassicalGeometry.box(parts,Vector3(length,0.14,0.44),Vector3(0,4.03,0),false)
	ClassicalGeometry.box(parts,Vector3(opening*2-0.012,0.47,0.37),Vector3(0,3.78,0),false)
	for face in [-1,1]:
		var z: float = face*0.24
		var jamb := 0.18*scale_x
		for side in [-1,1]:
			ClassicalGeometry.box(parts,Vector3(jamb,spring-sill,0.18),Vector3(side*(opening+jamb/2),(sill+spring)/2,z),false)
		ClassicalGeometry.box(parts,Vector3(2.2*scale_x,0.12,0.24),Vector3(0,0.94,z),false)
		ClassicalGeometry.box(parts,Vector3(2.0*scale_x,0.08,0.18),Vector3(0,0.84,z),false)
		if id == "wall_window_ellipse":
			for i in range(24):
				var a := PI*i/24.0
				var b := PI*(i+1)/24.0
				var points := PackedVector2Array([Vector2(opening*cos(a),spring+0.65*sin(a)),Vector2((opening+jamb)*cos(a),spring+0.81*sin(a)),Vector2((opening+jamb)*cos(b),spring+0.81*sin(b)),Vector2(opening*cos(b),spring+0.65*sin(b))])
				ClassicalGeometry.polygon(parts,points,0.18,Vector3(0,0,z),false,false)
			for side in [-1,1]:
				ClassicalGeometry.box(parts,Vector3(jamb+0.08*scale_x,0.10,0.22),Vector3(side*(opening+jamb/2),spring-0.05,z),false)
		else:
			ClassicalGeometry.box(parts,Vector3(2.02*scale_x,0.14,0.20),Vector3(0,2.92,z),false)
			if id == "wall_window_segmental":
				preload("res://src/building/segmental_pediment.gd").append_to(parts,scale_x,face)
			else:
				ClassicalGeometry.box(parts,Vector3(2.45*scale_x,0.10,0.24),Vector3(0,3.06,z),false)
				ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(-1.13*scale_x,3.10),Vector2(1.13*scale_x,3.10),Vector2(0,3.67)]),0.12,Vector3(0,0,z),false,false)
				for side in [-1,1]:
					ClassicalGeometry.beam(parts,Vector3(side*1.16*scale_x,3.12,z),Vector3(0,3.71,z),0.09,0.24)
	return parts
