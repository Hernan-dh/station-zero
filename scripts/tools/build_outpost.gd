extends SceneTree
## Bake editable models for concept_sheet_3. Run with:
## godot --headless --path . --script res://scripts/tools/build_outpost.gd
## Runtime loads the saved scenes; no procedural construction is needed in game.

var armor: Material = preload("res://resources/materials/slate.tres")
var dark: Material = preload("res://resources/materials/ink.tres")
var trim: Material = preload("res://resources/materials/gold.tres")
var pale: Material = preload("res://resources/materials/ivory.tres")
var cyan: Material = preload("res://resources/materials/teal_glow_1.tres")
var amber: Material = preload("res://resources/materials/gold_glow_0_6.tres")
var glass: Material = preload("res://resources/materials/dome_glass.tres")
var deck: Material = preload("res://resources/materials/deck.tres")

func _initialize() -> void:
	build_banner()
	build_wall()
	build_annex()
	build_dish_base()
	build_habitat()
	build_beacon()
	build_perimeter()
	build_site()
	print("Baked concept 3 outpost models")
	quit()

func group(parent: Node3D, title: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = title
	n.position = pos
	if parent != null: parent.add_child(n, true)
	return n

func mesh(parent: Node3D, title: String, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = title
	n.mesh = shape
	n.position = pos
	n.material_override = mat
	parent.add_child(n, true)
	return n

func box(p: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(p, title, shape, pos, mat)

func cylinder(p: Node3D, title: String, pos: Vector3, top: float, bottom: float, height: float, mat: Material, sides := 12) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return mesh(p, title, shape, pos, mat)

func beam(p: Node3D, title: String, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var n := box(p, title, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), mat)
	n.quaternion = Quaternion(Vector3.BACK, (b - a).normalized())
	return n

func ring(p: Node3D, title: String, pos: Vector3, radius: float, width: float, mat: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - width
	shape.outer_radius = radius + width
	shape.rings = 48
	shape.ring_segments = 6
	return mesh(p, title, shape, pos, mat)

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

# Chamfered silhouette in the XY plane, extruded along Z.
func armor_box(p: Node3D, title: String, pos: Vector3, size: Vector3, bevel: float, mat: Material) -> MeshInstance3D:
	var x := size.x * .5
	var y := size.y * .5
	var z := size.z * .5
	var outline := [Vector2(-x + bevel, y), Vector2(x - bevel, y), Vector2(x, y - bevel), Vector2(x, -y + bevel), Vector2(x - bevel, -y), Vector2(-x + bevel, -y), Vector2(-x, -y + bevel), Vector2(-x, y - bevel)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 8:
		var a := Vector3(outline[i].x, outline[i].y, z)
		var b := Vector3(outline[(i + 1) % 8].x, outline[(i + 1) % 8].y, z)
		var c := Vector3(b.x, b.y, -z)
		var d := Vector3(a.x, a.y, -z)
		triangle(st, Vector3(0, 0, z), a, b)
		triangle(st, Vector3(0, 0, -z), c, d)
		triangle(st, a, d, c)
		triangle(st, a, c, b)
	st.generate_normals()
	return mesh(p, title, st.commit(), pos, mat)

func own_children(n: Node, owner_node: Node) -> void:
	for child in n.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			own_children(child, owner_node)

func save_model(n: Node3D, file: String) -> void:
	own_children(n, n)
	var packed := PackedScene.new()
	assert(packed.pack(n) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/models/" + file + ".tscn") == OK)
	n.free()

func instance(p: Node3D, file: String, title: String, pos: Vector3) -> Node3D:
	var n: Node3D = load("res://scenes/models/" + file + ".tscn").instantiate()
	n.name = title
	n.position = pos
	p.add_child(n, true)
	return n

func stairs(p: Node3D, pos: Vector3, width: float, count: int, rise: float, run: float) -> void:
	var g := group(p, "Stairs", pos)
	for i in count:
		var h := (count - i) * rise
		box(g, "Tread%02d" % i, Vector3(0, h * .5, i * run), Vector3(width, h, run + .015), deck)
		box(g, "Nosing%02d" % i, Vector3(0, h, i * run + run * .43), Vector3(width, .035, .065), pale)
	for side in [-1, 1]:
		beam(g, "AmberRail", Vector3(side * (width * .5 + .06), count * rise + .04, -run * .4), Vector3(side * (width * .5 + .06), .12, count * run), .12, trim)

func build_banner() -> void:
	var n := group(null, "Banner")
	cylinder(n, "Foot", Vector3(0, .08, 0), .22, .3, .15, dark, 8)
	cylinder(n, "Mast", Vector3(0, 1.15, 0), .032, .045, 2.2, trim, 8)
	beam(n, "Crossbar", Vector3(-.43, 2.17, 0), Vector3(.43, 2.17, 0), .055, pale)
	var cloth := armor_box(n, "Pennant", Vector3(0, 1.5, .035), Vector3(.72, 1.22, .035), .12, trim)
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A geometric orbital insignia, readable from either side.
	for side in [-1, 1]:
		var crest := ring(n, "OrbitalInsignia", Vector3(0, 1.56, side * .06), .17, .018, pale)
		crest.rotation.x = PI * .5
		beam(n, "SpireInsignia", Vector3(0, 1.25, side * .065), Vector3(0, 1.92, side * .065), .025, pale)
		beam(n, "WingInsignia", Vector3(-.24, 1.73, side * .065), Vector3(.24, 1.39, side * .065), .022, pale)
	save_model(n, "outpost_banner")

func build_wall() -> void:
	var n := group(null, "WallSegment")
	armor_box(n, "Footing", Vector3(0, .25, 0), Vector3(2.6, .5, .75), .12, dark)
	armor_box(n, "Armor", Vector3(0, .75, 0), Vector3(2.5, 1.05, .48), .15, armor)
	box(n, "Crown", Vector3(0, 1.3, 0), Vector3(2.58, .14, .57), pale)
	box(n, "AmberInlay", Vector3(0, 1.27, .295), Vector3(1.75, .12, .035), trim)
	for x in [-.82, 0.0, .82]:
		box(n, "PanelJoint", Vector3(x, .72, .25), Vector3(.035, .9, .025), dark)
	box(n, "LowerRail", Vector3(0, .31, .29), Vector3(2.4, .09, .1), dark)
	save_model(n, "outpost_wall")

func pylon(p: Node3D, pos: Vector3, angle: float) -> void:
	var n := group(p, "Bastion", pos)
	n.rotation.y = angle
	var base := cylinder(n, "SplayedFoot", Vector3(0, .3, 0), .48, .7, .6, dark, 4)
	base.rotation.y = PI * .25
	var shaft := cylinder(n, "Armor", Vector3(0, .85, 0), .32, .51, 1.25, armor, 4)
	shaft.rotation.y = PI * .25
	for x in [-.25, .25]:
		beam(n, "AmberBrace", Vector3(x * 1.7, .15, .4), Vector3(x, 1.45, .24), .15, trim)
	beam(n, "EnergySlot", Vector3(0, .23, .43), Vector3(0, .86, .32), .085, cyan)
	armor_box(n, "Crown", Vector3(0, 1.52, 0), Vector3(.73, .18, .65), .06, pale)
	box(n, "Cap", Vector3(0, 1.63, 0), Vector3(.4, .045, .36), dark)

func build_annex() -> void:
	var n := group(null, "UtilityModule")
	armor_box(n, "Foundation", Vector3(0, .23, 0), Vector3(1.9, .4, 2), .18, dark)
	armor_box(n, "Shell", Vector3(0, .9, 0), Vector3(1.65, 1.25, 1.7), .23, armor)
	armor_box(n, "Roof", Vector3(0, 1.56, 0), Vector3(1.75, .22, 1.8), .09, pale)
	armor_box(n, "AccessRecess", Vector3(0, .85, .87), Vector3(.85, .95, .12), .13, dark)
	for y in [.65, .85, 1.05]:
		box(n, "StatusVent", Vector3(0, y, .945), Vector3(.53, .075, .03), cyan)
	for x in [-.65, .65]:
		box(n, "AmberCorner", Vector3(x, 1.0, .89), Vector3(.15, .7, .12), trim)
	for x in [-.42, .0, .42]:
		box(n, "RoofVent", Vector3(x, 1.68, -.1), Vector3(.17, .06, .65), dark)
	cylinder(n, "Aerial", Vector3(.55, 1.95, -.55), .025, .045, .65, pale, 6)
	save_model(n, "outpost_annex")

func build_dish_base() -> void:
	var n := group(null, "DishFoundation")
	cylinder(n, "Footing", Vector3(0, .12, 0), .9, 1.1, .23, dark, 8)
	cylinder(n, "TowerArmor", Vector3(0, .63, 0), .47, .7, .9, armor, 8)
	for side in [-1, 1]:
		beam(n, "Buttress", Vector3(side * .83, .18, .25), Vector3(side * .46, .92, .12), .22, trim)
	armor_box(n, "AccessPanel", Vector3(0, .57, .58), Vector3(.47, .59, .07), .08, dark)
	for y in [.39, .56, .73]:
		box(n, "Vent", Vector3(0, y, .63), Vector3(.28, .055, .035), cyan)
	save_model(n, "outpost_dish_base")

func dome_point(a: float, t: float) -> Vector3:
	return Vector3(sin(a) * 2.48 * cos(t), 2.35 + sin(t) * 1.72, -.65 + cos(a) * 2.48 * cos(t))

func build_habitat() -> void:
	var n := group(null, "Habitat")
	n.set_meta("display_name", "Habitat Core")
	cylinder(n, "Foundation", Vector3(0, .32, -.65), 2.9, 3.18, .5, dark)
	cylinder(n, "LowerArmor", Vector3(0, .71, -.65), 2.74, 2.9, .32, armor)
	cylinder(n, "PressureHull", Vector3(0, 1.46, -.65), 2.61, 2.7, 1.45, armor)
	cylinder(n, "RoofCollar", Vector3(0, 2.23, -.65), 2.72, 2.72, .19, dark)
	ring(n, "AmberEave", Vector3(0, 2.34, -.65), 2.59, .055, trim)
	# Twelve individually glazed sectors and structural ribs.
	for sector in 12:
		var a := sector * TAU / 12.0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in 6:
			for col in 4:
				var a0 := a + col * TAU / 48.0
				var a1 := a + (col + 1) * TAU / 48.0
				var t0 := row * PI / 12.0
				var t1 := (row + 1) * PI / 12.0
				triangle(st, dome_point(a0, t0), dome_point(a0, t1), dome_point(a1, t0))
				triangle(st, dome_point(a1, t0), dome_point(a0, t1), dome_point(a1, t1))
		st.generate_normals()
		mesh(n, "Glazing%02d" % sector, st.commit(), Vector3.ZERO, glass)
		for row in 6:
			beam(n, "DomeRib", dome_point(a, row * PI / 12.0) + Vector3(0, .035, 0), dome_point(a, (row + 1) * PI / 12.0) + Vector3(0, .035, 0), .085 if sector % 3 else .13, pale if sector % 3 else trim)
		var g := group(n, "HullPanel%02d" % sector, Vector3(sin(a) * 2.6, 0, -.65 + cos(a) * 2.6))
		g.rotation.y = a
		armor_box(g, "Buttress", Vector3(0, 1.15, .04), Vector3(.35, 1.55, .3), .09, dark)
		box(g, "CrownPlate", Vector3(0, 2.12, .1), Vector3(.58, .22, .35), trim)
		box(g, "RunningLight", Vector3(.48, 1.75, .06), Vector3(.43, .13, .09), cyan)
	for t in [.22, .6, 1.02]:
		ring(n, "GlazingMullion", Vector3(0, 2.35 + sin(t) * 1.72, -.65), cos(t) * 2.48, .028, dark)
	ring(n, "CyanHorizon", Vector3(0, 2.35 + sin(.22) * 1.72, -.65), cos(.22) * 2.49, .014, cyan)
	cylinder(n, "Crown", Vector3(0, 4.08, -.65), .38, .65, .17, trim)
	cylinder(n, "CrownHub", Vector3(0, 4.3, -.65), .22, .35, .3, armor, 8)
	cylinder(n, "Aerial", Vector3(0, 4.85, -.65), .025, .055, .85, pale, 6)
	armor_box(n, "AirlockOuter", Vector3(0, 1.52, 2.0), Vector3(2.05, 2.35, .86), .38, dark)
	armor_box(n, "AirlockArmor", Vector3(0, 1.58, 2.37), Vector3(1.82, 2.15, .36), .32, trim)
	armor_box(n, "AirlockInset", Vector3(0, 1.43, 2.58), Vector3(1.35, 1.72, .09), .22, armor)
	armor_box(n, "Door", Vector3(0, 1.35, 2.64), Vector3(.95, 1.4, .06), .16, dark)
	for x in [-.24, .24]:
		armor_box(n, "DoorLeaf", Vector3(x, 1.3, 2.69), Vector3(.42, 1.14, .04), .1, trim)
		box(n, "DoorLight", Vector3(x * .45, 1.34, 2.72), Vector3(.045, .64, .025), amber)
	box(n, "LintelLight", Vector3(0, 2.03, 2.65), Vector3(.82, .095, .05), cyan)
	stairs(n, Vector3(0, .17, 2.86), 1.85, 5, .105, .28)
	for side in [-1, 1]:
		instance(n, "outpost_banner", "EntryStandard", Vector3(side * 1.48, .22, 2.45))
		var annex := instance(n, "outpost_annex", "ServiceWing", Vector3(side * 3.13, .15, -.2))
		annex.rotation.y = side * -.12
		box(n, "TransferConduit", Vector3(side * 2.55, .9, -.3), Vector3(1.25, .75, .85), dark)
	save_model(n, "habitat")

func build_beacon() -> void:
	var n := group(null, "Model")
	cylinder(n, "Footing", Vector3(0, .25, 0), 1.05, 1.35, .5, dark, 8)
	cylinder(n, "Pedestal", Vector3(0, .65, 0), .7, 1.0, .5, armor, 8)
	cylinder(n, "Collar", Vector3(0, .93, 0), .72, .72, .12, trim, 8)
	cylinder(n, "Spine", Vector3(0, 3.2, 0), .16, .45, 4.5, dark, 8)
	for i in 4:
		var a := i * TAU / 4.0 + PI * .25
		var g := group(n, "SpireFin", Vector3.ZERO)
		g.rotation.y = a
		beam(g, "SplayedBrace", Vector3(0, .4, 1.0), Vector3(0, 1.7, .5), .27, armor)
		beam(g, "AmberEdge", Vector3(0, .5, 1.12), Vector3(0, 1.75, .61), .095, trim)
		beam(g, "UpperFin", Vector3(0, 1.6, .5), Vector3(0, 5.7, .11), .16, trim)
		beam(g, "Inlay", Vector3(0, 1.95, .51), Vector3(0, 3.5, .36), .055, cyan)
	var crystal := group(n, "Crystal", Vector3(0, 3.4, 0))
	cylinder(crystal, "LowerCrystal", Vector3(0, -.48, 0), .27, 0, .9, cyan, 6)
	cylinder(crystal, "UpperCrystal", Vector3(0, .32, 0), 0, .27, .7, cyan, 6)
	var energy := group(n, "Energy")
	ring(energy, "LowerHalo", Vector3(0, 3.6, 0), 1.02, .027, cyan)
	ring(energy, "UpperHalo", Vector3(0, 4.8, 0), .83, .022, cyan)
	cylinder(energy, "Tip", Vector3(0, 6.0, 0), 0, .13, .7, cyan, 6)
	box(energy, "BaseSlot", Vector3(0, .68, .83), Vector3(.16, .38, .08), cyan)
	save_model(n, "beacon")

func build_perimeter() -> void:
	var n := group(null, "Fortifications")
	n.set_meta("display_name", "Outpost Perimeter")
	var floor_node := cylinder(n, "Courtyard", Vector3(0, .08, 0), 7.35, 7.5, .25, dark, 16)
	floor_node.scale.z = .82
	for i in 16:
		var a := (i + .5) * TAU / 16.0
		var b := (i + 1.5) * TAU / 16.0
		var start := Vector3(sin(a) * 7.1, .12, cos(a) * 5.8)
		var end := Vector3(sin(b) * 7.1, .12, cos(b) * 5.8)
		pylon(n, start, a)
		# Leave a clear entrance aligned with the existing enemy approach.
		if i == 15: continue
		var wall := instance(n, "outpost_wall", "Wall%02d" % i, (start + end) * .5)
		wall.rotation.y = atan2(-(end - start).z, (end - start).x)
		wall.scale.x = start.distance_to(end) / 2.6
	box(n, "EntranceApron", Vector3(0, .2, 5.0), Vector3(2.65, .2, 2.2), deck)
	stairs(n, Vector3(0, .05, 6.05), 2.6, 3, .085, .24)
	for side in [-1, 1]:
		beam(n, "WalkwayGuide", Vector3(side * 1.05, .22, 4.35), Vector3(side * 1.05, .22, 5.65), .045, cyan)
		instance(n, "outpost_banner", "GateStandard", Vector3(side * 1.75, .15, 5.15))
	save_model(n, "outpost_perimeter")

func build_site() -> void:
	var n := group(null, "DefensiveBuildSite")
	n.set_meta("display_name", "Defensive Build Site")
	n.set_meta("build_radius", .85)
	cylinder(n, "Foundation", Vector3(0, -.03, 0), 1.2, 1.4, .5, dark, 12)
	cylinder(n, "ArmorCourse", Vector3(0, .12, 0), 1.13, 1.25, .26, armor, 12)
	cylinder(n, "Deck", Vector3(0, .24, 0), 1.07, 1.07, .08, deck, 12)
	ring(n, "SocketLight", Vector3(0, .29, 0), .9, .022, cyan)
	for i in 8:
		var a := i * TAU / 8.0
		var g := group(n, "Mount", Vector3(sin(a) * 1.13, .22, cos(a) * 1.13))
		g.rotation.y = a
		armor_box(g, "Clamp", Vector3.ZERO, Vector3(.33, .27, .4), .06, trim)
		box(g, "Indicator", Vector3(0, .15, .03), Vector3(.16, .025, .13), cyan)
	stairs(n, Vector3(0, -.27, 1.25), .85, 3, .16, .22)
	save_model(n, "defensive_build_site")
