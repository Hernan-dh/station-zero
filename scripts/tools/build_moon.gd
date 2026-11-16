extends SceneTree
## Rebuild the editable, baked moon scenes with:
## godot --headless --path . --script res://scripts/tools/build_moon.gd

const WAYPOINTS := [Vector3(-7, 0.14, 29), Vector3(-5, 0.14, 24), Vector3(3, 0.14, 20), Vector3(5, 0.14, 14), Vector3(0, 0.14, 8), Vector3(0, 0.14, 2.65)]
const SITES := [Vector3(-3.5, 0, 10), Vector3(8.4, 0, 16), Vector3(-1.5, 0, 26.4)]
var ROUTE: PackedVector3Array
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var stone: StandardMaterial3D
var dark: StandardMaterial3D
var amber: StandardMaterial3D
var crystal: StandardMaterial3D

func _initialize() -> void:
	rng.seed = 60128
	noise.seed = 1907
	noise.frequency = 0.095
	stone = material(Color("383b40"))
	dark = material(Color("242939"))
	amber = material(Color("ff792b"), 0.25)
	crystal = material(Color("09636e"), 0.18)
	crystal.vertex_color_use_as_albedo = false
	var curve := Curve3D.new()
	curve.bake_interval = 0.3
	for i in WAYPOINTS.size():
		var tangent: Vector3 = (WAYPOINTS[mini(i + 1, WAYPOINTS.size() - 1)] - WAYPOINTS[maxi(i - 1, 0)]).normalized()
		var handle := 1.5 if i > 0 and i < WAYPOINTS.size() - 1 else 0.0
		curve.add_point(WAYPOINTS[i], -tangent * handle, tangent * handle)
	ROUTE = curve.get_baked_points()
	build_surface()
	build_approach()
	build_station_details()
	quit()

