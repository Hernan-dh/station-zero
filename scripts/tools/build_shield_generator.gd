extends "res://scripts/tools/build_outpost.gd"
## Bake the editable A2 model and geodesic shield from concept_sheet_1.png.
## godot --headless --path . --script res://scripts/tools/build_shield_generator.gd

func _initialize() -> void:
	armor = preload("res://resources/materials/ivory.tres")
	dark = preload("res://resources/materials/arc_dark.tres")
	trim = preload("res://resources/materials/arc_orange.tres")
	cyan = preload("res://resources/materials/arc_cyan.tres")
	pale = preload("res://resources/materials/arc_metal.tres")
	build_generator()
	print("Baked Shield Generator and hex field")
	quit()

func build_generator() -> void:
	var root_model := group(null, "ShieldGeneratorModel")
	cylinder(root_model, "Foundation", Vector3(0, .1, 0), 1.62, 1.72, .2, dark, 12)
	cylinder(root_model, "ReactorHousing", Vector3(0, .32, 0), 1.42, 1.58, .32, dark, 12)
	cylinder(root_model, "Deck", Vector3(0, .51, 0), 1.38, 1.46, .12, armor, 12)
	ring(root_model, "OuterConduit", Vector3(0, .54, 0), 1.29, .025, cyan)
	for i in 12:
		var a := i * TAU / 12.0
		var section := group(root_model, "Bastion%02d" % i)
		section.rotation.y = a
		armor_box(section, "Armor", Vector3(0, .31, 1.46), Vector3(.67, .34, .23), .06, armor)
		box(section, "VentRecess", Vector3(0, .28, 1.585), Vector3(.48, .13, .035), dark)
		box(section, "AmberStatus", Vector3(0, .31, 1.61), Vector3(.4, .025, .025), amber)
		for j in [-1, 0, 1]:
			box(section, "VentFin%d" % j, Vector3(j * .12, .26, 1.615), Vector3(.025, .11, .025), pale)
		box(section, "TopStripe", Vector3(0, .49, 1.45), Vector3(.16, .018, .27), trim)
	for i in 6:
		var foot := group(root_model, "Buttress%02d" % i)
		foot.rotation.y = i * TAU / 6.0
		armor_box(foot, "Foot", Vector3(0, .09, 1.65), Vector3(.46, .17, .52), .045, dark)
		var plate := armor_box(foot, "SlopedArmor", Vector3(0, .32, 1.55), Vector3(.37, .45, .26), .055, armor)
		plate.rotation.x = -.32
		box(foot, "OrangePanel", Vector3(0, .31, 1.715), Vector3(.16, .18, .025), trim).rotation.x = -.32
		for side in [-1, 1]:
			cylinder(foot, "Bolt%d" % side, Vector3(side * .13, .49, 1.6), .025, .025, .025, dark, 6)
	cylinder(root_model, "CentralPedestal", Vector3(0, .7, 0), .63, .83, .28, dark, 8)
	cylinder(root_model, "PedestalCrown", Vector3(0, .86, 0), .61, .67, .09, pale, 8)
	cylinder(root_model, "ReactorCore", Vector3(0, 1.25, 0), .2, .24, .8, cyan, 16)
	for i in 9:
		ring(root_model, "CoreWinding%02d" % i, Vector3(0, .9 + i * .085, 0), .245, .027, preload("res://resources/materials/arc_white.tres"))
	cylinder(root_model, "EmitterCap", Vector3(0, 1.72, 0), .27, .36, .15, dark, 8)
	blade(root_model, "CentralSpire", Vector3(0, 1.75, 0), Vector3(.48, .86, .25), armor)
	box(root_model, "SpireAccent", Vector3(0, 2.18, .137), Vector3(.07, .26, .025), trim)
	box(root_model, "SpireTelemetry", Vector3(0, 1.94, .139), Vector3(.045, .09, .025), dark)
	cylinder(root_model, "EmitterNeedle", Vector3(0, 2.72, 0), .0, .035, .4, preload("res://resources/materials/arc_white.tres"), 6)
	for i in 4:
		var fin := group(root_model, "CoreFin%02d" % i)
		fin.rotation.y = i * TAU / 4.0 + PI / 4.0
		cylinder(fin, "ArmoredRoot", Vector3(0, 1.13, .4), .12, .26, .8, armor, 4)
		blade(fin, "Spear", Vector3(0, 1.42, .4), Vector3(.23, .7, .17), armor)
		box(fin, "ShoulderAccent", Vector3(.09, 1.59, .4), Vector3(.06, .18, .19), trim)
		box(fin, "CoreWindow", Vector3(0, 1.25, .55), Vector3(.075, .51, .035), cyan)
		armor_box(fin, "ServicePanel", Vector3(0, .75, .68), Vector3(.28, .23, .13), .025, armor)
		box(fin, "PanelIndicator", Vector3(0, .77, .754), Vector3(.11, .045, .02), cyan)
	for i in 4:
		var pylon := group(root_model, "FieldPylon%02d" % i)
		pylon.rotation.y = i * TAU / 4.0
		pylon.position = Vector3(sin(pylon.rotation.y), 0, cos(pylon.rotation.y)) * 1.31
		cylinder(pylon, "Anchor", Vector3(0, .65, 0), .24, .33, .25, dark, 6)
		blade(pylon, "PylonArmor", Vector3(0, .7, 0), Vector3(.36, 1.16, .23), armor)
		box(pylon, "WindowRecess", Vector3(0, 1.08, .12), Vector3(.12, .52, .06), dark)
		box(pylon, "LiveWindow", Vector3(0, 1.1, .16), Vector3(.055, .43, .025), cyan)
		for side in [-1, 1]:
			beam(pylon, "EdgeRail%d" % side, Vector3(side * .16, .79, .13), Vector3(side * .07, 1.43, .13), .035, trim)
		box(pylon, "TipInset", Vector3(0, 1.55, .12), Vector3(.035, .13, .015), dark)
		box(pylon, "Collar", Vector3(0, .82, .17), Vector3(.2, .08, .12), pale)
		beam(pylon, "PowerFeed", Vector3(0, .58, -.18), Vector3(0, .58, -.64), .07, dark)
		beam(pylon, "LiveFeed", Vector3(0, .62, -.18), Vector3(0, .62, -.64), .025, cyan)
	save_model(root_model, "shield_generator")
	assert(ResourceSaver.save(build_field_mesh(), "res://resources/meshes/shield_dome.tres") == OK)

