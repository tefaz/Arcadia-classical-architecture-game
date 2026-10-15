extends RefCounted

## Stone sculpture with bottom-centred plinths. Reliefs face +Z; the full-depth lion faces +X.
static func ellipsoid(parts: Array, centre: Vector3, radii: Vector3) -> void:
	var profile: Array = []
	for i in range(17):
		var angle := PI*i/16.0
		profile.append(Vector2(0 if i in [0,16] else sin(angle),-cos(angle)))
	ClassicalGeometry.lathe(parts,profile,Vector3.ZERO,false,24)
	parts.back().transform = Transform3D(Basis.IDENTITY.scaled(radii),centre)

static func limb(parts: Array, a: Vector3, b: Vector3, start: float, end: float) -> void:
	var distance := a.distance_to(b)
	ClassicalGeometry.lathe(parts,[Vector2(start*0.7,0),Vector2(start,distance*0.13),Vector2(end,distance*0.86),Vector2(end*0.65,distance)],Vector3.ZERO,false,16)
	var basis := Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	parts.back().transform = Transform3D(basis,a)

static func head(parts: Array, centre: Vector3, scale_value: float = 1.0) -> void:
	ellipsoid(parts,centre,Vector3(0.12,0.165,0.105)*scale_value)
	ellipsoid(parts,centre+Vector3(0,0.07,-0.018)*scale_value,Vector3(0.132,0.115,0.108)*scale_value)
	# A cut nose, brow and lips read as a carved face even in the shallow silhouette.
	ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(-0.022,0.055),Vector2(0.022,0.055),Vector2(0.026,-0.036),Vector2(-0.026,-0.036)]),0.055*scale_value,centre+Vector3(0,0.005,0.1)*scale_value)
	for side in [-1,1]:
		limb(parts,centre+Vector3(side*0.025,0.045,0.10)*scale_value,centre+Vector3(side*0.09,0.028,0.087)*scale_value,0.017*scale_value,0.011*scale_value)
		for i in range(4):
			ellipsoid(parts,centre+Vector3(side*0.11,0.10-i*0.05,-0.014)*scale_value,Vector3(0.033,0.042,0.058)*scale_value)
	ellipsoid(parts,centre+Vector3(0,-0.067,0.087)*scale_value,Vector3(0.036,0.013,0.018)*scale_value)

static func standing(parts: Array) -> void:
	ClassicalGeometry.box(parts,Vector3(1.18,0.08,0.44),Vector3(0,0.04,0))
	# Flared chiton, gathered at the waist; narrow vertical ribs suggest folded fabric.
	ClassicalGeometry.lathe(parts,[Vector2(0.33,0.13),Vector2(0.32,0.22),Vector2(0.25,0.66),Vector2(0.20,1.03),Vector2(0.225,1.11)],Vector3.ZERO,true,96)
	parts.back().transform.basis = Basis.IDENTITY.scaled(Vector3(1,1,0.49))
	for i in range(9):
		var x := (i-4)*0.066
		limb(parts,Vector3(x,0.16,0.145),Vector3(x*0.59,1.06,0.105),0.019,0.011)
	ellipsoid(parts,Vector3(0,1.29,0),Vector3(0.25,0.29,0.145))
	ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(-0.29,1.53),Vector2(0.22,1.48),Vector2(0.15,1.03),Vector2(-0.17,0.78),Vector2(-0.27,0.30),Vector2(-0.36,0.23)]),0.065,Vector3(0,0,0.12))
	for i in range(5):
		limb(parts,Vector3(-0.25+i*0.085,1.48,0.17),Vector3(-0.22+i*0.065,1.05,0.17),0.018,0.012)
	limb(parts,Vector3(0,1.49,0),Vector3(0,1.72,0),0.075,0.065)
	head(parts,Vector3(0,1.83,0))
	for side in [-1,1]:
		ellipsoid(parts,Vector3(side*0.105,0.13,0.07),Vector3(0.09,0.055,0.145))
	limb(parts,Vector3(-0.23,1.47,0),Vector3(-0.40,1.18,0),0.085,0.065)
	limb(parts,Vector3(-0.40,1.18,0),Vector3(-0.42,0.97,0.065),0.065,0.045)
	limb(parts,Vector3(0.23,1.47,0),Vector3(0.40,1.17,0.02),0.085,0.06)
	limb(parts,Vector3(0.40,1.17,0.02),Vector3(0.49,1.39,0.04),0.06,0.04)
	ellipsoid(parts,Vector3(0.49,1.39,0.04),Vector3(0.06,0.06,0.06))
	limb(parts,Vector3(0.51,0.12,0.02),Vector3(0.51,2.08,0.02),0.015,0.015)
	ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(0.47,2.07),Vector2(0.55,2.07),Vector2(0.51,2.2)]),0.025,Vector3(0,0,0.02))
	ellipsoid(parts,Vector3(-0.40,0.84,0.07),Vector3(0.18,0.30,0.075))
	ellipsoid(parts,Vector3(-0.40,0.84,0.143),Vector3(0.055,0.065,0.025))
	ClassicalGeometry.box(parts,Vector3(0.65,1.82,0.36),Vector3(0,0.99,0))
	parts.back().erase("mesh")

