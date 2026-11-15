extends SceneTree
## Rebuild the editable, baked moon scenes with:
## godot --headless --path . --script res://scripts/tools/build_moon.gd

const ROUTE := [Vector3(-7, 0.14, 29), Vector3(-5, 0.14, 24), Vector3(3, 0.14, 20), Vector3(5, 0.14, 14), Vector3(0, 0.14, 8), Vector3(0, 0.14, 2.65)]
const SITES := [Vector3(-3.5, 0, 10), Vector3(8.4, 0, 16), Vector3(-1.5, 0, 26.4)]
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
	stone = material(Color("484056"))
	dark = material(Color("263342"))
	amber = material(Color("ffc87a"), 1.2)
	crystal = material(Color("66dbd1"), 0.55)
	build_surface()
	build_approach()
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
	var hills := 0.5 + noise.get_noise_2d(x, z) * 2.2
	# A broken escarpment shelters the station from the moon's highlands.
	hills += 4.8 * exp(-pow((x + 13.0) / 4.8, 2)) * exp(-pow((z - 1.0) / 19.0, 2))
	hills += 5.5 * exp(-pow((z + 14.0) / 5.0, 2))
	# Shallow impact basin to the east of the approach.
	var crater := Vector2(x - 14, z - 6).length()
	hills += 1.5 * exp(-pow((crater - 4.3) / 1.1, 2)) - 1.7 * exp(-pow(crater / 3.0, 2))
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
	# Continuous surface: the edge lies beyond the orbit camera's horizon.
	var grid: Array[Vector3] = []
	const COUNT := 101
	const STEP := 1.6
	for z in COUNT:
		for x in COUNT:
			var px := (x - 50) * STEP
			var pz := (z - 44) * STEP
			if x > 0 and x < COUNT - 1 and z > 0 and z < COUNT - 1:
				px += rng.randf_range(-0.43, 0.43)
				pz += rng.randf_range(-0.43, 0.43)
			grid.append(Vector3(px, height_at(px, pz), pz))
	for z in COUNT - 1:
		for x in COUNT - 1:
			var a := grid[z * COUNT + x]
			var b := grid[z * COUNT + x + 1]
			var c := grid[(z + 1) * COUNT + x]
			var d := grid[(z + 1) * COUNT + x + 1]
			var tint := Color("332d43").lerp(Color("69505c"), rng.randf_range(0.05, 0.65))
			triangle(st, a, c, b, tint)
			triangle(st, b, c, d, tint.darkened(rng.randf_range(0.0, 0.08)))
	st.generate_normals()
	var ground_mesh := st.commit()
	ResourceSaver.save(ground_mesh, "res://resources/moon/regolith.res", ResourceSaver.FLAG_CHANGE_PATH)
	ground_mesh = ResourceLoader.load("res://resources/moon/regolith.res", "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE)
	var ground_mat := material(Color.WHITE)
	ground_mat.vertex_color_use_as_albedo = true
	mesh_node(surface, "FacetedRegolith", ground_mesh, Vector3.ZERO, ground_mat)
	var boulder := rock_mesh(false)
	# Deliberate landmark formations frame the base and leave the route clear.
	var landmarks := [Vector3(-10, 0, -4), Vector3(-12, 0, 3), Vector3(-11, 0, 13), Vector3(10.5, 0, -7), Vector3(11, 0, 23), Vector3(-10.5, 0, 28), Vector3(4, 0, -11)]
	for i in landmarks.size():
		var p: Vector3 = landmarks[i]
		p.y = height_at(p.x, p.z) - 0.25
		var rock := mesh_node(surface, "BasaltSpire%02d" % i, boulder, p, stone)
		rock.scale = Vector3(rng.randf_range(1.6, 2.8), rng.randf_range(2.4, 4.4), rng.randf_range(1.3, 2.4))
		rock.rotation.y = rng.randf() * TAU
	for i in 180:
		var p := Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-18, 38))
		if Vector2(p.x, p.z).length() < 7.5 or route_distance(p) < 3.0:
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
	var colonies := [Vector3(-8, 0, 6), Vector3(10, 0, 7), Vector3(10.5, 0, 20), Vector3(-9.5, 0, 21), Vector3(-6, 0, -8)]
	for i in colonies.size():
		for j in 5:
			var p: Vector3 = colonies[i] + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.8, 0.8))
			p.y = height_at(p.x, p.z) - 0.08
			var node := mesh_node(surface, "LumenCrystal%d_%d" % [i, j], shard, p, crystal)
			node.scale = Vector3(0.3, rng.randf_range(0.6, 1.7), 0.3)
			node.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0.15)
	# Shallow foundation slabs anchor the original buildings in the regolith.
	box(surface, "HabitatFoundation", Vector3(0, -0.13, 0), Vector3(5.2, 0.4, 4.8), dark)
	for i in SITES.size():
		var footing := CylinderMesh.new()
		footing.top_radius = 1.5
		footing.bottom_radius = 1.8
		footing.height = 0.24
		footing.radial_segments = 6
		mesh_node(surface, "DefenseExcavation%02d" % i, footing, SITES[i] + Vector3(0, -0.09, 0), stone)
	save_scene(surface, "res://scenes/moon_surface.tscn")

func rock_mesh(pointed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 5 if pointed else 7
	for i in n:
		var a := float(i) * TAU / n
		var b := float(i + 1) * TAU / n
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		var u := Vector3(cos(a) * 0.7 + 0.12, 0.8, sin(a) * 0.7)
		var v := Vector3(cos(b) * 0.7 + 0.12, 0.8, sin(b) * 0.7)
		var tip := Vector3(0.24, 1.8 if pointed else 1.12, 0.06)
		triangle(st, p, u, q, Color.WHITE)
		triangle(st, q, u, v, Color.WHITE)
		triangle(st, u, tip, v, Color.WHITE)
	st.generate_normals()
	return st.commit()

func build_approach() -> void:
	var approach := Node3D.new()
	approach.name = "EnemyApproach"
	approach.set_meta("display_name", "Moonpass — Enemy Approach")
	var path := Path3D.new()
	path.curve = Curve3D.new()
	for point in ROUTE:
		path.curve.add_point(point)
	attach(approach, path, "EnemyPath")
	var route_mat := material(Color("61505b"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
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
	var length := path.curve.get_baked_length()
	for i in range(1, int(length / 2.4)):
		var distance := i * 2.4
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
	label.modulate = Color("ffc87a")
	label.position = ROUTE[0] + Vector3(0, 0.025, 1.3)
	label.rotation.x = -PI / 2
	attach(approach, label, "ApproachMarking")
	save_scene(approach, "res://scenes/enemy_approach.tscn")

func save_scene(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(node)
	var error := ResourceSaver.save(scene, path)
	assert(error == OK)
	node.free()
