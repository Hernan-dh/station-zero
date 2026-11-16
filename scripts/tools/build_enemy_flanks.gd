extends "res://scripts/tools/build_moon.gd"
## Bake four equal-length approaches and the expanded terrain shelf:
## godot --headless --path . --script res://scripts/tools/build_enemy_flanks.gd
## Original moon/front scenes remain the source, so rebuilding is repeatable.

const FLANKS := [
	{"name": "Rear", "points": [Vector3(0, .14, -16), Vector3(0, .14, -11), Vector3(0, .14, -7.75)],
	"sites": [Vector3(-4, 0, -14), Vector3(4, 0, -12), Vector3(-4.5, 0, -8)]},
	{"name": "Left", "points": [Vector3(-21, .14, 12), Vector3(-17, .14, 10), Vector3(-16, .14, 5), Vector3(-13, .14, 1), Vector3(-8.5, .14, -.65)],
	"sites": [Vector3(-19, 0, 16), Vector3(-20, 0, 5), Vector3(-12, 0, 8.5)]},
	{"name": "Right", "points": [Vector3(21, .14, 17), Vector3(20, .14, 12), Vector3(19, .14, 6), Vector3(15, .14, 1), Vector3(11, .14, -.65), Vector3(8.5, .14, -.65)],
	"sites": [Vector3(16, 0, 14), Vector3(21, 0, 1), Vector3(12, 0, 5)]},
]
const EQUIPMENT_CLEARINGS := [Vector3(-8, 0, -4.7), Vector3(9, 0, -4)]
const TRAVEL_LENGTH := 42.0
var layouts: Array = FLANKS.duplicate(true)
var front_route: PackedVector3Array
var flank_routes: Array[PackedVector3Array] = []
var flank_sites: Array[Vector3] = []

func _initialize() -> void:
	rng.seed = 60128
	dark = material(Color("242939"))
	amber = material(Color("ff792b"), .25)
	stone = material(Color("383b40"))
	noise.seed = 1907
	noise.frequency = .095
	# Keep the front's original waypoints, easing its two tight inside corners.
	var front_curve := Curve3D.new()
	front_curve.bake_interval = .3
	for i in WAYPOINTS.size():
		var tangent: Vector3 = (WAYPOINTS[mini(i + 1, WAYPOINTS.size() - 1)] - WAYPOINTS[maxi(i - 1, 0)]).normalized()
		var handle := 1.8 if i > 0 and i < WAYPOINTS.size() - 1 else 0.0
		front_curve.add_point(WAYPOINTS[i], -tangent * handle, tangent * handle)
	front_route = front_curve.get_baked_points()
	front_route = extend_to_length(front_route, "Front", Vector3(-.23, 0, .97))
	ROUTE = front_route
	var front := create_approach()
	orient_ingress(front, front_route)
	front.set_meta("travel_length", TRAVEL_LENGTH)
	save_scene(front, "res://scenes/enemy_approach_extended.tscn")
	for flank in layouts:
		var outward: Vector3 = {"Rear": Vector3(0, 0, -1), "Left": Vector3(-.94, 0, .34), "Right": Vector3(.8, 0, .6)}[flank.name]
		var route := extend_to_length(bake_route(flank.points), flank.name, outward)
		flank_routes.append(route)
		var curve := movement_curve(route, flank.name)
		# Spread the existing sockets along the extended approach, keeping the inner one.
		for i in 2:
			var distance: float = curve.get_baked_length() * [.22, .52][i]
			var point := curve.sample_baked(distance)
			var tangent := (curve.sample_baked(distance + .1) - point).normalized()
			var side := Vector3(-tangent.z, 0, tangent.x)
			point += side * (4.3 if i == 0 else -4.3)
			point.y = 0
			flank.sites[i] = point
		for site in flank.sites:
			flank_sites.append(site)
	build_flanks()
	grade_terrain()
	quit()