func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func attach(root_node: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	root_node.add_child(node)
	node.owner = root_node

func mesh_node(root_node: Node, node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	attach(root_node, node, node_name)
	return node

func box(root_node: Node, node_name: String, pos: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh_node(root_node, node_name, mesh, pos, mat)

func route_distance(p: Vector3) -> float:
	var result := INF
	for i in range(ROUTE.size() - 1):
		var a: Vector3 = ROUTE[i]
		var b: Vector3 = ROUTE[i + 1]
		a.y = 0
		b.y = 0
		result = minf(result, p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)))
	return result

func height_at(x: float, z: float) -> float:
	var p := Vector3(x, 0, z)
	var clearing := 1.0 - smoothstep(6.4, 10.0, Vector2(x, z).length())
	clearing = maxf(clearing, 1.0 - smoothstep(2.2, 4.2, route_distance(p)))
	for site in SITES:
		clearing = maxf(clearing, 1.0 - smoothstep(1.7, 3.2, p.distance_to(site)))
	var hills := 0.15 + noise.get_noise_2d(x, z) * 0.65
	# A broken escarpment shelters the station from the moon's highlands.
	hills += 1.4 * exp(-pow((x + 13.0) / 4.8, 2)) * exp(-pow((z - 1.0) / 19.0, 2))
	hills += 2.2 * exp(-pow((z + 14.0) / 5.0, 2))
	# Bowl floors and raised ejecta rims are part of the continuous terrain.
	for impact in [Vector3(14, 4.6, 8), Vector3(16, 3.0, 23), Vector3(-16, 3.6, 20)]:
		var d: float = Vector2(x - impact.x, z - impact.z).length() / impact.y
		var bowl := -1.6 * (1.0 - smoothstep(0.3, 0.88, d))
		var rim := 0.85 * exp(-pow((d - 0.98) / 0.16, 2))
		hills += bowl + rim
	return lerpf(hills, 0.08, clearing)

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

func build_surface() -> void:
	var surface := Node3D.new()
	surface.name = "MoonSurface"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# A raised, eroded shelf follows the isometric layout in concept sheet 2.
	var grid: Array[Vector3] = []
	const COUNT := 73
	const STEP := 1.0
	for z in COUNT:
		for x in COUNT:
			var px := (x - 36) * STEP
			var pz := (z - 28) * STEP
			if x > 0 and x < COUNT - 1 and z > 0 and z < COUNT - 1:
				px += rng.randf_range(-0.24, 0.24)
				pz += rng.randf_range(-0.24, 0.24)
			grid.append(Vector3(px, height_at(px, pz), pz))
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	skirt.set_smooth_group(-1)
	for z in COUNT - 1:
		for x in COUNT - 1:
			if not inside_shelf(x - 35.5, z - 27.5):
				continue
			var a := grid[z * COUNT + x]
			var b := grid[z * COUNT + x + 1]
			var c := grid[(z + 1) * COUNT + x]
			var d := grid[(z + 1) * COUNT + x + 1]
			var tint := Color("494457").lerp(Color("655b70"), rng.randf_range(0.25, 0.55))
			triangle(st, a, c, b, tint)
			triangle(st, b, c, d, tint.darkened(rng.randf_range(0.0, 0.08)))
			if not inside_shelf(x - 36.5, z - 27.5):
				shelf_wall(skirt, a, c)
			if not inside_shelf(x - 34.5, z - 27.5):
				shelf_wall(skirt, d, b)
			if not inside_shelf(x - 35.5, z - 28.5):
				shelf_wall(skirt, b, a)
			if not inside_shelf(x - 35.5, z - 26.5):
				shelf_wall(skirt, c, d)
	st.generate_normals()
	skirt.generate_normals()
	var bedrock := material(Color.WHITE)
	bedrock.vertex_color_use_as_albedo = true
	mesh_node(surface, "ExposedShelfStrata", skirt.commit(), Vector3.ZERO, bedrock)
	var ground_mesh := st.commit()
	ResourceSaver.save(ground_mesh, "res://resources/moon/regolith.res", ResourceSaver.FLAG_CHANGE_PATH)
	ground_mesh = ResourceLoader.load("res://resources/moon/regolith.res", "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE)
	var ground_mat := load("res://resources/moon/regolith_material.tres")
	mesh_node(surface, "FacetedRegolith", ground_mesh, Vector3.ZERO, ground_mat)
	var boulder := slab_mesh(17)
	# Sheltering stacks of fractured sediment, with broad tops and exposed strata.
	var landmarks := [Vector3(-11, 4.0, -5), Vector3(-13, 3.5, 9), Vector3(-13, 2.4, 27), Vector3(8, 3.3, -8), Vector3(2, 4.3, -12), Vector3(-5, 5.0, -11), Vector3(12, 2.0, 29), Vector3(18, 2.8, -4)]
	for i in landmarks.size():
		var p: Vector3 = landmarks[i]
		var height := p.y
		p.y = height_at(p.x, p.z) - 0.35
		terrace(surface, "Escarpment%02d" % i, p, Vector3(4.6, height * 0.83, 3.0), 4)
	build_arch(surface, Vector3(-13, height_at(-13, -1), -1))
	for impact in [Vector3(14, 4.6, 8), Vector3(16, 3.0, 23), Vector3(-16, 3.6, 20)]:
		for j in 24:
			var a := j * TAU / 24.0
			var p := Vector3(impact.x + cos(a) * impact.y, 0, impact.z + sin(a) * impact.y)
			p.y = height_at(p.x, p.z) - 0.28
			var slab := mesh_node(surface, "CraterRim%d_%d" % [int(impact.x), j], slab_mesh(j + 80), p, stone)
			slab.scale = Vector3(0.62, rng.randf_range(0.14, 0.35), 0.55)
			slab.rotation.y = -a + PI / 2

	for i in 280:
		var p := Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-18, 38))
		if not inside_shelf(p.x, p.z, 0.85) or Vector2(p.x, p.z).length() < 7.5 or route_distance(p) < 3.0:
			continue
		var blocked := false
		for site in SITES:
			if p.distance_to(site) < 2.3:
				blocked = true
		if blocked:
			continue
		p.y = height_at(p.x, p.z) - 0.1
		var rock := mesh_node(surface, "Scree%03d" % i, boulder, p, stone)
		var s := rng.randf_range(0.18, 0.8)
		rock.scale = Vector3(s * 1.5, s, s)
		rock.rotation.y = rng.randf() * TAU
	var shard := rock_mesh(true)
	var colonies := [Vector3(-8, 0, 6), Vector3(10, 0, 7), Vector3(10.5, 0, 20), Vector3(-9.5, 0, 21), Vector3(-6, 0, -8), Vector3(-15, 0, 2), Vector3(18, 0, 24)]
	for i in colonies.size():
		var glow := OmniLight3D.new()
		glow.position = colonies[i] + Vector3(0, height_at(colonies[i].x, colonies[i].z) + 1.1, 0)
		glow.light_color = Color("10a6b3")
		glow.light_energy = 0.35
		glow.omni_range = 4.2
		attach(surface, glow, "CrystalLight%d" % i)
		for j in 7:
			var p: Vector3 = colonies[i] + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.8, 0.8))
			p.y = height_at(p.x, p.z) - 0.08
			var node := mesh_node(surface, "LumenCrystal%d_%d" % [i, j], shard, p, crystal)
			node.scale = Vector3(0.286, rng.randf_range(0.544, 1.428), 0.286)
			node.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0.15)
	# Shallow foundation slabs anchor the original buildings in the regolith.
	box(surface, "HabitatFoundation", Vector3(0, -0.13, 0), Vector3(5.2, 0.4, 4.8), dark)
	for i in SITES.size():
		var footing := CylinderMesh.new()
		terrace(surface, "SiteBedrock%02d" % i, SITES[i] + Vector3(0, -0.3, 0), Vector3(2.1, 0.75, 2.0), 2)
		footing.top_radius = 1.5
		footing.bottom_radius = 1.8
		footing.height = 0.24
		footing.radial_segments = 6
		mesh_node(surface, "DefenseExcavation%02d" % i, footing, SITES[i] + Vector3(0, 0.31, 0), stone)
	save_scene(surface, "res://scenes/moon_surface.tscn")

