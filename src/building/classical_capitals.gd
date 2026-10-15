extends RefCounted

const Carving := preload("res://src/building/capital_details.gd")
static var templates: Dictionary = {}

static func add(parts: Array, decoration: Array, detail: String) -> void:
	for original in decoration:
		var part: Dictionary = original.duplicate()
		part.detail = detail
		parts.append(part)

static func lathe(parts: Array, profile: Array, detail: String, pos: Vector3 = Vector3.ZERO, basis: Basis = Basis.IDENTITY, segments: int = 80) -> void:
	var decoration: Array = []
	ClassicalGeometry.lathe(decoration,profile,Vector3.ZERO,false,segments)
	decoration[0].transform = Transform3D(basis,pos)
	add(parts,decoration,detail)

static func build_doric() -> Array:
	var parts: Array = []
	lathe(parts,[Vector2(0.4,0),Vector2(0.41,0.03),Vector2(0.438,0.04),Vector2(0.445,0.055),Vector2(0.425,0.067),Vector2(0.443,0.08),Vector2(0.445,0.092),Vector2(0.426,0.105),Vector2(0.444,0.117),Vector2(0.44,0.135),Vector2(0.47,0.165),Vector2(0.505,0.205),Vector2(0.545,0.25),Vector2(0.585,0.31),Vector2(0.615,0.37),Vector2(0.63,0.415),Vector2(0.625,0.44)],"echinus",Vector3.ZERO,Basis.IDENTITY,96)
	parts.append({"mesh":Carving.plate([Vector3(0.735,0.44,0.685),Vector3(0.75,0.455,0.70),Vector3(0.75,0.585,0.70),Vector3(0.735,0.60,0.685)]),"transform":Transform3D.IDENTITY,"detail":"abacus"})
	return parts

static func build_ionic() -> Array:
	var parts: Array = []
	lathe(parts,[Vector2(0.4,0),Vector2(0.43,0.025),Vector2(0.44,0.045),Vector2(0.43,0.065),Vector2(0.445,0.08),Vector2(0.435,0.10),Vector2(0.47,0.13),Vector2(0.51,0.18),Vector2(0.545,0.24),Vector2(0.55,0.28),Vector2(0.54,0.31),Vector2(0.50,0.37),Vector2(0.47,0.44)],"echinus")
	parts.append({"mesh":Carving.plate([Vector3(0.70,0.445,0.64),Vector3(0.735,0.465,0.68),Vector3(0.75,0.485,0.7),Vector3(0.75,0.585,0.7),Vector3(0.738,0.6,0.688)]),"transform":Transform3D.IDENTITY,"detail":"abacus"})
	# True three-dimensional cushions connect the scroll faces at the sides.
	for side in [-1,1]:
		lathe(parts,[Vector2(0.21,-0.44),Vector2(0.215,-0.38),Vector2(0.18,-0.28),Vector2(0.16,-0.10),Vector2(0.155,0),Vector2(0.16,0.10),Vector2(0.18,0.28),Vector2(0.215,0.38),Vector2(0.21,0.44)],"bolsters",Vector3(side*0.54,0.285,0),Basis(Vector3.RIGHT,PI/2),64)
		lathe(parts,[Vector2(0.16,-0.045),Vector2(0.18,-0.035),Vector2(0.184,-0.02),Vector2(0.175,0),Vector2(0.184,0.02),Vector2(0.18,0.035),Vector2(0.16,0.045)],"bolster_belts",Vector3(side*0.54,0.285,0),Basis(Vector3.RIGHT,PI/2),64)
	for face in [-1,1]:
		for side in [-1,1]:
			var axis := Basis(Vector3.RIGHT,face*PI/2)
			# Recessed scroll field, raised rim and central eye support the spiral.
			lathe(parts,[Vector2(0,0),Vector2(0.22,0),Vector2(0.235,0.01),Vector2(0.24,0.025),Vector2(0.233,0.045),Vector2(0.217,0.047),Vector2(0.207,0.03),Vector2(0.025,0.03),Vector2(0.017,0.045),Vector2(0,0.05)],"volute_fields",Vector3(side*0.54,0.285,face*0.44),axis,80)
			var spiral := PackedVector3Array()
			for i in range(97):
				var t := i/96.0
				var angle := TAU*1.6*t
				var radius := lerpf(0.22,0.014,t)
				spiral.append(Vector3(side*(0.54+cos(angle)*radius),0.285+sin(angle)*radius,face*0.49))
			parts.append({"mesh":Carving.tube(spiral,0.018,Vector3.BACK),"transform":Transform3D.IDENTITY,"detail":"volutes"})
		var ribbon: Array = []
		ClassicalGeometry.box(ribbon,Vector3(1.06,0.10,0.085),Vector3(0,0.42,face*0.465),false)
		ClassicalGeometry.box(ribbon,Vector3(1.08,0.018,0.105),Vector3(0,0.465,face*0.47),false)
		ClassicalGeometry.box(ribbon,Vector3(0.93,0.018,0.08),Vector3(0,0.365,face*0.475),false)
		add(parts,ribbon,"channel")
		# Raised eggs sit in individually carved casings; pointed darts fill the gaps.
		for i in range(5):
			var x := (i-2)*0.13
			var z := sqrt(0.545*0.545-x*x)+0.018
			lathe(parts,[Vector2(0,-0.075),Vector2(0.014,-0.055),Vector2(0.031,-0.02),Vector2(0.039,0.02),Vector2(0.032,0.055),Vector2(0.017,0.073),Vector2(0,0.08)],"eggs",Vector3(x,0.285,face*z),Basis.IDENTITY,24)
			parts.append({"mesh":Carving.oval_ring(Vector2(0.052,0.092),Vector2(0.043,0.082),0.018),"transform":Transform3D(Basis.IDENTITY,Vector3(x,0.285,face*(z+0.012))),"detail":"egg_casings"})
		for i in range(4):
			var x := (i-1.5)*0.13
			var z := sqrt(0.545*0.545-x*x)+0.03
			var dart: Array = []
			ClassicalGeometry.polygon(dart,PackedVector2Array([Vector2(x-0.017,0.33),Vector2(x+0.017,0.33),Vector2(x,0.18)]),0.025,Vector3(0,0,face*z),false,false)
			add(parts,dart,"darts")
	for i in range(32):
		var angle := TAU*i/32
		lathe(parts,[Vector2(0,-0.012),Vector2(0.01,-0.009),Vector2(0.014,0),Vector2(0.01,0.009),Vector2(0,0.012)],"astragal",Vector3(0.443*cos(angle),0.07,0.443*sin(angle)),Basis.IDENTITY,12)
	return parts

static func append_to(parts: Array, style: String, y: float) -> void:
	if not templates.has(style):
		var capital := build_doric() if style == "doric" else build_ionic()
		# Retain the original collision and support planes for old buildings.
		ClassicalGeometry.cylinder(capital,0.44,0.6,0.4,Vector3(0,0.2,0),true)
		capital.back().erase("mesh")
		ClassicalGeometry.box(capital,Vector3(1.5,0.16,1.4),Vector3(0,0.52,0))
		capital.back().erase("mesh")
		templates[style] = Carving.batch_meshes(capital)
	for original in templates[style]:
		var part: Dictionary = original.duplicate()
		part.transform = Transform3D(Basis.IDENTITY,Vector3.UP*y)*original.transform
		parts.append(part)
