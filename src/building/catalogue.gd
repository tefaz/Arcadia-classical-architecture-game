class_name BuildCatalogue
extends RefCounted

## Stable IDs are the save format contract. Units are metres; pivots sit on the bottom.
const MATERIALS := ["Warm limestone", "White marble", "Golden sandstone"]
const MATERIAL_COLORS := [Color("cbb797"), Color("eeeae1"), Color("cda778")]
const BUILD_SLOTS := 9
const DEFAULT_SLOT := 8
const TOOL_SLOT := 9
const TOOL_KIND := "__stack_tool"
const HOTBAR := ["foundation", "doric_column", "entablature", "pediment", "wall", "arch", "roof_left_half", "balustrade", "", TOOL_KIND]
const GRID := 0.5
const BAY := 4.0
const STAIR_RISE := 0.8
const STAIR_RISER := 0.2
const STAIR_TREAD := 0.5
const MIN_SPAN := 0.5
const MAX_SPAN := 8.0
const WINDOW_KINDS := ["wall_window_pediment","wall_window_segmental","wall_window_ellipse"]
const DOOR_KINDS := ["wall_door_pediment"]
const WALL_KINDS := ["wall"]+WINDOW_KINDS+DOOR_KINDS
const MITRE_KINDS := WALL_KINDS+["entablature", "cornice", "balustrade"]
const FOUNDATION_KINDS := ["foundation","foundation_long","foundation_large","foundation_raised","foundation_podium","step_support"]
const PEDIMENT_KINDS := ["pediment_left","pediment_right","pediment_crown","pediment_backing","pediment_base"]
const TERRACOTTA_ROOF_KINDS := ["roof_left","roof_right","roof_left_half","roof_right_half"]
const STONE_ROOF_KINDS := ["stone_roof_left","stone_roof_right","stone_roof_left_half","stone_roof_right_half"]
const ROOF_KINDS := TERRACOTTA_ROOF_KINDS+STONE_ROOF_KINDS
const COVER_KINDS := ["flat_roof","dome","dome_large"]
const DOME_KINDS := ["dome","dome_large"]
const RAKE_KINDS := ["pediment_left","pediment_right","pediment_crown"]
const SCULPTURE_KINDS := ["draped_statue","reclining_figure","horse_relief"]
const STATUE_KINDS := SCULPTURE_KINDS+["lion_statue"]
const PIECES := [
	{"id": "foundation", "name": "Foundation", "group": "Foundations", "size": Vector3(4, 0.4, 4), "description": "A 4 × 4 m flush ashlar module, 0.4 m high. Repeat sideways for larger floors or vertically for taller foundations; its stone courses meet without projecting ledges.", "cost": {"stone": 12}},
	{"id": "foundation_long", "name": "Paved walkway", "group": "Foundations", "size": Vector3(8, 0.4, 4), "description": "A long approach paved with large rectangular flags inside a dressed-stone border. Joins four-metre foundation bays.", "cost": {"stone": 24}},
	{"id": "foundation_large", "name": "Courtyard paving", "group": "Foundations", "size": Vector3(8, 0.4, 8), "description": "A broad paved court with a generous perimeter border and a central diamond of cut stone. Four-metre connections support adjoining buildings.", "cost": {"stone": 48}},
	{"id": "foundation_raised", "name": "Raised terrace", "group": "Foundations", "size": Vector3(4, 0.8, 4), "description": "A 4 × 4 m flush masonry block, 0.8 m high: two foundation courses. Tile horizontally or stack vertically to build a continuous terrace.", "cost": {"stone": 24}},
	{"id": "foundation_podium", "name": "Temple podium", "group": "Foundations", "size": Vector3(4, 2, 4), "description": "A 4 × 4 m solid temple base, 2 m high: five foundation courses. Flush faces and recessed stone joints make repeated blocks read as one larger podium.", "cost": {"stone": 60}},
	{"id": "step_support", "name": "Stair support", "group": "Foundations", "size": Vector3(4, 0.4, 2), "description": "A solid plinth matching the temple steps' footprint. Stack supports below raised stairs, or snap one onto their underside.", "cost": {"stone": 6}},
	{"id": "steps", "name": "Temple steps", "group": "Foundations", "size": Vector3(4, 0.8, 2), "description": "Aim at a foundation side to fit a solid stairway from the ground to its exact landing height. Automatically faces the edge, keeps each riser at most 0.2 m, and extends the run for taller platforms. On open ground, places the original four-step flight.", "cost": {"stone": 8}},
	{"id": "doric_column", "name": "Doric column", "group": "Columns", "size": Vector3(1.5, 4.1, 1.5), "description": "A complete Doric column with a moulded foot, fluted shaft, rounded cushion capital, fine neck rings and a chamfered abacus.", "cost": {"stone": 12}},
	{"id": "ionic_column", "name": "Ionic column", "group": "Columns", "size": Vector3(1.6, 4.1, 1.4), "description": "A complete Ionic column with carved spiral volutes, side bolsters, egg-and-dart ornament, a fluted shaft and moulded foot.", "cost": {"stone": 13}},
	{"id": "corinthian_column", "name": "Corinthian column", "group": "Columns", "size": Vector3(1.5, 4.3, 1.5), "description": "A complete Corinthian column with a moulded foot, fluted shaft, and a carved capital with two acanthus crowns, curling volutes, flowers and a concave abacus.", "cost": {"stone": 14}},
	{"id": "entablature", "name": "Entablature", "group": "Structure", "size": Vector3(4, 0.75, 1.3), "description": "An architrave, dentil frieze, and cornice. Starts at four metres, fits closing gaps automatically, and mitres at right-angle corners. Use , and . to adjust length; / restores automatic fitting.", "cost": {"stone": 8}},
	{"id": "pediment", "name": "Pediment", "group": "Structure", "size": Vector3(4, 1.2, 0.7), "description": "A triangular classical gable with raking cornices and a recessed tympanum.", "cost": {"stone": 8}},
	{"id": "pediment_left", "name": "Pediment left slope", "group": "Pediments", "size": Vector3(4, 2.4, 0.7), "description": "Rises 2.4 m over a four-metre bay. Aim at the high end to continue upward with another left slope or a crown. Fill underneath with backing blocks. Automatically fits the outer corners of the entablature run.", "cost": {"stone": 8}},
	{"id": "pediment_right", "name": "Pediment right slope", "group": "Pediments", "size": Vector3(4, 2.4, 0.7), "description": "The descending half of a large gable. Join its high end to a crown, then repeat toward the eave. Reclining figures fit the recessed face; R turns their heads uphill.", "cost": {"stone": 8}},
	{"id": "pediment_crown", "name": "Pediment crown", "group": "Pediments", "size": Vector3(4, 1.2, 0.7), "description": "Joins the rising and falling slopes at the summit and follows the entablature’s outer corner span. One slope on each side makes a 12 m pediment; add paired slopes for 20, 28, or more metres.", "cost": {"stone": 6}},
	{"id": "pediment_backing", "name": "Tympanum backing", "group": "Pediments", "size": Vector3(4, 2.4, 0.7), "description": "A recessed four-metre backing course. Stack beneath the slopes and crown to fill a large pediment. Aim at its front to attach statues or horse reliefs inside the recess.", "cost": {"stone": 6}},
	{"id": "pediment_base", "name": "Pediment base cornice", "group": "Pediments", "size": Vector3(4, 0.18, 0.7), "description": "A repeatable horizontal cornice along the foot of a modular pediment. Lay a continuous run, then add backing blocks and slopes on top.", "cost": {"stone": 3}},
	{"id": "wall", "name": "Ashlar wall", "group": "Structure", "size": Vector3(4, 4.1, 0.4), "description": "Coursed masonry with a moulded foot and coping. Fits closing gaps and mitres at right angles. Use , and . for half-metre lengths; / restores automatic fitting.", "cost": {"stone": 10}},
	{"id": "wall_door_pediment", "name": "Pediment doorway wall", "group": "Structure", "size": Vector3(4, 4.1, 0.72), "description": "A walk-through rectangular doorway framed by moulded stone jambs, a lintel and a triangular pediment on both faces. The standard bay has a 1.8 m wide, 2.7 m high opening with no raised threshold. Fits plain/window wall corners, foundation perimeters and flush ceilings. M changes stone; comma/period adjust the wall span.", "cost": {"stone": 12}},
	{"id": "wall_window_pediment", "name": "Pediment window wall", "group": "Structure", "size": Vector3(4, 4.1, 0.72), "description": "An ashlar wall with an open rectangular window, moulded sill and a triangular classical pediment on both faces. Matches ordinary wall bays and corner mitres. M selects the stone finish; comma/period change the bay length.", "cost": {"stone": 12}},
	{"id": "wall_window_segmental", "name": "Curved pediment window", "group": "Structure", "size": Vector3(4, 4.1, 0.72), "description": "The same rectangular opening, jambs and sill as the pediment window wall, crowned by a classical segmental pediment with a recessed centre and layered cornice instead of a triangle. Decorated on both faces; matches ordinary wall bays and corner mitres. M changes the stone finish.", "cost": {"stone": 12}},
	{"id": "wall_window_ellipse", "name": "Elliptical window wall", "group": "Structure", "size": Vector3(4, 4.1, 0.72), "description": "An ashlar wall with a tall open window topped by a half-ellipse arch and moulded stone surround on both faces. Fits ordinary walls and entablatures; the opening remains clear for views and light. M selects the stone finish.", "cost": {"stone": 12}},
	{"id": "arch", "name": "Round arch", "group": "Structure", "size": Vector3(4, 4.1, 0.7), "description": "A walk-through Roman arch with individual voussoirs and a central keystone.", "cost": {"stone": 10}},
	{"id": "roof_left", "name": "Terracotta Roof Slope", "group": "Roofs", "size": Vector3(4, 2.4, 4), "description": "A hollow terracotta slope rising 2.4 m across a four-metre bay. R rotates it; turn 180 degrees for the opposite side. Fits matching pediments and repeats along its depth.", "cost": {"stone": 2, "clay": 8}},
	{"id": "roof_left_half", "name": "Terracotta Roof Half Slope", "group": "Roofs", "size": Vector3(2, 1.2, 4), "description": "A smaller terracotta slope rising 1.2 m across 2 m. Rotate 180 degrees for the opposite side of a compact roof or pediment crown. Joins the larger slopes.", "cost": {"stone": 1, "clay": 4}},
	{"id": "stone_roof_left", "name": "Stone Roof Slope", "group": "Roofs", "size": Vector3(4, 2.4, 4), "description": "A hollow stone-slab slope rising 2.4 m across 4 m. R rotates it for either side. Uses the selected limestone, marble or sandstone and fits the same pediments as terracotta.", "cost": {"stone": 10}},
	{"id": "stone_roof_left_half", "name": "Stone Roof Half Slope", "group": "Roofs", "size": Vector3(2, 1.2, 4), "description": "A smaller stone slope rising 1.2 m across 2 m for compact roofs and pediment crowns. Rotate 180 degrees for the opposite side. M changes its stone finish.", "cost": {"stone": 5}},
	{"id": "flat_roof", "name": "Flat roof / ceiling", "group": "Roofs", "size": Vector3(4, 0.2, 4), "description": "A thin stone cover with a flat underside. Aim at the upper wall of a closed rectangular room to fit flush with its outer faces. Repeat sideways or use Stack; final panels fit the far walls. On entablatures it starts with an edge anchor. T selects manual edge, corner and centre anchors; R turns the slab. Also fits pediments and roof slopes. M selects the stone finish.", "cost": {"stone": 8}},
	{"id": "dome", "name": "Dome roof", "group": "Roofs", "size": Vector3(4, 2.4, 4), "description": "A hollow stone dome on a short drum and a 4 × 4 m square coping base. Covers a standard room without filling the interior. On a wall or beam, R turns the attached edge and T cycles edge/corner anchors. M selects limestone, marble or sandstone.", "cost": {"stone": 18}},
	{"id": "dome_large", "name": "Grand dome roof", "group": "Roofs", "size": Vector3(8, 4.4, 8), "description": "An 8 × 8 m hollow dome for larger halls, with a square corner-covering base and a round stone drum. Uses the chosen stone finish; R turns the attached edge and T cycles anchors on walls or beams.", "cost": {"stone": 60}},
	{"id": "cornice", "name": "Dentil cornice", "group": "Details", "size": Vector3(4, 0.3, 0.8), "description": "A slender dentil course with automatic corner mitres and gap fitting. Use , and . to adjust its length; / restores automatic fitting.", "cost": {"stone": 4}},
	{"id": "balustrade", "name": "Balustrade", "group": "Details", "size": Vector3(4, 1.15, 0.5), "description": "Turned balusters and a continuous handrail. Fits gaps automatically; corners share a post and mitred rails. Use , and . for length; / restores automatic fitting.", "cost": {"stone": 6}},
	{"id": "pedestal", "name": "Pedestal", "group": "Details", "size": Vector3(1.4, 1.1, 1.4), "description": "A moulded square pedestal for urns, columns, or ornaments.", "cost": {"stone": 4}},
	{"id": "rectangular_pedestal", "name": "Rectangular pedestal", "group": "Details", "size": Vector3(3.2, 1.2, 1.6), "description": "A broad rectangular stone plinth with chamfered foot, dressed block and moulded cap. The lion statue centres on its top; R turns the plinth and M changes its stone finish.", "cost": {"stone": 9}},
	{"id": "urn", "name": "Garden urn", "group": "Details", "size": Vector3(0.9, 1.25, 0.9), "description": "A lathed stone urn with a flared lip and two curved handles.", "cost": {"stone": 3}},
	{"id": "finial", "name": "Palmette finial", "group": "Details", "size": Vector3(0.85, 1.1, 0.4), "description": "A fan-shaped acroterion to crown a pediment or roof ridge.", "cost": {"stone": 3}},
	{"id": "lion_statue", "name": "Lion statue", "group": "Sculpture", "size": Vector3(2.8, 1.6, 1.25), "description": "A fully modelled reclining guardian lion with a carved mane, raised head, broad paws and curled tail on an integral stone slab. Aim at the rectangular pedestal top to centre it. R turns the lion; M selects limestone, marble or sandstone.", "cost": {"stone": 10}},
	{"id": "draped_statue", "name": "Draped statue", "group": "Sculpture", "size": Vector3(1.2, 2.2, 0.46), "description": "A standing stone figure with carved drapery, a shield, and a spear. Attach to the front of tympanum backing, or place on a cornice or pedestal. R turns the figure.", "cost": {"stone": 5}},
	{"id": "reclining_figure", "name": "Reclining figure", "group": "Sculpture", "size": Vector3(2.8, 0.95, 0.46), "description": "A reclining human figure for the low corners of a pediment. Aim at a slope's recessed front; turn with R so the head points toward the summit.", "cost": {"stone": 4}},
	{"id": "horse_relief", "name": "Horse relief", "group": "Sculpture", "size": Vector3(2.8, 1.85, 0.46), "description": "A carved horse in profile, with a flowing mane and raised foreleg. Attach inside tympanum backing; use R to face a pair toward one another.", "cost": {"stone": 5}},
]