func rock_mesh(pointed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := 5 if pointed else 7
	for i in n:
		var a := float(i) * TAU / n
		var b := float(i + 1) * TAU / n
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		var u := Vector3(cos(a) * 0.7 + 0.12, 0.8, sin(a) * 0.7)
		var v := Vector3(cos(b) * 0.7 + 0.12, 0.8, sin(b) * 0.7)
		var tip := Vector3(0.24, 1.8 if pointed else 1.12, 0.06)
		var facet := Color.WHITE.lerp(Color("493089"), float(i % 3) * 0.3)
		triangle(st, p, u, q, facet.darkened(0.18))
		triangle(st, q, u, v, facet)
		triangle(st, u, tip, v, facet.lightened(0.15))
	st.generate_normals()
	return st.commit()

func build_approach() -> void:
	save_scene(create_approach(), "res://scenes/enemy_approach.tscn")

## Shared road geometry keeps additional approaches at the original scale.
func create_approach() -> Node3D:
	var approach := Node3D.new()
	approach.name = "EnemyApproach"
	approach.set_meta("display_name", "Moonpass — Enemy Approach")
	var path := Path3D.new()
	path.curve = Curve3D.new()
	for point in ROUTE:
		path.curve.add_point(point)
	attach(approach, path, "EnemyPath")
	var route_mat := material(Color("383734"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# A continuous mitered ribbon follows the exact movement path.
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in ROUTE.size():
		var before: Vector3 = ROUTE[maxi(0, i - 1)]
		var after: Vector3 = ROUTE[mini(ROUTE.size() - 1, i + 1)]
		var tangent := (after - before).normalized()
		var side := Vector3(-tangent.z, 0, tangent.x) * 1.65
		left.append(ROUTE[i] + side)
		right.append(ROUTE[i] - side)
	for i in ROUTE.size() - 1:
		triangle(st, left[i], left[i + 1], right[i], Color.WHITE)
		triangle(st, right[i], left[i + 1], right[i + 1], Color.WHITE)
	st.generate_normals()
	mesh_node(approach, "CompactedMoonDust", st.commit(), Vector3.ZERO, route_mat)
	for edge in [-1, 1]:
		var rail := SurfaceTool.new()
		rail.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in ROUTE.size() - 1:
			var a: Vector3 = left[i] if edge < 0 else right[i]
			var b: Vector3 = left[i + 1] if edge < 0 else right[i + 1]
			var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * 0.07
			var lift := Vector3(0, 0.025, 0)
			triangle(rail, a - side + lift, a + side + lift, b - side + lift, Color.WHITE)
			triangle(rail, a + side + lift, b + side + lift, b - side + lift, Color.WHITE)
		rail.generate_normals()
		mesh_node(approach, "AmberRouteEdge%d" % edge, rail.commit(), Vector3.ZERO, amber)
	var length := path.curve.get_baked_length()
	for i in range(1, int(length / 3.0)):
		var distance := i * 3.0
		var p := path.curve.sample_baked(distance)
		var direction := (path.curve.sample_baked(minf(distance + 0.1, length)) - p).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		for sign_value in [-1, 1]:
			var position: Vector3 = p + side * sign_value * 1.72
			box(approach, "GuidePost%d_%d" % [i, sign_value], position + Vector3(0, 0.14, 0), Vector3(0.15, 0.4, 0.15), dark)
			box(approach, "AmberGuide%d_%d" % [i, sign_value], position + Vector3(0, 0.36, 0), Vector3(0.19, 0.09, 0.19), amber)
		# Inlaid arrows point toward the station.
		for sign_value in [-1, 1]:
			var mark := box(approach, "Direction%d_%d" % [i, sign_value], p + side * sign_value * 0.16 + Vector3(0, 0.012, 0), Vector3(0.10, 0.012, 0.43), amber)
			mark.rotation.y = atan2(direction.x, direction.z) + sign_value * 0.65
	for i in [-1, 1]:
		var p: Vector3 = ROUTE[0] + Vector3(i * 2.15, 0, 0)
		box(approach, "IngressPylon%d" % i, p + Vector3(0, 0.8, 0), Vector3(0.42, 1.8, 0.45), dark)
		box(approach, "IngressLight%d" % i, p + Vector3(0, 1.76, 0), Vector3(0.46, 0.12, 0.49), amber)
	var spawn := Marker3D.new()
	spawn.position = ROUTE[0]
	attach(approach, spawn, "EnemySpawn")
	var destination := Marker3D.new()
	destination.position = ROUTE[-1]
	attach(approach, destination, "HabitatApproach")
	var label := Label3D.new()
	label.text = "INBOUND"
	label.font_size = 34
	label.pixel_size = 0.008
	label.outline_size = 0
	label.modulate = Color("ff9a4a")
	label.position = ROUTE[0] + Vector3(0, 0.025, 1.3)
	label.rotation.x = -PI / 2
	attach(approach, label, "ApproachMarking")
	return approach

func save_scene(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(node)
	var error := ResourceSaver.save(scene, path)
	assert(error == OK)
	node.free()

## A fractured, flat-topped slab. The shared silhouette makes stacks read as strata.
func slab_mesh(seed_value: int) -> ArrayMesh:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var ring: Array[Vector3] = []
	for i in 8:
		var angle := TAU * i / 8.0 + PI / 8
		var r := local_rng.randf_range(0.87, 1.12)
		ring.append(Vector3(cos(angle) * r, 0, sin(angle) * r))
	for i in 8:
		var p := ring[i]
		var q := ring[(i + 1) % 8]
		var u := p * 0.9 + Vector3(0.07, 1, -0.04)
		var v := q * 0.9 + Vector3(0.07, 1, -0.04)
		triangle(st, p, u, q, Color.WHITE)
		triangle(st, q, u, v, Color.WHITE)
		triangle(st, u, Vector3(0, 1, 0), v, Color.WHITE)
	st.generate_normals()
	return st.commit()

func terrace(parent: Node3D, title: String, base: Vector3, size: Vector3, layers: int) -> void:
	var colors := [Color("33363a"), Color("45484d"), Color("2b2e32"), Color("505359")]
	for level in layers:
		var taper := 1.0 - float(level) / layers * 0.38
		var mesh := slab_mesh(100 + level)
		var mat := material(colors[level % colors.size()])
		var h := size.y / layers
		var slab := mesh_node(parent, title + "Layer%d" % level, mesh, base + Vector3(level * 0.16, level * h, 0), mat)
		slab.scale = Vector3(size.x * taper, h * 0.94, size.z * taper)
		# Individual upright fractures break up the large faces of each stratum.
		for j in 8:
			var a := j * TAU / 8.0
			var p := base + Vector3(cos(a) * size.x * taper * 0.82, level * h - 0.06, sin(a) * size.z * taper * 0.82)
			var chip := mesh_node(parent, title + "Fracture%d_%d" % [level, j], mesh, p, mat)
			chip.scale = Vector3(size.x * 0.23, h * rng.randf_range(0.85, 1.15), size.z * 0.24)
			chip.rotation.y = -a
		if level == 1 and size.y > 1.0:
			var seam := mesh_node(parent, title + "OchreStratum", mesh, base + Vector3(0.13, h - 0.02, 0), material(Color("574030")))
			seam.scale = Vector3(size.x * 0.94, 0.12, size.z * 0.94)

func build_arch(parent: Node3D, base: Vector3) -> void:
	var rock := slab_mesh(299)
	for i in 13:
		var a := float(i) / 12.0 * PI
		var p := base + Vector3(cos(a) * 3.7, sin(a) * 4.7 + 0.1, 0)
		var block := mesh_node(parent, "MoonArchBlock%02d" % i, rock, p, material(Color("45484e") if i % 3 else Color("585b60")))
		block.scale = Vector3(1.05, 1.23, 1.1)
		block.rotation.z = a - PI / 2

func beam(parent: Node3D, title: String, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var node := box(parent, title, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), mat)
	node.look_at_from_position((a + b) * 0.5, b, Vector3.UP)

func build_station_details() -> void:
	var details := Node3D.new()
	details.name = "StationDetails"
	var ivory := load("res://resources/materials/ivory.tres")
	var glass := material(Color("125e9e"), 0.16)
	glass.metallic = 0.3
	glass.roughness = 0.28
	var orange := material(Color("df6026"))
	var dome := SurfaceTool.new()
	dome.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A blue glazed cupola with a central opening for the existing beacon mast.
	var radii := [2.28, 1.95, 1.35, 0.75]
	var heights := [2.43, 2.83, 3.17, 3.22]
	for i in 16:
		var a := TAU * i / 16.0
		var b := TAU * (i + 1) / 16.0
		for j in 3:
			var p := Vector3(cos(a) * radii[j], heights[j], sin(a) * radii[j] - 0.65)
			var q := Vector3(cos(b) * radii[j], heights[j], sin(b) * radii[j] - 0.65)
			var u := Vector3(cos(a) * radii[j + 1], heights[j + 1], sin(a) * radii[j + 1] - 0.65)
			var v := Vector3(cos(b) * radii[j + 1], heights[j + 1], sin(b) * radii[j + 1] - 0.65)
			triangle(dome, p, u, q, Color.WHITE)
			triangle(dome, q, u, v, Color.WHITE)
			if i % 2 == 0:
				beam(details, "CupolaRib%d_%d" % [i, j], p, u, 0.055, ivory)
			if j == 0 or j == 2:
				beam(details, "CupolaBand%d_%d" % [i, j], p, q, 0.065, orange)
	dome.generate_normals()
	mesh_node(details, "BlueGlassCupola", dome.commit(), Vector3.ZERO, glass)
	for side in [-1, 1]:
		var x: float = side * 2.5
		box(details, "GateButtress%d" % side, Vector3(x, 0.55, 1.7), Vector3(0.65, 1.05, 0.85), ivory)
		box(details, "GateAccent%d" % side, Vector3(x, 0.65, 2.14), Vector3(0.25, 0.65, 0.03), orange)
		box(details, "BannerMast%d" % side, Vector3(x, 2.05, 2.2), Vector3(0.055, 3.8, 0.055), dark)
		box(details, "Banner%d" % side, Vector3(x + side * 0.36, 2.7, 2.2), Vector3(0.65, 1.55, 0.035), orange)
		var badge := Label3D.new()
		badge.text = "◇\nⅠ"
		badge.font_size = 64
		badge.pixel_size = 0.006
		badge.outline_size = 0
		badge.position = Vector3(x + side * 0.36, 2.7, 2.23)
		attach(details, badge, "BannerInsignia%d" % side)
		box(details, "EntryLamp%d" % side, Vector3(side * 0.54, 1.15, 1.79), Vector3(0.07, 1.0, 0.08), amber)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.0, 2.3)
	lamp.light_color = Color("ff842f")
	lamp.light_energy = 1.6
	lamp.omni_range = 3.2
	attach(details, lamp, "AirlockWarmLight")
	save_scene(details, "res://scenes/models/station_details.tscn")

func inside_shelf(x: float, z: float, inset := 1.0) -> bool:
	return pow(absf(x) / (23.0 * inset), 4) + pow(absf(z - 10.0) / (28.0 * inset), 4) < 1.0

func shelf_wall(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var levels := [0.0, 0.48, 0.53, 1.0]
	var colors := [Color("393449"), Color("925e4b"), Color("28283c")]
	for i in 3:
		var p := a.lerp(Vector3(a.x * 0.97, -4.5, a.z), levels[i])
		var q := b.lerp(Vector3(b.x * 0.97, -4.5, b.z), levels[i])
		var u := a.lerp(Vector3(a.x * 0.97, -4.5, a.z), levels[i + 1])
		var v := b.lerp(Vector3(b.x * 0.97, -4.5, b.z), levels[i + 1])
		var tint: Color = colors[i].lightened(rng.randf_range(0, 0.08))
		triangle(st, p, u, q, tint)
		triangle(st, q, u, v, tint)