func blade(p: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	# A shallow armored blade with a sharp tip, rather than a conical tower.
	var w := size.x
	var h := size.y
	var z := size.z * .5
	var outline := [Vector2(-w * .5, h * .12), Vector2(-w * .12, h * .82), Vector2(0, h), Vector2(w * .12, h * .82), Vector2(w * .5, h * .12), Vector2(w * .5, 0), Vector2(-w * .5, 0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := Vector3(outline[i].x, outline[i].y, z)
		var b := Vector3(outline[(i + 1) % outline.size()].x, outline[(i + 1) % outline.size()].y, z)
		var c := Vector3(b.x, b.y, -z)
		var d := Vector3(a.x, a.y, -z)
		triangle(st, Vector3(0, h * .4, z), a, b)
		triangle(st, Vector3(0, h * .4, -z), c, d)
		triangle(st, a, d, c)
		triangle(st, a, c, b)
	st.generate_normals()
	return mesh(p, title, st.commit(), pos, mat)

func build_field_mesh() -> ArrayMesh:
	# The dual of a subdivided icosahedron gives seamless hexagons (and twelve
	# pentagons), including at the pole. No UV seam or stretched polar texture.
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vertices: Array[Vector3] = [Vector3(-1,t,0), Vector3(1,t,0), Vector3(-1,-t,0), Vector3(1,-t,0), Vector3(0,-1,t), Vector3(0,1,t), Vector3(0,-1,-t), Vector3(0,1,-t), Vector3(t,0,-1), Vector3(t,0,1), Vector3(-t,0,-1), Vector3(-t,0,1)]
	for i in vertices.size(): vertices[i] = vertices[i].normalized()
	var faces: Array = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	for subdivision in 2:
		var cache := {}
		var next: Array = []
		for face in faces:
			var ab := midpoint(vertices, cache, face[0], face[1])
			var bc := midpoint(vertices, cache, face[1], face[2])
			var ca := midpoint(vertices, cache, face[2], face[0])
			next.append_array([[face[0],ab,ca],[face[1],bc,ab],[face[2],ca,bc],[ab,bc,ca]])
		faces = next
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vertices.size():
		var center := vertices[i]
		var corners: Array[Vector3] = []
		for face in faces:
			if i in face:
				corners.append((vertices[face[0]] + vertices[face[1]] + vertices[face[2]]).normalized())
		var axis := center.cross(Vector3.UP).normalized()
		if axis.length_squared() < .1: axis = Vector3.RIGHT
		var tangent := center.cross(axis)
		corners.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.dot(tangent), a.dot(axis)) < atan2(b.dot(tangent), b.dot(axis)))
		for j in corners.size():
			clip_field_triangle(st, [center, corners[j], corners[(j + 1) % corners.size()]], [0.0, 1.0, 1.0])
	return st.commit()

func midpoint(vertices: Array[Vector3], cache: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a,b), maxi(a,b))
	if not cache.has(key):
		cache[key] = vertices.size()
		vertices.append((vertices[a] + vertices[b]).normalized())
	return cache[key]

func clip_field_triangle(st: SurfaceTool, points: Array, weights: Array) -> void:
	var clipped: Array[Vector3] = []
	var colors: Array[float] = []
	for i in 3:
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % 3]
		var ca: float = weights[i]
		var cb: float = weights[(i + 1) % 3]
		if a.y >= 0:
			clipped.append(a)
			colors.append(ca)
		if (a.y >= 0) != (b.y >= 0):
			var fraction := -a.y / (b.y - a.y)
			clipped.append(a.lerp(b, fraction))
			colors.append(lerpf(ca, cb, fraction))
	for i in range(1, clipped.size() - 1):
		var order := [0, i, i + 1]
		if (clipped[i] - clipped[0]).cross(clipped[i + 1] - clipped[0]).dot(clipped[0]) > 0:
			order = [0, i + 1, i]
		for index in order:
			st.set_normal(clipped[index].normalized())
			st.set_color(Color(colors[index], 0, 0, 1))
			st.add_vertex(clipped[index])