func bake_route(points: Array) -> PackedVector3Array:
	var curve := Curve3D.new()
	curve.bake_interval = .3
	for i in points.size():
		var tangent: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var handle := .6
		if i == points.size() - 1:
			# Meet the cardinal gate ramp squarely, with room for the inner edge.
			tangent = Vector3(signf(tangent.x), 0, 0) if absf(tangent.x) > absf(tangent.z) else Vector3(0, 0, signf(tangent.z))
			handle = 1.2
		if i > 0 and i < points.size() - 1:
			# Broad bends keep the full-width ribbon from folding at the inside edge.
			handle = minf(2.4, minf(points[i].distance_to(points[i - 1]), points[i].distance_to(points[i + 1])) * .48)
		curve.add_point(points[i], -tangent * handle, tangent * handle)
	return curve.get_baked_points()

## The measured movement curve (including ramp/stairs), not visual ribbon length,
## determines equal arrival times for enemies moving at the same speed.
func movement_curve(route: PackedVector3Array, title: String) -> Curve3D:
	var curve := Curve3D.new()
	for point in route:
		curve.add_point(point)
	if title == "Front":
		return curve
	var angle: float = {"Left": -PI / 2, "Right": PI / 2, "Rear": PI}[title]
	var basis := Basis(Vector3.UP, angle)
	var core := Vector3(0, 0, -.65)
	var outer := 6.45 if title == "Rear" else 7.85
	for target in [core + basis * Vector3(0, .26, outer), core + basis * Vector3(0, .26, 4.85), core + basis * Vector3(0, .71, 3.51)]:
		var start := curve.get_point_position(curve.point_count - 1)
		var steps := ceili(start.distance_to(target) / .2)
		for step in range(1, steps + 1):
			curve.add_point(start.lerp(target, float(step) / steps))
	return curve

func extension(base: PackedVector3Array, outward: Vector3, reach: float, title: String) -> PackedVector3Array:
	var start := base[0]
	var side := Vector3(-outward.z, 0, outward.x)
	var points: Array[Vector3] = [start + outward * reach]
	if title == "Rear":
		points[0] += side * reach * .1
		points.append(start + outward * reach * .66 + side * reach * .20)
		points.append(start + outward * reach * .30 - side * reach * .08)
	elif title != "Front":
		points.append(start + outward * reach * .5 + side * minf(1.8, reach * .1))
	points.append(start)
	var curve := Curve3D.new()
	curve.bake_interval = .3
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var handle := minf(3.6, reach * .18)
		if i == points.size() - 1:
			tangent = (base[1] - base[0]).normalized()
			# Match the tangent of the preserved inner road at the join.
			handle = minf(2.2, reach * .18)
		curve.add_point(points[i], -tangent * handle, tangent * handle)
	var result := curve.get_baked_points()
	result.resize(result.size() - 1)
	result.append_array(base)
	return result

func extend_to_length(base: PackedVector3Array, title: String, outward: Vector3) -> PackedVector3Array:
	var low := .1
	var high := TRAVEL_LENGTH
	var result: PackedVector3Array
	for iteration in 26:
		var reach := (low + high) * .5
		result = extension(base, outward.normalized(), reach, title)
		if movement_curve(result, title).get_baked_length() < TRAVEL_LENGTH:
			low = reach
		else:
			high = reach
	assert(absf(movement_curve(result, title).get_baked_length() - TRAVEL_LENGTH) < .01)
	print(title, " route: ", movement_curve(result, title).get_baked_length(), " units; spawn ", result[0])
	return result

func orient_ingress(approach: Node3D, route: PackedVector3Array) -> void:
	var direction := (route[1] - route[0]).normalized()
	var side := Vector3(-direction.z, 0, direction.x)
	var yaw := atan2(-direction.x, -direction.z)
	for sign_value in [-1, 1]:
		for prefix in ["IngressPylon", "IngressLight"]:
			var node := approach.get_node(prefix + str(sign_value)) as Node3D
			node.position.x = route[0].x + side.x * sign_value * 2.15
			node.position.z = route[0].z + side.z * sign_value * 2.15
			node.rotation.y = yaw
	var label := approach.get_node("ApproachMarking") as Label3D
	label.position = route[0] - direction * 1.3 + Vector3(0, .025, 0)
	label.rotation.y = yaw

