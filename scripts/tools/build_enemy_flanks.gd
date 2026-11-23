extends "res://scripts/tools/moon_kit.gd"
## Bake the expanded terrain, four equal-length approaches, and the outer
## highlands as one self-contained scene:
## godot --headless --path . --script res://scripts/tools/build_enemy_flanks.gd
## Everything is assembled and packed in memory; no intermediate source scene
## or hand-written .tscn text is needed.

const TRAVEL_LENGTH := Layout.TRAVEL_LENGTH
var EQUIPMENT_CLEARINGS: Array[Vector3] = []
var _equipment_placements := {}
var _site_scale := Vector3.ONE
var _site_y := 0.0
var _site_number_position := Vector3.ZERO
var _site_number_rotation := Vector3.ZERO
var _site_number_font_size := 0
var _site_number_pixel_size := 0.0
var _outer_landscape: Node3D
var _expanded_strata: ArrayMesh

func _initialize() -> void:
	rng.seed = TerrainStyle.SEED
	dark = TerrainStyle.DARK_MATERIAL
	amber = TerrainStyle.AMBER_MATERIAL
	stone = TerrainStyle.STONE_MATERIAL
	crystal = TerrainStyle.CRYSTAL_MATERIAL
	noise.seed = TerrainStyle.NOISE_SEED
	noise.frequency = TerrainStyle.NOISE_FREQUENCY
	var placements := Layout.outpost_layout()
	if not placements.get("valid", false):
		fail("Could not read outpost layout; run the outpost builders first.")
		return
	SITES.assign(placements.clearings)
	_equipment_placements = placements.equipment
	for node_name in Layout.CLEARING_EQUIPMENT_NODES:
		var data: Dictionary = _equipment_placements[node_name]
		EQUIPMENT_CLEARINGS.append(data.position)
	_site_scale = placements.defense_site_scale
	_site_y = placements.defense_site_y
	_site_number_position = placements.site_number_position
	_site_number_rotation = placements.site_number_rotation
	_site_number_font_size = placements.site_number_font_size
	_site_number_pixel_size = placements.site_number_pixel_size
	# Build the base surface first with the original layout, then reseed so the
	# flank and highland details keep the sequence the standalone bake used.
	var base_route := original_front_route()
	var surface := create_surface(base_route)
	rng.seed = TerrainStyle.SEED
	var layouts: Array = []
	var flank_routes: Array[PackedVector3Array] = []
	var flank_sites: Array[Vector3] = []
	# Keep the front's original waypoints, easing its two tight inside corners.
	var front_curve := Curve3D.new()
	front_curve.bake_interval = TerrainStyle.BAKE_INTERVAL
	for i in WAYPOINTS.size():
		var tangent: Vector3 = (WAYPOINTS[mini(i + 1, WAYPOINTS.size() - 1)] - WAYPOINTS[maxi(i - 1, 0)]).normalized()
		var handle := TerrainStyle.FRONT_HANDLE if i > 0 and i < WAYPOINTS.size() - 1 else 0.0
		front_curve.add_point(WAYPOINTS[i], -tangent * handle, tangent * handle)
	var front_route := front_curve.get_baked_points()
	front_route = extend_to_length(front_route, "Front", TerrainStyle.FRONT_OUTWARD)
	var front := create_approach(front_route)
	orient_ingress(front, front_route)
	front.set_meta(Metadata.TRAVEL_LENGTH, TRAVEL_LENGTH)
	SceneMerge.merge_static_meshes(front, front)
	save_scene(front, "res://scenes/enemy_approach_extended.tscn")
	for flank_name in ["Rear", "Left", "Right"]:
		var points: Array = Layout.FLANK_ROUTES[flank_name]
		var outward: Vector3 = Layout.FLANK_OUTWARD[flank_name]
		var route := extend_to_length(bake_route(points), flank_name, outward)
		flank_routes.append(route)
		var curve := movement_curve(route, flank_name)
		var sites: Array[Vector3] = []
		# Spread the sockets along the extended approach.
		for i in 2:
			var distance: float = curve.get_baked_length() * TerrainStyle.SITE_SAMPLE_DISTANCES[i]
			var point := curve.sample_baked(distance)
			var tangent := (curve.sample_baked(distance + TerrainStyle.ROUTE_SAMPLE_STEP) - point).normalized()
			var side := Vector3(-tangent.z, 0, tangent.x)
			point += side * (TerrainStyle.SITE_SIDE_OFFSET if i == 0 else -TerrainStyle.SITE_SIDE_OFFSET)
			point.y = 0
			sites.append(point)
		var occupant_name: String = Layout.FLANK_SITE_OCCUPANTS.get(flank_name, "")
		if occupant_name.is_empty():
			var distance: float = curve.get_baked_length() * TerrainStyle.FLANK_SITE_END_DISTANCE
			var point := curve.sample_baked(distance)
			var tangent := (curve.sample_baked(distance + TerrainStyle.ROUTE_SAMPLE_STEP) - point).normalized()
			point += Vector3(-tangent.z, 0, tangent.x) * TerrainStyle.SITE_SIDE_OFFSET
			point.y = 0
			sites.append(point)
		else:
			var data: Dictionary = _equipment_placements[occupant_name]
			sites.append(data.position)
		layouts.append({"name": flank_name, "sites": sites})
		for site in sites:
			flank_sites.append(site)
	build_flanks(layouts, flank_routes)
	grade_terrain(surface, front_route, flank_routes, flank_sites)
	if not commit():
		return
	quit()

