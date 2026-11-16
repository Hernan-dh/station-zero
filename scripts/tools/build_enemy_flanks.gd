extends "res://scripts/tools/build_moon.gd"
## Bake the three extra approaches and local terrain grading:
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
var flank_routes: Array[PackedVector3Array] = []
var flank_sites: Array[Vector3] = []

func _initialize() -> void:
	rng.seed = 60128
	dark = material(Color("242939"))
	amber = material(Color("ff792b"), .25)
	stone = material(Color("383b40"))
	for flank in FLANKS:
		flank_routes.append(bake_route(flank.points))
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

func build_flanks() -> void:
	var root_node := Node3D.new()
	root_node.name = "EnemyFlanks"
	var front := load("res://scenes/enemy_approach.tscn").instantiate() as Node3D
	for i in FLANKS.size():
		var flank: Dictionary = FLANKS[i]
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
		# Each movement path now terminates at its own airlock, through an open gate.
		var angle: float = {"Left": -PI / 2, "Right": PI / 2, "Rear": PI}[flank.name]
		var basis := Basis(Vector3.UP, angle)
		var core := Vector3(0, 0, -.65)
		var outer := 6.45 if flank.name == "Rear" else 7.85
		var targets := [core + basis * Vector3(0, .26, outer), core + basis * Vector3(0, .26, 4.85), core + basis * Vector3(0, .71, 3.51)]
		for target in targets:
			var start := path.curve.get_point_position(path.curve.point_count - 1)
			var steps := ceili(start.distance_to(target) / .2)
			for step in range(1, steps + 1):
				path.curve.add_point(start.lerp(target, float(step) / steps))
		approach.get_node("HabitatApproach").position = targets[-1]
		approach.set_meta("entrance", NodePath("../../Habitat/" + flank.name + "Entrance/Arrival"))
		var direction := (ROUTE[1] - ROUTE[0]).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		var yaw := atan2(-direction.x, -direction.z)
		for sign_value in [-1, 1]:
			for prefix in ["IngressPylon", "IngressLight"]:
				var node := approach.get_node(prefix + str(sign_value)) as Node3D
				node.position.x = ROUTE[0].x + side.x * sign_value * 2.15
				node.position.z = ROUTE[0].z + side.z * sign_value * 2.15
				node.rotation.y = yaw
		var label := approach.get_node("ApproachMarking") as Label3D
		label.position = ROUTE[0] - direction * 1.3 + Vector3(0, .025, 0)
		label.rotation.y = yaw
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
	var influence := 1.0 - smoothstep(2.5, 4.2, flank_distance(p))
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
	var graded := ArrayMesh.new()
	graded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(graded, 0)
	st.set_smooth_group(-1)
	st.generate_normals()
	ResourceSaver.save(st.commit(), "res://resources/moon/regolith_expanded.res")
	# Inherit the original terrain, overriding only local ground and obstructions.
	var scene_text := '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="PackedScene" path="res://scenes/moon_surface.tscn" id="base"]\n[ext_resource type="ArrayMesh" path="res://resources/moon/regolith_expanded.res" id="ground"]\n\n[node name="MoonSurface" instance=ExtResource("base")]\n\n[node name="FacetedRegolith" parent="." index="1"]\nmesh = ExtResource("ground")\n'
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
			var blocked := flank_distance(child.position) < 2.4 + radius
			for site in flank_sites + EQUIPMENT_CLEARINGS:
				blocked = blocked or Vector2(child.position.x - site.x, child.position.z - site.z).length() < 2.5 + radius
			if blocked:
				scene_text += '\n[node name="%s" parent="." index="%d"]\nvisible = false\nmetadata/selection_ignore = true\n' % [child.name, child.get_index()]
	FileAccess.open("res://scenes/moon_surface_expanded.tscn", FileAccess.WRITE).store_string(scene_text)
	surface.free()
