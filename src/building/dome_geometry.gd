extends RefCounted

## Hollow domes sit on square coping rings, covering the corners of square rooms.
static func recipe(id: String) -> Array:
	var size := BuildCatalogue.piece_size(id)
	var radius := size.x*0.45
	var thickness := 0.14 if size.x == 4 else 0.22
	var inner := radius-thickness
	var spring := size.y-radius
	var coping := 0.18 if size.x == 4 else 0.24
	var drum_bottom := coping-0.04
	var parts: Array = []
	var profile: Array = [Vector2(0,spring+inner)]
	for i in range(23,-1,-1):
		var angle := PI/2*i/24.0
		profile.append(Vector2(inner*cos(angle),spring+inner*sin(angle)))
	profile.append_array([Vector2(inner,drum_bottom),Vector2(radius,drum_bottom),Vector2(radius,spring)])
	for i in range(1,25):
		var angle := PI/2*i/24.0
		profile.append(Vector2(0 if i == 24 else radius*cos(angle),spring+radius*sin(angle)))
	ClassicalGeometry.lathe(parts,profile,Vector3.ZERO,false,64)
	parts.append({"mesh":coping_mesh(size.x/2,inner-0.04,coping),"transform":Transform3D.IDENTITY})
	# Convex shell sectors leave the interior empty and can be queried by the
	# same placement checks as every other component. No full-sphere collider.
	for i in range(16):
		var a := TAU*i/16.0
		var b := TAU*(i+1)/16.0
		var outer_a := square_point(size.x/2,a)
		var outer_b := square_point(size.x/2,b)
		var inner_a := Vector2(cos(a),sin(a))*(inner-0.04)
		var inner_b := Vector2(cos(b),sin(b))*(inner-0.04)
		add_ring_sector(parts,outer_a,outer_b,inner_a,inner_b,0,coping)
		add_ring_sector(parts,Vector2(cos(a),sin(a))*radius,Vector2(cos(b),sin(b))*radius,Vector2(cos(a),sin(a))*inner,Vector2(cos(b),sin(b))*inner,drum_bottom,spring)
		for band in range(6):
			var vertices := PackedVector3Array()
			for r in [inner,radius]:
				for phi in [PI/2*band/6.0,PI/2*(band+1)/6.0]:
					for theta in [a,b]:
						vertices.append(Vector3(r*cos(phi)*cos(theta),spring+r*sin(phi),r*cos(phi)*sin(theta)))
			var shape := ConvexPolygonShape3D.new()
			shape.points = vertices
			parts.append({"shape":shape,"transform":Transform3D.IDENTITY})
	# The sector hulls converge to a degenerate edge at the pole. A small
	# overlapping cap inside the shell closes that physics precision gap.
	var crown := SphereShape3D.new()
	crown.radius = thickness*0.4
	parts.append({"shape":crown,"transform":Transform3D(Basis.IDENTITY,Vector3(0,size.y-thickness*0.5,0))})
	return parts

static func square_point(half: float, angle: float) -> Vector2:
	var direction := Vector2(cos(angle),sin(angle))
	return direction*(half/maxf(absf(direction.x),absf(direction.y)))

static func add_ring_sector(parts: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, low: float, high: float) -> void:
	var shape := ConvexPolygonShape3D.new()
	var vertices := PackedVector3Array()
	for point in [a,b,d,c]:
		vertices.append(Vector3(point.x,low,point.y))
		vertices.append(Vector3(point.x,high,point.y))
	shape.points = vertices
	parts.append({"shape":shape,"transform":Transform3D.IDENTITY})

static func coping_mesh(half: float, inner: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var a := TAU*i/64.0
		var b := TAU*(i+1)/64.0
		var p := square_point(half,a)
		var q := square_point(half,b)
		var r := Vector2(cos(a),sin(a))*inner
		var s := Vector2(cos(b),sin(b))*inner
		var pl := Vector3(p.x,0,p.y)
		var ql := Vector3(q.x,0,q.y)
		var rl := Vector3(r.x,0,r.y)
		var sl := Vector3(s.x,0,s.y)
		var up := Vector3.UP*height
		quad(surface,pl+up,ql+up,sl+up,rl+up,Vector3.UP)
		quad(surface,pl,ql,sl,rl,Vector3.DOWN)
		quad(surface,pl,ql,ql+up,pl+up,Vector3(q.y-p.y,0,p.x-q.x).normalized())
		quad(surface,rl,sl,sl+up,rl+up,Vector3(r.y-s.y,0,s.x-r.x).normalized())
	return surface.commit()

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	ClassicalGeometry._triangle(surface,[a,b,c],[normal,normal,normal])
	ClassicalGeometry._triangle(surface,[a,c,d],[normal,normal,normal])
