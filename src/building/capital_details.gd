extends RefCounted

## Closed carving primitives and mesh batching shared by the column orders.
static func tube(path: PackedVector3Array, radius: float, plane_normal: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var normals: Array = []
	for i in range(path.size()):
		var tangent: Vector3 = (path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
		var side_normal := (plane_normal-tangent*plane_normal.dot(tangent)).normalized()
		var across := tangent.cross(side_normal).normalized()
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for j in range(8):
			var normal := side_normal*cos(TAU*j/8)+across*sin(TAU*j/8)
			ring.append(path[i]+normal*radius*lerpf(1.0,0.35,i/float(path.size()-1)))
			ring_normals.append(normal)
		rings.append(ring)
		normals.append(ring_normals)
	for i in range(path.size()-1):
		for j in range(8):
			var k := (j+1)%8
			ClassicalGeometry._triangle(surface,[rings[i][j],rings[i][k],rings[i+1][k]],[normals[i][j],normals[i][k],normals[i+1][k]])
			ClassicalGeometry._triangle(surface,[rings[i][j],rings[i+1][k],rings[i+1][j]],[normals[i][j],normals[i+1][k],normals[i+1][j]])
	for i in [0,path.size()-1]:
		var outward: Vector3 = (path[0]-path[1]).normalized() if i == 0 else (path[-1]-path[-2]).normalized()
		for j in range(8): triangle(surface,path[i],rings[i][j],rings[i][(j+1)%8],outward)
	return surface.commit()

static func batch_meshes(parts: Array) -> Array:
	var groups := {}
	var result: Array = []
	for part in parts:
		if part.has("shape"):
			var collider: Dictionary = part.duplicate()
			collider.erase("mesh")
			result.append(collider)
		if not part.has("mesh"): continue
		var group: String = part.get("detail","body")
		if not groups.has(group):
			groups[group] = SurfaceTool.new()
			groups[group].begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface in range(part.mesh.get_surface_count()):
			groups[group].append_from(part.mesh,surface,part.transform)
	for group in groups:
		result.append({"mesh":groups[group].commit(),"transform":Transform3D.IDENTITY,"detail":group})
	return result

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(outward) < 0: normal = -normal
	ClassicalGeometry._triangle(surface,[a,b,c],[normal,normal,normal])

static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	triangle(surface,a,b,c,outward)
	triangle(surface,a,c,d,outward)

static func plate(layers: Array[Vector3]) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for layer in layers:
		rings.append([Vector3(-layer.x,layer.y,-layer.z),Vector3(layer.x,layer.y,-layer.z),Vector3(layer.x,layer.y,layer.z),Vector3(-layer.x,layer.y,layer.z)])
	for i in range(rings.size()-1):
		for j in range(4):
			var k := (j+1)%4
			var outward: Vector3 = (rings[i][j]+rings[i][k])*Vector3(1,0,1)
			quad(surface,rings[i][j],rings[i][k],rings[i+1][k],rings[i+1][j],outward)
	quad(surface,rings[0][0],rings[0][1],rings[0][2],rings[0][3],Vector3.DOWN)
	quad(surface,rings[-1][0],rings[-1][1],rings[-1][2],rings[-1][3],Vector3.UP)
	return surface.commit()

static func oval_ring(outer: Vector2, inner: Vector2, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		var a := TAU*i/48.0
		var b := TAU*(i+1)/48.0
		var p := Vector3(outer.x*cos(a),outer.y*sin(a),-depth/2)
		var q := Vector3(outer.x*cos(b),outer.y*sin(b),-depth/2)
		var r := Vector3(inner.x*cos(a),inner.y*sin(a),-depth/2)
		var s := Vector3(inner.x*cos(b),inner.y*sin(b),-depth/2)
		var lift := Vector3(0,0,depth)
		quad(surface,p+lift,q+lift,s+lift,r+lift,Vector3.BACK)
		quad(surface,p,q,s,r,Vector3.FORWARD)
		quad(surface,p,q,q+lift,p+lift,Vector3(cos((a+b)/2),sin((a+b)/2),0))
		quad(surface,r,s,s+lift,r+lift,Vector3(-cos((a+b)/2),-sin((a+b)/2),0))
	return surface.commit()
