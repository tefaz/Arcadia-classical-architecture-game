extends RefCounted

## Shared carved capital: two acanthus crowns, corner volutes and a concave abacus.
const Carving := preload("res://src/building/capital_details.gd")
static var template: Array = []
const WIDTHS := [0.035,0.055,0.085,0.125,0.145,0.15,0.135,0.085,0.12,0.16,0.18,0.175,0.15,0.095,0.13,0.15,0.15,0.125,0.075,0.095,0.11,0.095,0.06,0.045,0.04,0.012]

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(outward) < 0: normal = -normal
	ClassicalGeometry._triangle(surface,[a,b,c],[normal,normal,normal])

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	triangle(surface,a,b,c,outward)
	triangle(surface,a,c,d,outward)

static func leaf_point(row: int, column: int, height: float, back: bool = false) -> Vector3:
	return leaf_surface(row/float(WIDTHS.size()-1),-1+column/4.0,height,back)

static func leaf_surface(t: float, u: float, height: float, back: bool = false) -> Vector3:
	var row := t*(WIDTHS.size()-1)
	var index := mini(floori(row),WIDTHS.size()-2)
	var width := lerpf(WIDTHS[index],WIDTHS[index+1],row-index)*0.80
	var radius := 0.415+0.03*t+0.125*t*t*t
	var ridge := sin(PI*t)*0.03*(1-absf(u))
	for branch in [0.14,0.35,0.57,0.77]:
		ridge -= 0.008*exp(-pow((t-branch-absf(u)*0.10)/0.025,2))*sin(PI*absf(u))
	return Vector3(width*u,height*t-0.018*pow(maxf(0,(t-0.85)/0.15),2),radius+ridge-(lerpf(0.045,0.024,t) if back else 0.0))

static func leaf_normal(row: int, column: int, height: float, back: bool) -> Vector3:
	var across := leaf_point(row,mini(8,column+1),height,back)-leaf_point(row,maxi(0,column-1),height,back)
	var upwards := leaf_point(mini(WIDTHS.size()-1,row+1),column,height,back)-leaf_point(maxi(0,row-1),column,height,back)
	return across.cross(upwards).normalized()*(-1 if back else 1)

static func leaf(height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(WIDTHS.size()-1):
		for column in range(8):
			for back in [false,true]:
				var a := leaf_point(row,column,height,back)
				var b := leaf_point(row,column+1,height,back)
				var c := leaf_point(row+1,column+1,height,back)
				var d := leaf_point(row+1,column,height,back)
				var na := leaf_normal(row,column,height,back)
				var nb := leaf_normal(row,column+1,height,back)
				var nc := leaf_normal(row+1,column+1,height,back)
				var nd := leaf_normal(row+1,column,height,back)
				ClassicalGeometry._triangle(surface,[a,b,c],[na,nb,nc])
				ClassicalGeometry._triangle(surface,[a,c,d],[na,nc,nd])
	for row in range(WIDTHS.size()-1):
		for column in [0,8]:
			quad(surface,leaf_point(row,column,height),leaf_point(row+1,column,height),leaf_point(row+1,column,height,true),leaf_point(row,column,height,true),Vector3.LEFT if column == 0 else Vector3.RIGHT)
	for row in [0,WIDTHS.size()-1]:
		for column in range(8):
			quad(surface,leaf_point(row,column,height),leaf_point(row,column+1,height),leaf_point(row,column+1,height,true),leaf_point(row,column,height,true),Vector3.DOWN if row == 0 else Vector3.UP)
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	combined.append_from(surface.commit(),0,Transform3D.IDENTITY)
	var midrib := PackedVector3Array()
	for i in range(15): midrib.append(leaf_surface(lerpf(0.04,0.94,i/14.0),0,height)+Vector3(0,0,0.006))
	combined.append_from(Carving.tube(midrib,0.007,Vector3.RIGHT),0,Transform3D.IDENTITY)
	for branch in [0.12,0.33,0.55,0.75]:
		for side in [-1,1]:
			var vein := PackedVector3Array()
			for i in range(6):
				var t: float = branch+0.11*i/5.0
				vein.append(leaf_surface(t,side*(0.10+0.72*i/5.0),height)+Vector3(0,0,0.004))
			combined.append_from(Carving.tube(vein,0.005,Vector3.RIGHT),0,Transform3D.IDENTITY)
	return combined.commit()

static func abacus_outline(scale_value: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(-0.75,-0.70),Vector2(-0.38,-0.575),Vector2(0,-0.55),Vector2(0.38,-0.575),Vector2(0.75,-0.70),Vector2(0.625,-0.35),Vector2(0.60,0),Vector2(0.625,0.35),Vector2(0.75,0.70),Vector2(0.38,0.575),Vector2(0,0.55),Vector2(-0.38,0.575),Vector2(-0.75,0.70),Vector2(-0.625,0.35),Vector2(-0.60,0),Vector2(-0.625,-0.35)])
	for i in range(points.size()): points[i] *= scale_value
	return points