# Kept for saved buildings and history; the library offers complete columns and modular roofs.
const LEGACY_PIECES := [
	{"id": "roof_right", "name": "Roof right slope", "group": "Roofs", "size": Vector3(4, 2.4, 4), "description": "The descending half of a large tiled roof, matching the pediment right slope. Join its high edge to a left slope or small right half, then extend downhill or along the building.", "cost": {"stone": 2, "clay": 8}},
	{"id": "roof_right_half", "name": "Roof right half", "group": "Roofs", "size": Vector3(2, 1.2, 4), "description": "The separate falling half of the original terracotta roof. Pairs with a left half over the small pediment or crown, and joins larger right slopes below. Repeat in 4 m depth bays.", "cost": {"stone": 1, "clay": 4}},
	{"id": "stone_roof_right", "name": "Stone roof right slope", "group": "Roofs", "size": Vector3(4, 2.4, 4), "description": "A descending roof of broad stone slabs with recessed joints. Matches the large right pediment slope, repeats in 4 m depth bays, and uses the selected stone finish.", "cost": {"stone": 10}},
	{"id": "stone_roof_right_half", "name": "Stone roof right half", "group": "Roofs", "size": Vector3(2, 1.2, 4), "description": "A small falling stone roof half. Matches compact pediments and crowns, with the same pitch and connections as terracotta. M changes its stone finish.", "cost": {"stone": 5}},

	{"id": "roof", "name": "Terracotta roof", "group": "Structure", "size": Vector3(4, 1.2, 4), "description": "A pitched roof with overlapping tile ribs. Its ridge runs along the Z axis.", "cost": {"stone": 4, "clay": 8}},
	{"id": "base", "name": "Attic base", "group": "Columns", "size": Vector3(1.4, 0.5, 1.4), "description": "A square plinth with rounded torus mouldings. Start a custom column here.", "cost": {"stone": 3}},
	{"id": "shaft", "name": "Fluted shaft", "group": "Columns", "size": Vector3(0.92, 3, 0.92), "description": "A gently tapered shaft with twenty-four carved flutes.", "cost": {"stone": 6}},
	{"id": "doric_capital", "name": "Doric capital", "group": "Columns", "size": Vector3(1.5, 0.6, 1.5), "description": "A restrained echinus and square abacus, in the Doric tradition.", "cost": {"stone": 3}},
	{"id": "ionic_capital", "name": "Ionic capital", "group": "Columns", "size": Vector3(1.6, 0.6, 1.4), "description": "Paired spiral volutes beneath a finely layered abacus.", "cost": {"stone": 4}},
	{"id": "corinthian_capital", "name": "Corinthian capital", "group": "Columns", "size": Vector3(1.5, 0.8, 1.5), "description": "Two crowns of lobed, veined acanthus leaves, corner volutes, paired helices, flowers and a concave moulded abacus.", "cost": {"stone": 5}},
]
const LEGACY_REPLACEMENTS := {"roof_right":"roof_left","roof_right_half":"roof_left_half","stone_roof_right":"stone_roof_left","stone_roof_right_half":"stone_roof_left_half","roof":"roof_left_half","base":"doric_column","shaft":"doric_column","doric_capital":"doric_column","ionic_capital":"ionic_column","corinthian_capital":"corinthian_column"}