static func reclining(parts: Array) -> void:
	ClassicalGeometry.box(parts,Vector3(2.8,0.06,0.44),Vector3(0,0.03,0))
	limb(parts,Vector3(-1.21,0.17,0),Vector3(-0.63,0.23,0),0.07,0.10)
	limb(parts,Vector3(-0.63,0.23,0),Vector3(0.02,0.28,0),0.10,0.15)
	limb(parts,Vector3(-1.15,0.14,0.10),Vector3(-0.46,0.43,0.06),0.07,0.11)
	limb(parts,Vector3(-0.46,0.43,0.06),Vector3(0.03,0.28,0.04),0.11,0.15)
	ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(-1.22,0.10),Vector2(-1.12,0.23),Vector2(-0.46,0.50),Vector2(0.22,0.38),Vector2(0.16,0.17)]),0.21,Vector3(0,0,0.04))
	for i in range(7):
		limb(parts,Vector3(-1.07+i*0.15,0.15,0.16),Vector3(-0.50+i*0.09,0.44-i*0.011,0.16),0.017,0.011)
	limb(parts,Vector3(0.02,0.29,0),Vector3(0.67,0.54,0),0.17,0.18)
	ellipsoid(parts,Vector3(0.57,0.53,0),Vector3(0.24,0.16,0.15))
	limb(parts,Vector3(0.70,0.55,0),Vector3(0.88,0.70,0),0.07,0.06)
	head(parts,Vector3(0.96,0.77,0),0.85)
	limb(parts,Vector3(0.68,0.54,-0.035),Vector3(1.19,0.30,-0.02),0.075,0.055)
	limb(parts,Vector3(1.19,0.30,-0.02),Vector3(1.23,0.10,0.04),0.055,0.04)
	limb(parts,Vector3(0.61,0.56,0.10),Vector3(0.35,0.29,0.14),0.075,0.05)
	limb(parts,Vector3(0.35,0.29,0.14),Vector3(0.01,0.33,0.15),0.05,0.04)
	ClassicalGeometry.box(parts,Vector3(2.58,0.36,0.36),Vector3(0,0.24,0))
	parts.back().erase("mesh")
	ClassicalGeometry.box(parts,Vector3(0.62,0.38,0.32),Vector3(0.77,0.60,0))
	parts.back().erase("mesh")