func bake_route(points: Array) -> PackedVector3Array:
	var curve := Curve3D.new()
	curve.bake_interval = TerrainStyle.BAKE_INTERVAL
	for i in points.size():
		var tangent: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var handle := TerrainStyle.ROUTE_HANDLE
		if i == points.size() - 1:
			# Meet the cardinal gate ramp squarely, with room for the inner edge.
			tangent = Vector3(signf(tangent.x), 0, 0) if absf(tangent.x) > absf(tangent.z) else Vector3(0, 0, signf(tangent.z))
			handle = TerrainStyle.ROUTE_END_HANDLE
		if i > 0 and i < points.size() - 1:
			# Broad bends keep the full-width ribbon from folding at the inside edge.
			handle = minf(TerrainStyle.ROUTE_BEND_HANDLE, minf(points[i].distance_to(points[i - 1]), points[i].distance_to(points[i + 1])) * TerrainStyle.ROUTE_BEND_FACTOR)
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
	var basis := Basis(Vector3.UP, Layout.ENTRANCES[title])
	var core := Layout.CORE
	var outer: float = Layout.GATE_OUTER[title]
	for target in [core + basis * Vector3(0, TerrainStyle.MOVEMENT_CORE_Y, outer), core + basis * Vector3(0, TerrainStyle.MOVEMENT_GATE_Y, TerrainStyle.MOVEMENT_GATE_RADIUS), core + basis * Vector3(0, TerrainStyle.MOVEMENT_HABITAT_Y, TerrainStyle.MOVEMENT_HABITAT_RADIUS)]:
		var start := curve.get_point_position(curve.point_count - 1)
		var steps := ceili(start.distance_to(target) / TerrainStyle.MOVEMENT_STEP)
		for step in range(1, steps + 1):
			curve.add_point(start.lerp(target, float(step) / steps))
	return curve