static func library_kind(id: String) -> String:
	return LEGACY_REPLACEMENTS.get(id,id)

static func valid_span(kind: String, length: float) -> bool:
	if is_equal_approx(length,snappedf(length,GRID)): return true
	# Flush wall runs fit one or both 22 cm convex/concave corner offsets from ordinary bays.
	if kind in WALL_KINDS:
		for trim in [0.22,0.44,-0.22,-0.44]:
			if is_equal_approx(length+trim,snappedf(length+trim,GRID)): return true
	return false

static func join_profile(id: String) -> String:
	return "wall" if id in WALL_KINDS else id

static func cover_anchor_label(anchor: int) -> String:
	return ["Centre","Front edge","Back edge","Right edge","Left edge","Back-left corner","Front-left corner","Back-right corner","Front-right corner"][posmod(anchor,9)]

static func roof_profile(id: String) -> String:
	return id.trim_prefix("stone_").trim_prefix("roof_")

static func roof_variants(width: float) -> Array:
	return ["roof_left_half","roof_right_half","stone_roof_left_half","stone_roof_right_half"] if width == 2 else ["roof_left","roof_right","stone_roof_left","stone_roof_right"]

# The first socket is already in world space; the second belongs to the candidate.
static func sockets_match(world: Dictionary, local: Dictionary, basis: Basis) -> bool:
	if world.family != local.family: return false
	if world.has("slope") and local.has("slope"):
		return world.slope.dot(basis*local.slope) > 0.95
	return true