static func horse(parts: Array) -> void:
	ClassicalGeometry.box(parts,Vector3(2.8,0.06,0.44),Vector3(0,0.03,0))
	ellipsoid(parts,Vector3(-0.21,0.95,0),Vector3(0.70,0.29,0.19))
	ellipsoid(parts,Vector3(-0.68,0.93,0),Vector3(0.28,0.31,0.18))
	ellipsoid(parts,Vector3(0.26,1.02,0),Vector3(0.25,0.33,0.18))
	# Bent hind legs and an extended, raised foreleg give a readable equine pose.
	for z in [-0.10,0.11]:
		var offset := -0.13 if z < 0 else 0.0
		limb(parts,Vector3(-0.66,0.89,z),Vector3(-0.47+offset,0.53,z),0.13,0.07)
		limb(parts,Vector3(-0.47+offset,0.53,z),Vector3(-0.78+offset,0.14,z),0.07,0.045)
		ellipsoid(parts,Vector3(-0.76+offset,0.11,z+0.015),Vector3(0.10,0.055,0.07))
	limb(parts,Vector3(0.27,1.03,-0.1),Vector3(0.36,0.57,-0.1),0.12,0.06)
	limb(parts,Vector3(0.36,0.57,-0.1),Vector3(0.52,0.14,-0.1),0.06,0.04)
	ellipsoid(parts,Vector3(0.56,0.11,-0.09),Vector3(0.10,0.055,0.07))
	limb(parts,Vector3(0.29,1.02,0.11),Vector3(0.69,0.66,0.11),0.12,0.065)
	limb(parts,Vector3(0.69,0.66,0.11),Vector3(0.99,0.84,0.11),0.065,0.04)
	ellipsoid(parts,Vector3(1.03,0.85,0.12),Vector3(0.10,0.055,0.07))
	ClassicalGeometry.polygon(parts,PackedVector2Array([Vector2(0.04,0.98),Vector2(0.31,1.46),Vector2(0.45,1.71),Vector2(0.72,1.64),Vector2(0.66,1.32),Vector2(0.43,0.91)]),0.28,Vector3.ZERO)
	ellipsoid(parts,Vector3(0.66,1.62,0),Vector3(0.23,0.15,0.13))
	limb(parts,Vector3(0.71,1.59,0),Vector3(1.02,1.40,0),0.125,0.085)
	ellipsoid(parts,Vector3(1.03,1.41,0),Vector3(0.12,0.085,0.10))
	for z in [-0.07,0.07]:
		limb(parts,Vector3(0.55,1.68,z),Vector3(0.49,1.85,z),0.06,0.009)
		ellipsoid(parts,Vector3(0.77,1.65,z*1.7),Vector3(0.026,0.025,0.018))
	for i in range(10):
		var t := i/9.0
		limb(parts,Vector3(0.42-t*0.32,1.69-t*0.58,-0.035),Vector3(0.28-t*0.34,1.61-t*0.57,0.13),0.045,0.018)
	for i in range(5):
		var x := -0.81-i*0.095
		limb(parts,Vector3(x,1.07-i*0.05,0),Vector3(x-0.09,0.99-i*0.11,0.025),0.08-i*0.01,0.055-i*0.009)
	ClassicalGeometry.box(parts,Vector3(1.5,0.54,0.38),Vector3(-0.22,0.95,0))
	parts.back().erase("mesh")
	ClassicalGeometry.box(parts,Vector3(0.56,0.59,0.28),Vector3(0.55,1.45,0))
	parts.back().erase("mesh")