func extension(base: PackedVector3Array, outward: Vector3, reach: float, title: String) -> PackedVector3Array:
	var start := base[0]
	var side := Vector3(-outward.z, 0, outward.x)
	var points: Array[Vector3] = [start + outward * reach]
	if title == "Rear":
		points[0] += side * reach * TerrainStyle.REAR_EXTENSION_OFFSET
		points.append(start + outward * reach * TerrainStyle.REAR_EXTENSION_MID + side * reach * TerrainStyle.REAR_EXTENSION_SIDE)
		points.append(start + outward * reach * TerrainStyle.REAR_EXTENSION_NEAR - side * reach * TerrainStyle.REAR_EXTENSION_NEAR_SIDE)
	elif title != "Front":
		points.append(start + outward * reach * TerrainStyle.FLANK_EXTENSION_MID + side * minf(TerrainStyle.FLANK_EXTENSION_HANDLE, reach * TerrainStyle.FLANK_EXTENSION_SIDE))
	points.append(start)
	var curve := Curve3D.new()
	curve.bake_interval = TerrainStyle.BAKE_INTERVAL
	for i in points.size():
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var handle := minf(TerrainStyle.FLANK_EXTENSION_HANDLE, reach * TerrainStyle.FLANK_EXTENSION_HANDLE_FACTOR)
		if i == points.size() - 1:
			tangent = (base[1] - base[0]).normalized()
			# Match the tangent of the preserved inner road at the join.
			handle = minf(TerrainStyle.FLANK_EXTENSION_HANDLE, reach * TerrainStyle.FLANK_EXTENSION_HANDLE_FACTOR)
		curve.add_point(points[i], -tangent * handle, tangent * handle)
	var result := curve.get_baked_points()
	result.resize(result.size() - 1)
	result.append_array(base)
	return result

func extend_to_length(base: PackedVector3Array, title: String, outward: Vector3) -> PackedVector3Array:
	var low := TerrainStyle.EXTENSION_LOW
	var high := TRAVEL_LENGTH
	var result: PackedVector3Array
	for iteration in TerrainStyle.EXTENSION_ITERATIONS:
		var reach := (low + high) * .5
		result = extension(base, outward.normalized(), reach, title)
		if movement_curve(result, title).get_baked_length() < TRAVEL_LENGTH:
			low = reach
		else:
			high = reach
	if absf(movement_curve(result, title).get_baked_length() - TRAVEL_LENGTH) >= TerrainStyle.EXTENSION_TOLERANCE:
		fail("Could not fit %s route to %.2f units." % [title, TRAVEL_LENGTH])
		return result
	print(title, " route: ", movement_curve(result, title).get_baked_length(), " units; spawn ", result[0])
	return result

func orient_ingress(approach: Node3D, route: PackedVector3Array) -> void:
	var direction := (route[1] - route[0]).normalized()
	var side := Vector3(-direction.z, 0, direction.x)
	var yaw := atan2(-direction.x, -direction.z)
	for sign_value in [-1, 1]:
		for prefix in ["IngressPylon", "IngressLight"]:
			var node := approach.get_node(prefix + str(sign_value)) as Node3D
			node.position.x = route[0].x + side.x * sign_value * TerrainStyle.APPROACH_PYLON_OFFSET
			node.position.z = route[0].z + side.z * sign_value * TerrainStyle.APPROACH_PYLON_OFFSET
			node.rotation.y = yaw
	var label := approach.get_node("ApproachMarking") as Label3D
	label.position = route[0] - direction * TerrainStyle.APPROACH_LABEL_POSITION.z + Vector3(0, TerrainStyle.APPROACH_LABEL_POSITION.y, 0)
	label.rotation.y = yaw