static func slot_key(slot: int) -> String:
	if slot == TOOL_SLOT: return "−"
	return str(slot+1)

static func get_piece(id: String) -> Dictionary:
	for piece in PIECES+LEGACY_PIECES:
		if piece.id == id:
			return piece
	return {}

static func socket(pos: Vector3, normal: Vector3, family: String = "stack") -> Dictionary:
	return {"position": pos, "normal": normal, "family": family}

static func piece_size(id: String, length: float = BAY, stair_rise: float = STAIR_RISE) -> Vector3:
	var size: Vector3 = get_piece(id).size
	if id in MITRE_KINDS: size.x = length
	if id == "steps": size = Vector3(4,stair_rise,stair_count(stair_rise)*STAIR_TREAD)
	return size

static func stair_count(rise: float) -> int:
	return maxi(1,ceili(rise/STAIR_RISER-0.00001))

static func sockets(id: String, length: float = BAY, stair_rise: float = STAIR_RISE) -> Array[Dictionary]:
	var definition := get_piece(id)
	if definition.is_empty():
		return []
	var size := piece_size(id,length,stair_rise)
	var result: Array[Dictionary] = [socket(Vector3.ZERO, Vector3.DOWN), socket(Vector3(0, size.y, 0), Vector3.UP)]
	if id == "steps":
		result[1] = socket(Vector3(0,size.y,-size.z/2+STAIR_TREAD/2),Vector3.UP)
	if id in FOUNDATION_KINDS:
		for x in range(int(-size.x/2),int(size.x/2)+1,2):
			for z in range(int(-size.z/2),int(size.z/2)+1,2):
				result.append(socket(Vector3(x, size.y, z), Vector3.UP))
		var xs: Array[float] = [0.0]
		var zs: Array[float] = [0.0]
		if size.x > 4:
			for x in range(int(-size.x/2+2),int(size.x/2),4): xs.append(float(x))
		if size.z > 4:
			for z in range(int(-size.z/2+2),int(size.z/2),4): zs.append(float(z))
		for x in xs:
			for z in zs:
				if not is_zero_approx(x) or not is_zero_approx(z):
					result.append(socket(Vector3(x,size.y,z),Vector3.UP))
		# Bottom-plane edges keep unlike foundation heights aligned at their bases.
		for sign_value in [-1,1]:
			for z in zs:
				result.append(socket(Vector3(sign_value*size.x/2,0,z),Vector3(sign_value,0,0),"floor"))
			for x in xs:
				result.append(socket(Vector3(x,0,sign_value*size.z/2),Vector3(0,0,sign_value),"floor"))
	if id in MITRE_KINDS or id == "arch":
		for sign_value in [-1, 1]:
			result.append(socket(Vector3(sign_value * size.x/2, size.y / 2, 0), Vector3(sign_value, 0, 0), "span"))
	if id in ["entablature", "roof", "pediment"] or id in MITRE_KINDS:
		for x in [-size.x/2, size.x/2]:
			result.append(socket(Vector3(x, 0, 0), Vector3.DOWN))
	if id == "roof":
		for z in [-2.0, 2.0]:
			result.append(socket(Vector3(0, 0, z), Vector3(0, 0, signf(z)), "roof"))
	if id in COVER_KINDS:
		for point in [Vector3(0,0,size.z/2),Vector3(0,0,-size.z/2),Vector3(size.x/2,0,0),Vector3(-size.x/2,0,0)]:
			result.append(socket(point,Vector3.DOWN))
			if id == "flat_roof": result.append(socket(point+Vector3.UP*size.y,Vector3.UP))
		for x in [-size.x/2,size.x/2]:
			for z in [-size.z/2,size.z/2]:
				result.append(socket(Vector3(x,0,z),Vector3.DOWN))
				if id == "flat_roof": result.append(socket(Vector3(x,size.y,z),Vector3.UP))
	if id == "flat_roof":
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			result.append(socket(direction*2+Vector3.UP*size.y/2,direction,"flat_roof_edge"))
	if id in ROOF_KINDS:
		var left := roof_profile(id) in ["left","left_half"]
		var low_x := -size.x/2 if left else size.x/2
		result[0] = socket(Vector3(low_x,0,0),Vector3.DOWN)
		result[1] = socket(Vector3(-low_x,size.y,0),Vector3.UP)
		result.append(socket(Vector3(-size.x/2,0 if left else size.y,0),Vector3.LEFT,"roof_rake"))
		result.append(socket(Vector3(size.x/2,size.y if left else 0,0),Vector3.RIGHT,"roof_rake"))
		for side in [-1,1]:
			var run := socket(Vector3(0,size.y/2,side*2),Vector3(0,0,side),"roof_run")
			run["accepts"] = roof_variants(size.x)
			run["slope"] = Vector3.RIGHT if left else Vector3.LEFT
			result.append(run)
			var gable := socket(Vector3(0,size.y/2,side*2),Vector3(0,0,side),"roof_gable_half" if size.x == 2 else "roof_gable_full")
			gable["accepts"] = ["pediment_left","pediment_right"] if size.x == 4 else ["pediment","pediment_crown"]
			gable["slope"] = Vector3.RIGHT if left else Vector3.LEFT
			result.append(gable)
	if id in RAKE_KINDS or id == "pediment":
		for side in [-1,1]:
			if id in ["pediment_left","pediment_right"]:
				var gable := socket(Vector3(0,size.y/2,0),Vector3(0,0,side),"roof_gable_full")
				gable["accepts"] = roof_variants(4)
				gable["slope"] = Vector3.RIGHT if id == "pediment_left" else Vector3.LEFT
				result.append(gable)
			else:
				for left in [true,false]:
					var gable := socket(Vector3(-1 if left else 1,size.y/2,0),Vector3(0,0,side),"roof_gable_half")
					gable["accepts"] = roof_variants(2)
					gable["slope"] = Vector3.RIGHT if left else Vector3.LEFT
					result.append(gable)
	if id in PEDIMENT_KINDS:
		if id in ["pediment_left","pediment_right","pediment_crown"]:
			var left_y := 2.4 if id == "pediment_right" else 0.0
			var right_y := 2.4 if id == "pediment_left" else 0.0
			result.append(socket(Vector3(-2,left_y,0),Vector3.LEFT,"pediment_rake"))
			result.append(socket(Vector3(2,right_y,0),Vector3.RIGHT,"pediment_rake"))
			if id != "pediment_crown":
				result[1] = socket(Vector3(2 if id == "pediment_left" else -2,2.4,0),Vector3.UP)
		if id in ["pediment_backing","pediment_base"]:
			for side in [-1,1]:
				result.append(socket(Vector3(side*2,0,0),Vector3(side,0,0),"pediment_course"))
		if id == "pediment_backing":
			for x in [-1.0,0.0,1.0]:
				var recess := socket(Vector3(x,0.08,0.09),Vector3.BACK,"sculpture")
				recess["accepts"] = SCULPTURE_KINDS if is_zero_approx(x) else ["draped_statue"]
				result.append(recess)
		if id in ["pediment_left","pediment_right"]:
			var recess := socket(Vector3(0.55 if id == "pediment_left" else -0.55,0.02,0.09),Vector3.BACK,"sculpture")
			recess["accepts"] = ["reclining_figure"]
			result.append(recess)
	if id in SCULPTURE_KINDS:
		# Both orientations let shallow sculptures face either way within the same recess.
		result.append(socket(Vector3.ZERO,Vector3.FORWARD,"sculpture"))
		result.append(socket(Vector3.ZERO,Vector3.BACK,"sculpture"))
	return result