static func build() -> Array:
	var parts: Array = []
	ClassicalGeometry.lathe(parts,[Vector2(0.4,0),Vector2(0.445,0.015),Vector2(0.455,0.035),Vector2(0.43,0.06),Vector2(0.425,0.10),Vector2(0.445,0.30),Vector2(0.48,0.50),Vector2(0.535,0.64),Vector2(0.57,0.69)],Vector3.ZERO,false,64)
	ClassicalGeometry.cylinder(parts,0.44,0.60,0.6,Vector3(0,0.3,0),true)
	parts.back().erase("mesh")
	for tier in range(2):
		var mesh := leaf(0.40 if tier == 0 else 0.45)
		for j in range(8):
			var angle := TAU*j/8+tier*PI/8
			parts.append({"mesh":mesh,"transform":Transform3D(Basis(Vector3.UP,angle),Vector3(0,0.035 if tier == 0 else 0.17,0)),"detail":"acanthus"})
	# Four diagonal cauliculi rise from the upper leaf crown into true spiral volutes.
	var path := PackedVector3Array()
	for i in range(13):
		var t := i/12.0
		path.append(Vector3(0,lerpf(0.29,0.49,t),lerpf(0.43,0.79,t)))
	for i in range(1,49):
		var t := i/48.0
		var angle := -PI/2+TAU*1.35*t
		var radius := lerpf(0.13,0.014,t)
		path.append(Vector3(0,0.62+radius*sin(angle),0.79+radius*cos(angle)))
	var scroll := Carving.tube(path,0.030,Vector3.RIGHT)
	for j in range(4):
		var corner := Transform3D(Basis(Vector3.UP,PI/4+j*PI/2),Vector3.ZERO)
		var web: Array = []
		ClassicalGeometry.cylinder(web,0.092,0.092,0.012,Vector3(0,0.62,0.79),false)
		web.back().transform.basis = Basis(Vector3.BACK,PI/2)
		ClassicalGeometry.polygon(web,PackedVector2Array([Vector2(0.45,0.28),Vector2(0.50,0.45),Vector2(0.73,0.54),Vector2(0.79,0.49),Vector2(0.66,0.44),Vector2(0.54,0.31)]),0.045,Vector3.ZERO,false,false)
		web.back().transform.basis = Basis(Vector3.UP,-PI/2)
		for part in web:
			part.transform = corner*part.transform
			part.detail = "volute_web"
			parts.append(part)
		parts.append({"mesh":scroll,"transform":Transform3D(Basis(Vector3.UP,PI/4+j*PI/2),Vector3.ZERO),"detail":"corner_volute"})
	# Paired inward helices and a small flower on each face of the capital.
	for face in range(4):
		var transform_value := Transform3D(Basis(Vector3.UP,face*PI/2),Vector3.ZERO)
		for side in [-1,1]:
			var helix := PackedVector3Array()
			for i in range(33):
				var t := i/32.0
				var angle := -PI/2+TAU*1.1*t
				var radius := lerpf(0.085,0.012,t)
				helix.append(Vector3(side*(0.17+radius*cos(angle)),0.605+radius*sin(angle),0.525))
			parts.append({"mesh":Carving.tube(helix,0.014,Vector3.BACK),"transform":transform_value,"detail":"helix"})
		var flower := PackedVector2Array()
		for i in range(40):
			var angle := TAU*i/40
			var radius := 0.042+0.015*cos(angle*5)
			flower.append(Vector2(radius*cos(angle),0.735+radius*sin(angle)))
		var ornament: Array = []
		var face_offset := 0.05 if face%2 == 1 else 0.0
		ClassicalGeometry.polygon(ornament,flower,0.05,Vector3(0,0,0.57+face_offset),false,false)
		ClassicalGeometry.cylinder(ornament,0.016,0.016,0.025,Vector3(0,0.735,0.607+face_offset),false)
		ornament.back().transform.basis = Basis(Vector3.RIGHT,PI/2)
		for part in ornament:
			part.transform = transform_value*part.transform
			part.detail = "abacus_flower"
			parts.append(part)
	for layer in [Vector3(0.69,0.705,0.96),Vector3(0.705,0.755,0.98),Vector3(0.755,0.78,0.965),Vector3(0.78,0.8,1.0)]:
		var part := ClassicalGeometry._prism(abacus_outline(layer.z),layer.x,layer.y)
		part.erase("shape")
		part.detail = "abacus"
		parts.append(part)
	# Preserve the original support/collision contract and exact 0.8 m crown.
	ClassicalGeometry.box(parts,Vector3(1.5,0.16,1.4),Vector3(0,0.72,0))
	parts.back().erase("mesh")
	return Carving.batch_meshes(parts)

static func append_to(parts: Array, y: float) -> void:
	if template.is_empty(): template = build()
	for original in template:
		var part: Dictionary = original.duplicate()
		part.transform = Transform3D(Basis.IDENTITY,Vector3.UP*y)*original.transform
		parts.append(part)