func build_flanks(layouts: Array, flank_routes: Array[PackedVector3Array]) -> void:
	var root_node := Node3D.new()
	root_node.name = "EnemyFlanks"
	var flank_ground := Node3D.new()
	attach(root_node, flank_ground, "FlankGround")
	for i in layouts.size():
		var flank: Dictionary = layouts[i]
		var approach := create_approach(flank_routes[i])
		attach(root_node, approach, flank.name + "Approach")
		Metadata.set_display_name(approach, flank.name + " — Enemy Approach")
		approach.add_to_group("enemy_approaches", true)
		var path := approach.get_node("EnemyPath") as Path3D
		path.curve = movement_curve(flank_routes[i], flank.name)
		approach.get_node("HabitatApproach").position = path.curve.get_point_position(path.curve.point_count - 1)
		approach.set_meta(Metadata.ENTRANCE, NodePath("../../Habitat/" + flank.name + "Entrance/Arrival"))
		approach.set_meta(Metadata.TRAVEL_LENGTH, TRAVEL_LENGTH)
		orient_ingress(approach, flank_routes[i])
		SceneMerge.merge_static_meshes(approach, approach)
		# Keep INBOUND at the original size; direction names live in selection metadata.
		var sites := Node3D.new()
		attach(approach, sites, "DefenseSites")
		for j in flank.sites.size():
			var site_position: Vector3 = flank.sites[j]
			var occupant := ""
			for data in _equipment_placements.values():
				var placed: Vector3 = data.position
				if Vector2(site_position.x - placed.x, site_position.z - placed.z).length() < 1.0:
					occupant = data.display_name
					break
			var site := load("res://scenes/models/defensive_build_site.tscn").instantiate() as Node3D
			attach(sites, site, "DefenseSite%02d" % (j + 1))
			site.position = site_position + Vector3(0, _site_y, 0)
			site.scale = _site_scale
			site.add_to_group("defensive_build_sites", true)
			Metadata.set_display_name(site, "%s Defense Site %02d — %s" % [flank.name, j + 1, occupant if not occupant.is_empty() else "Vacant"])
			site.set_meta(Metadata.OCCUPIED, not occupant.is_empty())
			site.set_meta(Metadata.APPROACH, flank.name.to_lower())
			var number := Label3D.new()
			number.text = "%s%02d" % [Layout.SITE_NUMBER_PREFIX[flank.name], j + 1]
			number.position = _site_number_position
			number.rotation = _site_number_rotation
			number.font_size = _site_number_font_size
			number.pixel_size = _site_number_pixel_size
			number.outline_size = 0
			attach(site, number, "SiteNumber")
			number.owner = root_node
			var mount := Marker3D.new()
			mount.position = Layout.DEFENSE_MOUNT_POSITION
			attach(site, mount, "DefenseMount")
			mount.owner = root_node
			terrace(flank_ground, "%sSiteBedrock%02d" % [flank.name, j + 1], site_position + Layout.SITE_BEDROCK_OFFSET, Layout.SITE_BEDROCK_SIZE, Layout.SITE_BEDROCK_LAYERS)
			cylinder(flank_ground, "%sDefenseExcavation%02d" % [flank.name, j + 1], site_position + Layout.SITE_EXCAVATION_OFFSET, TerrainStyle.SITE_EXCAVATION_TOP_RADIUS, TerrainStyle.SITE_EXCAVATION_BOTTOM_RADIUS, TerrainStyle.SITE_EXCAVATION_HEIGHT, stone, TerrainStyle.SITE_EXCAVATION_SIDES)
	SceneMerge.merge_static_meshes(flank_ground, root_node)
	# Generated descendants belong to the baked scene; retain build-site instancing.
	own_children(root_node, root_node)
	save_scene(root_node, "res://scenes/enemy_flanks.tscn")

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

func flank_distance(p: Vector3, flank_routes: Array[PackedVector3Array]) -> float:
	p.y = 0
	var result := INF
	for route in flank_routes:
		result = minf(result, distance_to_route(p, route))
	return result

