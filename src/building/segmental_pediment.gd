extends RefCounted

## A low circular segment, recessed tympanum and stepped cornice, following
## classical window pediments rather than an ellipse with vertical shoulders.
const BASE := 3.12
const HALF_SPAN := 1.04
const RISE := 0.43
const STEPS := 48

static func arc(offset: float, scale_x: float) -> PackedVector2Array:
	var radius := (HALF_SPAN*HALF_SPAN+RISE*RISE)/(2*RISE)
	var centre := BASE+RISE-radius
	radius += offset
	var half_angle := acos((BASE-centre)/radius)
	var points := PackedVector2Array()
	for i in range(STEPS+1):
		var angle := lerpf(-half_angle,half_angle,i/float(STEPS))
		points.append(Vector2(radius*sin(angle)*scale_x,BASE if i in [0,STEPS] else centre+radius*cos(angle)))
	return points

static func append_to(parts: Array, scale_x: float, face: int) -> void:
	# The field sits behind the moulding so the cornice casts a real shadow.
	ClassicalGeometry.polygon(parts,arc(0,scale_x),0.05,Vector3(0,0,face*0.205),false,false)
	# Radial offset and front projection: fillet, bead, recessed groove,
	# bed moulding, projecting corona, and the upper crown moulding.
	var layers := [Vector3(0,0.025,0.265),Vector3(0.025,0.045,0.290),Vector3(0.045,0.060,0.270),Vector3(0.060,0.080,0.295),Vector3(0.080,0.100,0.315),Vector3(0.100,0.135,0.355),Vector3(0.135,0.150,0.330),Vector3(0.150,0.165,0.335),Vector3(0.165,0.180,0.345)]
	for layer in layers:
		var outline := arc(layer.y,scale_x)
		var inner := arc(layer.x,scale_x)
		inner.reverse()
		outline.append_array(inner)
		var back := 0.195
		ClassicalGeometry.polygon(parts,outline,layer.z-back,Vector3(0,0,face*(layer.z+back)/2),false,false)
	# Horizontal cornice and end supports meet the curved cornice on a
	# common spring line; the mouldings return onto a proper ledge.
	for layer in [Vector4(2.16,0.025,3.0125,0.270),Vector4(2.30,0.030,3.040,0.300),Vector4(2.52,0.040,3.075,0.355),Vector4(2.56,0.025,3.1075,0.345)]:
		var depth: float = layer.w-0.195
		ClassicalGeometry.box(parts,Vector3(layer.x*scale_x,layer.y,depth),Vector3(0,layer.z,face*(layer.w-depth/2)),false)
	for side in [-1,1]:
		ClassicalGeometry.box(parts,Vector3(0.14*scale_x,0.10,0.15),Vector3(side*1.04*scale_x,2.97,face*0.215),false)