func build_flanks() -> void:
	var root_node := Node3D.new()
	root_node.name = "EnemyFlanks"
	var front := load("res://scenes/enemy_approach.tscn").instantiate() as Node3D
	for i in layouts.size():
		var flank: Dictionary = layouts[i]
		ROUTE = flank_routes[i]
		var approach := create_approach()
		attach(root_node, approach, flank.name + "Approach")
		# Use the front's actual materials, including any authored palette changes.
		for mesh in approach.find_children("*", "MeshInstance3D", true, false):
			var original := front.get_node_or_null(NodePath(mesh.name)) as MeshInstance3D
			if original != null:
				mesh.material_override = original.material_override
		approach.set_meta("display_name", flank.name + " — Enemy Approach")
		approach.add_to_group("enemy_approaches", true)
		var path := approach.get_node("EnemyPath") as Path3D
		path.curve = movement_curve(ROUTE, flank.name)
		approach.get_node("HabitatApproach").position = path.curve.get_point_position(path.curve.point_count - 1)
		approach.set_meta("entrance", NodePath("../../Habitat/" + flank.name + "Entrance/Arrival"))
		approach.set_meta("travel_length", TRAVEL_LENGTH)
		orient_ingress(approach, ROUTE)
		# Keep INBOUND at the original size; direction names live in selection metadata.
		var sites := Node3D.new()
		attach(approach, sites, "DefenseSites")
		for j in flank.sites.size():
			var site := load("res://scenes/models/defensive_build_site.tscn").instantiate() as Node3D
			attach(sites, site, "DefenseSite%02d" % (j + 1))
			site.position = flank.sites[j] + Vector3(0, .4, 0)
			site.scale = Vector3(1.35, 1, 1.35)
			site.add_to_group("defensive_build_sites", true)
			site.set_meta("display_name", "%s Defense Site %02d — Vacant" % [flank.name, j + 1])
			site.set_meta("occupied", false)
			site.set_meta("approach", flank.name.to_lower())
			var number := Label3D.new()
			number.text = "%s%02d" % [{"Rear": "B", "Left": "L", "Right": "R"}[flank.name], j + 1]
			number.position = Vector3(0, .31, -.48)
			number.rotation.x = -PI / 2
			number.font_size = 42
			number.pixel_size = .008
			number.outline_size = 0
			attach(site, number, "SiteNumber")
			var mount := Marker3D.new()
			mount.position = Vector3(0, .26, 0)
			attach(site, mount, "DefenseMount")
			terrace(root_node, "%sSiteBedrock%02d" % [flank.name, j + 1], flank.sites[j] + Vector3(0, -.3, 0), Vector3(2.1, .75, 2.0), 2)
			var footing := CylinderMesh.new()
			footing.top_radius = 1.5
			footing.bottom_radius = 1.8
			footing.height = .24
			footing.radial_segments = 6
			mesh_node(root_node, "%sDefenseExcavation%02d" % [flank.name, j + 1], footing, flank.sites[j] + Vector3(0, .31, 0), stone)
	# Generated descendants belong to the baked scene; retain build-site instancing.
	own_children(root_node, root_node)
	save_scene(root_node, "res://scenes/enemy_flanks.tscn")
	front.free()

func distance_to_route(p: Vector3, route: PackedVector3Array) -> float:
	p.y = 0
	var result := INF
	for i in route.size() - 1:
		var a := route[i]
		var b := route[i + 1]
		a.y = 0
		b.y = 0
		result = minf(result, p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)))
	return result