func grading(p: Vector3, front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> float:
	p.y = 0
	var influence := 1.0 - smoothstep(TerrainStyle.ROUTE_CLEARANCE, TerrainStyle.ROUTE_CLEARANCE + TerrainStyle.GRADE_ROUTE_FALLOFF, minf(flank_distance(p, flank_routes), distance_to_route(p, front_route)))
	for site in flank_sites + EQUIPMENT_CLEARINGS:
		influence = maxf(influence, 1.0 - smoothstep(TerrainStyle.GRADE_SITE_CLEARANCE, TerrainStyle.GRADE_SITE_CLEARANCE + TerrainStyle.GRADE_SITE_FALLOFF, p.distance_to(site)))
	return influence

func grade_terrain(surface: Node3D, front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> void:
	# The original surface is already in memory; the expanded ground and cliff
	# replace its two terrain nodes, and the outer highlands joins as a child.
	var ground := surface.get_node("FacetedRegolith") as MeshInstance3D
	var arrays := ground.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i].y = lerpf(vertices[i].y, TerrainStyle.GROUND_LEVEL, grading(vertices[i], front_route, flank_routes, flank_sites))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var expanded := expand_ground(arrays, front_route, flank_routes, flank_sites)
	ground.mesh = external_mesh(expanded, "res://resources/moon/regolith_expanded.res")
	var strata := surface.get_node("ExposedShelfStrata") as MeshInstance3D
	strata.mesh = _expanded_strata
	# Shift complete rock formations as units, leaving the station buildings intact.
	var shifts := TerrainStyle.TERRAIN_SHIFTS
	var rejected: Array[Node] = []
	for child in surface.get_children():
		if not child is Node3D:
			continue
		var shifted := false
		for prefix in shifts:
			if str(child.name).begins_with(prefix):
				child.position += shifts[prefix]
				shifted = true
				break
		if shifted:
			continue
		if str(child.name).begins_with("Scree") or str(child.name).begins_with("CraterRim") or str(child.name).begins_with("LumenCrystal") or str(child.name).begins_with("CrystalLight"):
			var radius := 0.0
			if child is MeshInstance3D:
				var bounds: AABB = child.transform * child.get_aabb()
				radius = maxf(bounds.size.x, bounds.size.z) * .5
			var blocked := minf(flank_distance(child.position, flank_routes), distance_to_route(child.position, front_route)) < TerrainStyle.GRADE_ROUTE_CLEARANCE + radius
			for site in flank_sites + EQUIPMENT_CLEARINGS:
				blocked = blocked or Vector2(child.position.x - site.x, child.position.z - site.z).length() < TerrainStyle.GRADE_SITE_CLEARANCE + radius
			if blocked:
				rejected.append(child)
	for child in rejected:
		child.get_parent().remove_child(child)
		child.free()
	surface.add_child(_outer_landscape, true)
	merge_static_terrain(surface)
	own_children(surface, surface)
	save_scene(surface, "res://scenes/moon_surface_expanded.tscn")

## Collapse thousands of static terrain decorations into one mesh per material.
## The original ground and cliff meshes stay separate so their external resources
## remain easy to inspect and replace.
func merge_static_terrain(root: Node3D) -> void:
	var groups := {}
	var to_remove: Array[Node] = []
	_collect_static_meshes(root, Transform3D.IDENTITY, groups, to_remove)
	for node in to_remove:
		node.get_parent().remove_child(node)
		node.free()
	var index := 0
	for key in groups:
		var group: Dictionary = groups[key]
		if group.count == 0:
			continue
		var shape: ArrayMesh = external_mesh(group.tool.commit(), "res://resources/moon/terrain_merged_%02d.res" % index)
		mesh_node(root, "MergedTerrain%02d" % index, shape, Vector3.ZERO, group.material)
		index += 1

func _collect_static_meshes(node: Node, parent_transform: Transform3D, groups: Dictionary, to_remove: Array[Node]) -> void:
	# Hidden decorations were rejected by the grading pass; never fold their
	# geometry into a visible merged mesh.
	if node is Node3D and not node.visible:
		return
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null and not Metadata.selection_ignored(node) and node.name != "FacetedRegolith" and node.name != "ExposedShelfStrata":
		var material: Material = node.material_override
		var key := material.get_instance_id() if material != null else 0
		if not groups.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_smooth_group(-1)
			groups[key] = {"tool": tool, "material": material, "count": 0}
		var group: Dictionary = groups[key]
		for surface in node.mesh.get_surface_count():
			group.tool.append_from(node.mesh, surface, transform)
		group.count += 1
		to_remove.append(node)
	for child in node.get_children():
		_collect_static_meshes(child, transform, groups, to_remove)

## Keep every original terrain triangle; stitch new cells onto its boundary and
## move the exposed cliff strata to a larger, irregular shelf outline.
func expanded_shelf(x: float, z: float) -> bool:
	var angle := atan2(z, x)
	var radius := 1.0 + TerrainStyle.EXPANDED_SHELF_WOBBLE * sin(angle * TerrainStyle.EXPANDED_SHELF_WOBBLE_FREQUENCY + TerrainStyle.EXPANDED_SHELF_WOBBLE_PHASE) + TerrainStyle.EXPANDED_SHELF_WOBBLE_COS * cos(angle * TerrainStyle.EXPANDED_SHELF_WOBBLE_COS_FREQUENCY)
	return pow(absf(x) / (TerrainStyle.EXPANDED_SHELF_RADIUS.x * radius), TerrainStyle.EXPANDED_SHELF_POWER) + pow(absf(z) / (TerrainStyle.EXPANDED_SHELF_DEPTH_RADIUS * radius), TerrainStyle.EXPANDED_SHELF_POWER) < 1.0

func terrain_corner(key: Vector2i, known: Dictionary, front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> Vector3:
	if known.has(key):
		return known[key]
	var jitter := RandomNumberGenerator.new()
	jitter.seed = absi(key.x * 73856093 ^ key.y * 19349663)
	var p := Vector3(key.x + jitter.randf_range(-TerrainStyle.GRID_JITTER, TerrainStyle.GRID_JITTER), 0, key.y + jitter.randf_range(-TerrainStyle.GRID_JITTER, TerrainStyle.GRID_JITTER))
	p.y = lerpf(height_at(p.x, p.z, front_route), TerrainStyle.GROUND_LEVEL, grading(p, front_route, flank_routes, flank_sites))
	known[key] = p
	return p

func expand_ground(arrays: Array, front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> ArrayMesh:
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
	for z in range(TerrainStyle.EXPANDED_GROUND_RECT.position.y, TerrainStyle.EXPANDED_GROUND_RECT.end.y):
		for x in range(TerrainStyle.EXPANDED_GROUND_RECT.position.x, TerrainStyle.EXPANDED_GROUND_RECT.end.x):
			if not expanded_shelf(x + .5, z + .5):
				continue
			var a := terrain_corner(Vector2i(x, z), known, front_route, flank_routes, flank_sites)
			var b := terrain_corner(Vector2i(x + 1, z), known, front_route, flank_routes, flank_sites)
			var c := terrain_corner(Vector2i(x, z + 1), known, front_route, flank_routes, flank_sites)
			var d := terrain_corner(Vector2i(x + 1, z + 1), known, front_route, flank_routes, flank_sites)
			if not inside_shelf(x + .5, z + .5):
				var tint := TerrainStyle.SHELF_COLOR.lerp(TerrainStyle.SHELF_LIGHT_COLOR, rng.randf_range(TerrainStyle.SHELF_TINT_START, TerrainStyle.SHELF_TINT_END))
				triangle(ground, a, c, b, tint)
				triangle(ground, b, c, d, tint.darkened(rng.randf_range(0, TerrainStyle.SHELF_DARKEN)))
			if not expanded_shelf(x - .5, z + .5): shelf_wall(skirt, a, c)
			if not expanded_shelf(x + 1.5, z + .5): shelf_wall(skirt, d, b)
			if not expanded_shelf(x + .5, z - .5): shelf_wall(skirt, b, a)
			if not expanded_shelf(x + .5, z + 1.5): shelf_wall(skirt, c, d)
	ground.generate_normals()
	skirt.generate_normals()
	_expanded_strata = external_mesh(skirt.commit(), "res://resources/moon/expanded_strata.res")
	_outer_landscape = build_outer_landscape(front_route, flank_routes, flank_sites)
	return ground.commit()

func outer_height(p: Vector3, front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> float:
	return lerpf(height_at(p.x, p.z, front_route), TerrainStyle.GROUND_LEVEL, grading(p, front_route, flank_routes, flank_sites))

func clear_of_routes(p: Vector3, radius: float, front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> bool:
	if minf(flank_distance(p, flank_routes), distance_to_route(p, front_route)) < radius + TerrainStyle.ROUTE_CLEARANCE:
		return false
	for site in flank_sites + EQUIPMENT_CLEARINGS + SITES:
		if Vector2(p.x - site.x, p.z - site.z).length() < radius + TerrainStyle.SITE_CLEARANCE:
			return false
	return true

func build_outer_landscape(front_route: PackedVector3Array, flank_routes: Array[PackedVector3Array], flank_sites: Array[Vector3]) -> Node3D:
	var landscape := Node3D.new()
	landscape.name = "OuterHighlands"
	for i in TerrainStyle.OUTER_ESCARPMENTS.size():
		var p: Vector3 = TerrainStyle.OUTER_ESCARPMENTS[i]
		if clear_of_routes(p, TerrainStyle.OUTER_ESCARPMENT_CLEARANCE, front_route, flank_routes, flank_sites):
			p.y = outer_height(p, front_route, flank_routes, flank_sites) + TerrainStyle.OUTER_ESCARPMENT_OFFSET
			terrace(landscape, "OuterEscarpment%02d" % i, p, Vector3(TerrainStyle.OUTER_ESCARPMENT_WIDTH, TerrainStyle.OUTER_ESCARPMENT_BASE_HEIGHT + (i % 3) * TerrainStyle.OUTER_ESCARPMENT_HEIGHT_STEP, TerrainStyle.OUTER_ESCARPMENT_DEPTH), TerrainStyle.ESCARPMENT_LAYERS)
	var rock := slab_mesh(TerrainStyle.OUTER_SLAB_SEED)
	for i in TerrainStyle.OUTER_SCREE_COUNT:
		var p := Vector3(rng.randf_range(TerrainStyle.OUTER_SCREE_RECT.position.x, TerrainStyle.OUTER_SCREE_RECT.end.x), 0, rng.randf_range(TerrainStyle.OUTER_SCREE_RECT.position.y, TerrainStyle.OUTER_SCREE_RECT.end.y))
		if inside_shelf(p.x, p.z) or not expanded_shelf(p.x * TerrainStyle.OUTER_CRYSTAL_SHELF_SCALE, p.z * TerrainStyle.OUTER_CRYSTAL_SHELF_SCALE) or not clear_of_routes(p, TerrainStyle.OUTER_SCREE_CLEARANCE, front_route, flank_routes, flank_sites):
			continue
		p.y = outer_height(p, front_route, flank_routes, flank_sites) + TerrainStyle.OUTER_SCREE_HEIGHT_OFFSET
		var node := mesh_node(landscape, "OuterScree%03d" % i, rock, p, stone)
		var size := rng.randf_range(TerrainStyle.OUTER_SCREE_MIN, TerrainStyle.OUTER_SCREE_MAX)
		node.scale = Vector3(size * TerrainStyle.OUTER_SCREE_SCALE, size, size)
		node.rotation.y = rng.randf() * TAU
	var shard := rock_mesh(true)
	var shard_mat := TerrainStyle.CRYSTAL_MATERIAL
	for i in TerrainStyle.OUTER_CRYSTAL_COLONIES.size():
		var p: Vector3 = TerrainStyle.OUTER_CRYSTAL_COLONIES[i]
		if not clear_of_routes(p, TerrainStyle.OUTER_CRYSTAL_CLEARANCE, front_route, flank_routes, flank_sites): continue
		for j in TerrainStyle.CRYSTAL_COUNT:
			var point := p + Vector3(rng.randf_range(-TerrainStyle.OUTER_CRYSTAL_OFFSET, TerrainStyle.OUTER_CRYSTAL_OFFSET), 0, rng.randf_range(-TerrainStyle.OUTER_CRYSTAL_OFFSET, TerrainStyle.OUTER_CRYSTAL_OFFSET))
			point.y = outer_height(point, front_route, flank_routes, flank_sites) + TerrainStyle.OUTER_CRYSTAL_HEIGHT_OFFSET
			var node := mesh_node(landscape, "OuterCrystal%d_%d" % [i, j], shard, point, shard_mat)
			node.scale = Vector3(TerrainStyle.OUTER_CRYSTAL_SCALE.x, rng.randf_range(TerrainStyle.OUTER_CRYSTAL_SCALE.y, TerrainStyle.OUTER_CRYSTAL_MAX_Y), TerrainStyle.OUTER_CRYSTAL_SCALE.z)
			node.rotation.y = rng.randf() * TAU
	return landscape