static func lion(parts: Array) -> void:
	ClassicalGeometry.box(parts,Vector3(2.8,0.10,1.25),Vector3(0,0.05,0))
	# A low reclining body, folded haunches and straight forepaws form a guardian pose.
	ellipsoid(parts,Vector3(-0.25,0.59,0),Vector3(0.77,0.32,0.37))
	ellipsoid(parts,Vector3(-0.83,0.49,0),Vector3(0.42,0.35,0.40))
	ellipsoid(parts,Vector3(0.35,0.70,0),Vector3(0.38,0.44,0.38))
	for side in [-1,1]:
		var z: float = side*0.31
		ellipsoid(parts,Vector3(-0.80,0.37,z),Vector3(0.36,0.25,0.21))
		ellipsoid(parts,Vector3(-0.46,0.18,z),Vector3(0.28,0.08,0.17))
		limb(parts,Vector3(0.36,0.61,z),Vector3(0.66,0.27,z),0.16,0.105)
		limb(parts,Vector3(0.66,0.27,z),Vector3(1.04,0.21,z),0.105,0.10)
		ellipsoid(parts,Vector3(1.08,0.20,z),Vector3(0.27,0.10,0.18))
		for toe in range(3):
			ellipsoid(parts,Vector3(1.27,0.17,z+(toe-1)*0.095),Vector3(0.10,0.07,0.042))
	# Full mane with overlapping swept locks, carved in the same stone as the body.
	ellipsoid(parts,Vector3(0.55,1.02,0),Vector3(0.32,0.48,0.43))
	for row in range(2):
		for i in range(28):
			var angle := TAU*(i+row*0.5)/28.0
			var radial := Vector3(0,sin(angle),cos(angle))
			var a := Vector3(0.69-row*0.18,1.10,0)+radial*(0.29+row*0.04)
			var b := Vector3(0.52-row*0.18,0.99,0)+radial*(0.43+row*0.025)
			var c := Vector3(0.30-row*0.15,0.90,0)+radial*(0.40+row*0.025)
			var lock := PackedVector3Array()
			for j in range(9):
				var t := j/8.0
				lock.append(a*(1-t)*(1-t)+b*2*t*(1-t)+c*t*t)
			parts.append({"mesh":preload("res://src/building/capital_details.gd").tube(lock,0.052,radial),"transform":Transform3D.IDENTITY})
	ellipsoid(parts,Vector3(0.79,1.20,0),Vector3(0.28,0.30,0.29))
	# Rounded ears, brows and recessed eyes frame the broad feline muzzle.
	for side in [-1,1]:
		ellipsoid(parts,Vector3(0.68,1.51,side*0.255),Vector3(0.085,0.09,0.055))
		ellipsoid(parts,Vector3(0.94,1.26,side*0.21),Vector3(0.045,0.027,0.015))
		limb(parts,Vector3(0.87,1.31,side*0.23),Vector3(1.02,1.28,side*0.17),0.035,0.025)
		ellipsoid(parts,Vector3(1.015,1.115,side*0.085),Vector3(0.19,0.125,0.14))
	ellipsoid(parts,Vector3(1.185,1.165,0),Vector3(0.055,0.045,0.085))
	ellipsoid(parts,Vector3(1.02,1.045,0),Vector3(0.15,0.055,0.17))
	# The tail curls along the rear flank, ending in a carved tuft.
	var tail := PackedVector3Array()
	for i in range(25):
		var t := i/24.0
		var angle := lerpf(-PI*0.6,PI*0.75,t)
		tail.append(Vector3(-0.77-0.48*cos(angle),0.22+0.10*(1-t),-0.29-0.22*sin(angle)))
	parts.append({"mesh":preload("res://src/building/capital_details.gd").tube(tail,0.042,Vector3.UP),"transform":Transform3D.IDENTITY})
	ellipsoid(parts,tail[-1],Vector3(0.105,0.065,0.075))
	# Simple aimable body volumes leave the gaps beneath the head and between paws open.
	ClassicalGeometry.box(parts,Vector3(1.75,0.60,0.82),Vector3(-0.30,0.48,0))
	parts.back().erase("mesh")
	ClassicalGeometry.box(parts,Vector3(0.90,0.95,0.85),Vector3(0.58,0.99,0))
	parts.back().erase("mesh")

static func recipe(id: String) -> Array:
	var parts: Array = []
	match id:
		"draped_statue": standing(parts)
		"reclining_figure": reclining(parts)
		"horse_relief": horse(parts)
		"lion_statue": lion(parts)
	# Bake the carved details into one shared mesh to keep repeated friezes inexpensive.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var result: Array = []
	for part in parts:
		if part.has("mesh"):
			# Primitive meshes are indexed and carved surfaces are not. Expand both before
			# combining them, otherwise only the indexed plinth appears in the final mesh.
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var normal_basis: Basis = part.transform.basis.inverse().transposed()
			for i in range(indices.size() if not indices.is_empty() else vertices.size()):
				var index := indices[i] if not indices.is_empty() else i
				surface.set_normal((normal_basis*normals[index]).normalized())
				surface.add_vertex(part.transform*vertices[index])
		if part.has("shape"):
			var collider: Dictionary = part.duplicate()
			collider.erase("mesh")
			result.append(collider)
	result.append({"mesh":surface.commit(),"transform":Transform3D.IDENTITY})
	return result