func own_children(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			own_children(child, scene_root)
		else:
			for added in child.get_children():
				if added.name in ["SiteNumber", "DefenseMount"]:
					added.owner = scene_root

func flank_distance(p: Vector3) -> float:
	p.y = 0
	var result := INF
	for route in flank_routes:
		result = minf(result, distance_to_route(p, route))
	return result

func grading(p: Vector3) -> float:
	p.y = 0
	var influence := 1.0 - smoothstep(2.5, 4.2, minf(flank_distance(p), distance_to_route(p, front_route)))
	for site in flank_sites + EQUIPMENT_CLEARINGS:
		influence = maxf(influence, 1.0 - smoothstep(2.5, 3.6, p.distance_to(site)))
	return influence

func grade_terrain() -> void:
	var surface := load("res://scenes/moon_surface.tscn").instantiate() as Node3D
	var ground := surface.get_node("FacetedRegolith") as MeshInstance3D
	var arrays := ground.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i].y = lerpf(vertices[i].y, .08, grading(vertices[i]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	ResourceSaver.save(expand_ground(arrays), "res://resources/moon/regolith_expanded.res")
	# Inherit the original terrain, overriding only local ground and obstructions.
	var scene_text := '[gd_scene load_steps=5 format=3]\n\n[ext_resource type="PackedScene" path="res://scenes/moon_surface.tscn" id="base"]\n[ext_resource type="ArrayMesh" path="res://resources/moon/regolith_expanded.res" id="ground"]\n\n[ext_resource type="ArrayMesh" path="res://resources/moon/expanded_strata.res" id="strata"]\n[ext_resource type="PackedScene" path="res://scenes/outer_highlands.tscn" id="outer"]\n\n[node name="MoonSurface" instance=ExtResource("base")]\n\n[node name="ExposedShelfStrata" parent="." index="0"]\nmesh = ExtResource("strata")\n\n[node name="FacetedRegolith" parent="." index="1"]\nmesh = ExtResource("ground")\n'
	# Shift complete rock formations as units, leaving the station buildings intact.
	var shifts := {"Escarpment00": Vector3(-7, 0, 29), "Escarpment01": Vector3(1, 0, 14), "Escarpment03": Vector3(5, 0, -1), "Escarpment04": Vector3(9.5, 0, 0), "Escarpment05": Vector3(-7, 0, -2), "MoonArchBlock": Vector3(-5, 0, -6), "Escarpment07": Vector3(0, 0, -6)}
	for child in surface.get_children():
		if not child is Node3D:
			continue
		var shifted := false
		for prefix in shifts:
			if str(child.name).begins_with(prefix):
				var transform: Transform3D = child.transform
				transform.origin += shifts[prefix]
				scene_text += '\n[node name="%s" parent="." index="%d"]\ntransform = %s\n' % [child.name, child.get_index(), var_to_str(transform)]
				shifted = true
				break
		if shifted:
			continue
		if str(child.name).begins_with("Scree") or str(child.name).begins_with("CraterRim") or str(child.name).begins_with("LumenCrystal") or str(child.name).begins_with("CrystalLight"):
			var radius := 0.0
			if child is MeshInstance3D:
				var bounds: AABB = child.transform * child.get_aabb()
				radius = maxf(bounds.size.x, bounds.size.z) * .5
			var blocked := minf(flank_distance(child.position), distance_to_route(child.position, front_route)) < 2.4 + radius
			for site in flank_sites + EQUIPMENT_CLEARINGS:
				blocked = blocked or Vector2(child.position.x - site.x, child.position.z - site.z).length() < 2.5 + radius
			if blocked:
				scene_text += '\n[node name="%s" parent="." index="%d"]\nvisible = false\nmetadata/selection_ignore = true\n' % [child.name, child.get_index()]
	scene_text += '\n[node name="OuterHighlands" parent="." instance=ExtResource("outer")]\n'
	FileAccess.open("res://scenes/moon_surface_expanded.tscn", FileAccess.WRITE).store_string(scene_text)
	surface.free()

## Keep every original terrain triangle; stitch new cells onto its boundary and
## move the exposed cliff strata to a larger, irregular shelf outline.
func expanded_shelf(x: float, z: float) -> bool:
	var angle := atan2(z, x)
	var radius := 1.0 + .035 * sin(angle * 5.0 + .7) + .025 * cos(angle * 3.0)
	return pow(absf(x) / (41.0 * radius), 3.2) + pow(absf(z) / (47.0 * radius), 3.2) < 1.0

func terrain_corner(key: Vector2i, known: Dictionary) -> Vector3:
	if known.has(key):
		return known[key]
	var jitter := RandomNumberGenerator.new()
	jitter.seed = absi(key.x * 73856093 ^ key.y * 19349663)
	var p := Vector3(key.x + jitter.randf_range(-.24, .24), 0, key.y + jitter.randf_range(-.24, .24))
	p.y = lerpf(height_at(p.x, p.z), .08, grading(p))
	known[key] = p
	return p

func expand_ground(arrays: Array) -> ArrayMesh:
	ROUTE = front_route
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var known := {}
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	ground.set_smooth_group(-1)
	for i in vertices.size():
		known[Vector2i(roundi(vertices[i].x), roundi(vertices[i].z))] = vertices[i]
		ground.set_color(colors[i])
		ground.add_vertex(vertices[i])
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	skirt.set_smooth_group(-1)
	for z in range(-50, 50):
		for x in range(-45, 45):
			if not expanded_shelf(x + .5, z + .5):
				continue
			var a := terrain_corner(Vector2i(x, z), known)
			var b := terrain_corner(Vector2i(x + 1, z), known)
			var c := terrain_corner(Vector2i(x, z + 1), known)
			var d := terrain_corner(Vector2i(x + 1, z + 1), known)
			if not inside_shelf(x + .5, z + .5):
				var tint := Color("494457").lerp(Color("655b70"), rng.randf_range(.25, .55))
				triangle(ground, a, c, b, tint)
				triangle(ground, b, c, d, tint.darkened(rng.randf_range(0, .08)))
			if not expanded_shelf(x - .5, z + .5): shelf_wall(skirt, a, c)
			if not expanded_shelf(x + 1.5, z + .5): shelf_wall(skirt, d, b)
			if not expanded_shelf(x + .5, z - .5): shelf_wall(skirt, b, a)
			if not expanded_shelf(x + .5, z + 1.5): shelf_wall(skirt, c, d)
	ground.generate_normals()
	skirt.generate_normals()
	ResourceSaver.save(skirt.commit(), "res://resources/moon/expanded_strata.res")
	build_outer_landscape()
	return ground.commit()

func outer_height(p: Vector3) -> float:
	return lerpf(height_at(p.x, p.z), .08, grading(p))

func clear_of_routes(p: Vector3, radius: float) -> bool:
	if minf(flank_distance(p), distance_to_route(p, front_route)) < radius + 2.5:
		return false
	for site in flank_sites + EQUIPMENT_CLEARINGS + SITES:
		if Vector2(p.x - site.x, p.z - site.z).length() < radius + 2.8:
			return false
	return true

func build_outer_landscape() -> void:
	var landscape := Node3D.new()
	landscape.name = "OuterHighlands"
	for i in 7:
		var p: Vector3 = [Vector3(-30, 0, -3), Vector3(-25, 0, -25), Vector3(15, 0, -33), Vector3(30, 0, -16), Vector3(32, 0, 7), Vector3(-27, 0, 31), Vector3(18, 0, 37)][i]
		if clear_of_routes(p, 5.0):
			p.y = outer_height(p) - .25
			terrace(landscape, "OuterEscarpment%02d" % i, p, Vector3(4.4, 2.0 + (i % 3) * .7, 3.0), 4)
	var rock := slab_mesh(71)
	for i in 420:
		var p := Vector3(rng.randf_range(-38, 38), 0, rng.randf_range(-43, 43))
		if inside_shelf(p.x, p.z) or not expanded_shelf(p.x * 1.07, p.z * 1.07) or not clear_of_routes(p, 1.2):
			continue
		p.y = outer_height(p) - .1
		var node := mesh_node(landscape, "OuterScree%03d" % i, rock, p, stone)
		var size := rng.randf_range(.2, .8)
		node.scale = Vector3(size * 1.5, size, size)
		node.rotation.y = rng.randf() * TAU
	var shard := rock_mesh(true)
	var shard_mat := material(Color("09636e"), .18)
	for i in 6:
		var p: Vector3 = [Vector3(-34, 0, 5), Vector3(-26, 0, -16), Vector3(-8, 0, -35), Vector3(12, 0, -25), Vector3(33, 0, 15), Vector3(25, 0, 31)][i]
		if not clear_of_routes(p, 2): continue
		for j in 7:
			var point := p + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
			point.y = outer_height(point) - .08
			var node := mesh_node(landscape, "OuterCrystal%d_%d" % [i, j], shard, point, shard_mat)
			node.scale = Vector3(.286, rng.randf_range(.6, 1.4), .286)
			node.rotation.y = rng.randf() * TAU
	save_scene(landscape, "res://scenes/outer_highlands.tscn")
