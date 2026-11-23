extends "res://scripts/tools/build_kit.gd"
## Moon terrain and approach geometry shared by the environment generator.
## No output is produced here; build_enemy_flanks.gd assembles and saves it.

const Layout = preload("res://scripts/world_layout.gd")
const TerrainStyle = preload("res://scripts/terrain_style.gd")
const WAYPOINTS := Layout.WAYPOINTS
var SITES: Array[Vector3] = []
var noise := FastNoiseLite.new()
var stone: StandardMaterial3D
var crystal: StandardMaterial3D
var _slab_cache := {}
var _rock_cache := {}

## Terrain winding is inverted relative to the solid model kit so the visible
## upper faces point up. The calls below pass their edge pairs in ribbon order.
func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color := Color.WHITE) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

func original_front_route() -> PackedVector3Array:
	var curve := Curve3D.new()
	curve.bake_interval = TerrainStyle.BAKE_INTERVAL
	for i in WAYPOINTS.size():
		var tangent: Vector3 = (WAYPOINTS[mini(i + 1, WAYPOINTS.size() - 1)] - WAYPOINTS[maxi(i - 1, 0)]).normalized()
		var handle := TerrainStyle.ORIGINAL_FRONT_HANDLE if i > 0 and i < WAYPOINTS.size() - 1 else 0.0
		curve.add_point(WAYPOINTS[i], -tangent * handle, tangent * handle)
	return curve.get_baked_points()

func route_distance(p: Vector3, route: PackedVector3Array) -> float:
	var result := INF
	for i in range(route.size() - 1):
		var a: Vector3 = route[i]
		var b: Vector3 = route[i + 1]
		a.y = 0
		b.y = 0
		result = minf(result, p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)))
	return result

func height_at(x: float, z: float, route: PackedVector3Array) -> float:
	var p := Vector3(x, 0, z)
	var clearing := 1.0 - smoothstep(TerrainStyle.CLEARING_START, TerrainStyle.CLEARING_END, Vector2(x, z).length())
	clearing = maxf(clearing, 1.0 - smoothstep(TerrainStyle.ROUTE_CLEARING_START, TerrainStyle.ROUTE_CLEARING_END, route_distance(p, route)))
	for site in SITES:
		clearing = maxf(clearing, 1.0 - smoothstep(TerrainStyle.SITE_CLEARING_START, TerrainStyle.SITE_CLEARING_END, p.distance_to(site)))
	var hills := TerrainStyle.BASE_HEIGHT + noise.get_noise_2d(x, z) * TerrainStyle.NOISE_AMPLITUDE
	# A broken escarpment shelters the station from the moon's highlands.
	hills += TerrainStyle.ESCARPMENT_HEIGHT * exp(-pow((x - TerrainStyle.ESCARPMENT_CENTER.x) / TerrainStyle.ESCARPMENT_WIDTH, 2)) * exp(-pow((z - TerrainStyle.ESCARPMENT_CENTER.y) / TerrainStyle.ESCARPMENT_LENGTH, 2))
	hills += TerrainStyle.SOUTH_RIDGE_HEIGHT * exp(-pow((z - TerrainStyle.SOUTH_RIDGE_CENTER.y) / TerrainStyle.SOUTH_RIDGE_WIDTH, 2))
	# Bowl floors and ejecta rims are part of the continuous terrain.
	for impact: Vector3 in TerrainStyle.CRATERS:
		var d: float = Vector2(x - impact.x, z - impact.z).length() / impact.y
		var bowl := -TerrainStyle.BOWL_DEPTH * (1.0 - smoothstep(TerrainStyle.BOWL_START, TerrainStyle.BOWL_END, d))
		var rim := TerrainStyle.BOWL_RIM_HEIGHT * exp(-pow((d - TerrainStyle.BOWL_RIM_CENTER) / TerrainStyle.BOWL_RIM_WIDTH, 2))
		hills += bowl + rim
	return lerpf(hills, TerrainStyle.GROUND_LEVEL, clearing)

func create_surface(route: PackedVector3Array) -> Node3D:
	var surface := Node3D.new()
	surface.name = "MoonSurface"
	surface.set_meta(Metadata.PICKING_TERRAIN, true)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# A raised, eroded shelf follows the isometric layout in concept sheet 2.
	var grid: Array[Vector3] = []
	for z in TerrainStyle.GRID_COUNT:
		for x in TerrainStyle.GRID_COUNT:
			var px := (x - TerrainStyle.GRID_ORIGIN.x) * TerrainStyle.GRID_STEP
			var pz := (z - TerrainStyle.GRID_ORIGIN.y) * TerrainStyle.GRID_STEP
			if x > 0 and x < TerrainStyle.GRID_COUNT - 1 and z > 0 and z < TerrainStyle.GRID_COUNT - 1:
				px += rng.randf_range(-TerrainStyle.GRID_JITTER, TerrainStyle.GRID_JITTER)
				pz += rng.randf_range(-TerrainStyle.GRID_JITTER, TerrainStyle.GRID_JITTER)
			grid.append(Vector3(px, height_at(px, pz, route), pz))
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	skirt.set_smooth_group(-1)
	for z in TerrainStyle.GRID_COUNT - 1:
		for x in TerrainStyle.GRID_COUNT - 1:
			if not inside_shelf(x - (TerrainStyle.GRID_ORIGIN.x - 0.5), z - (TerrainStyle.GRID_ORIGIN.y - 0.5)):
				continue
			var a := grid[z * TerrainStyle.GRID_COUNT + x]
			var b := grid[z * TerrainStyle.GRID_COUNT + x + 1]
			var c := grid[(z + 1) * TerrainStyle.GRID_COUNT + x]
			var d := grid[(z + 1) * TerrainStyle.GRID_COUNT + x + 1]
			var tint := TerrainStyle.SHELF_COLOR.lerp(TerrainStyle.SHELF_LIGHT_COLOR, rng.randf_range(TerrainStyle.SHELF_TINT_START, TerrainStyle.SHELF_TINT_END))
			triangle(st, a, c, b, tint)
			triangle(st, b, c, d, tint.darkened(rng.randf_range(0.0, TerrainStyle.SHELF_DARKEN)))
			if not inside_shelf(x - (TerrainStyle.GRID_ORIGIN.x + 0.5), z - (TerrainStyle.GRID_ORIGIN.y - 0.5)):
				shelf_wall(skirt, a, c)
			if not inside_shelf(x - (TerrainStyle.GRID_ORIGIN.x - 1.5), z - (TerrainStyle.GRID_ORIGIN.y - 0.5)):
				shelf_wall(skirt, d, b)
			if not inside_shelf(x - (TerrainStyle.GRID_ORIGIN.x - 0.5), z - (TerrainStyle.GRID_ORIGIN.y + 0.5)):
				shelf_wall(skirt, b, a)
			if not inside_shelf(x - (TerrainStyle.GRID_ORIGIN.x - 0.5), z - (TerrainStyle.GRID_ORIGIN.y - 1.5)):
				shelf_wall(skirt, c, d)
	st.generate_normals()
	skirt.generate_normals()
	var bedrock := material(Color.WHITE)
	bedrock.vertex_color_use_as_albedo = true
	mesh_node(surface, "ExposedShelfStrata", skirt.commit(), Vector3.ZERO, bedrock)
	var ground_mat := load("res://resources/moon/regolith_material.tres")
	mesh_node(surface, "FacetedRegolith", st.commit(), Vector3.ZERO, ground_mat)
	var boulder := slab_mesh(TerrainStyle.SLAB_SEED)
	# Sheltering stacks of fractured sediment, with broad tops and exposed strata.
	for i in TerrainStyle.LANDMARKS.size():
		var p: Vector3 = TerrainStyle.LANDMARKS[i]
		var height: float = p.y
		p.y = height_at(p.x, p.z, route) + TerrainStyle.ESCARPMENT_OFFSET
		terrace(surface, "Escarpment%02d" % i, p, Vector3(TerrainStyle.ESCARPMENT_TERRACE_WIDTH, height * TerrainStyle.ESCARPMENT_HEIGHT_FACTOR, TerrainStyle.ESCARPMENT_DEPTH), TerrainStyle.ESCARPMENT_LAYERS)
	build_arch(surface, Vector3(TerrainStyle.ARCH_BASE_XZ.x, height_at(TerrainStyle.ARCH_BASE_XZ.x, TerrainStyle.ARCH_BASE_XZ.y, route), TerrainStyle.ARCH_BASE_XZ.y))
	for impact in TerrainStyle.CRATERS:
		for j in TerrainStyle.CRATER_RIM_COUNT:
			var a := j * TAU / TerrainStyle.CRATER_RIM_COUNT
			var p := Vector3(impact.x + cos(a) * impact.y, 0, impact.z + sin(a) * impact.y)
			p.y = height_at(p.x, p.z, route) + TerrainStyle.CRATER_RIM_HEIGHT_OFFSET
			var slab := mesh_node(surface, "CraterRim%d_%d" % [int(impact.x), j], slab_mesh(j + TerrainStyle.CRATER_SLAB_SEED), p, stone)
			slab.scale = Vector3(TerrainStyle.CRATER_RIM_SCALE.x, rng.randf_range(TerrainStyle.CRATER_RIM_SCALE.y, TerrainStyle.CRATER_RIM_MAX_Y), TerrainStyle.CRATER_RIM_SCALE.z)
			slab.rotation.y = -a + PI / 2

	for i in TerrainStyle.SCREE_COUNT:
		var p := Vector3(rng.randf_range(TerrainStyle.SCREE_RECT.position.x, TerrainStyle.SCREE_RECT.end.x), 0, rng.randf_range(TerrainStyle.SCREE_RECT.position.y, TerrainStyle.SCREE_RECT.end.y))
		if not inside_shelf(p.x, p.z, TerrainStyle.SHELF_INSET) or Vector2(p.x, p.z).length() < TerrainStyle.SCREE_CLEAR_RADIUS or route_distance(p, route) < TerrainStyle.SCREE_ROUTE_CLEARANCE:
			continue
		var blocked := false
		for site in SITES:
			if p.distance_to(site) < TerrainStyle.SCREE_SITE_CLEARANCE:
				blocked = true
		if blocked:
			continue
		p.y = height_at(p.x, p.z, route) + TerrainStyle.SCREE_Y_OFFSET
		var rock := mesh_node(surface, "Scree%03d" % i, boulder, p, stone)
		var s := rng.randf_range(TerrainStyle.SCREE_MIN_SCALE, TerrainStyle.SCREE_MAX_SCALE)
		rock.scale = Vector3(s * TerrainStyle.SCREE_SCALE_X, s, s)
		rock.rotation.y = rng.randf() * TAU
	var shard := rock_mesh(true)
	for i in TerrainStyle.CRYSTAL_COLONIES.size():
		var colony: Vector3 = TerrainStyle.CRYSTAL_COLONIES[i]
		var glow := OmniLight3D.new()
		glow.position = colony + Vector3(0, height_at(colony.x, colony.z, route) + TerrainStyle.CRYSTAL_LIGHT_HEIGHT, 0)
		glow.light_color = TerrainStyle.CRYSTAL_LIGHT_COLOR
		glow.light_energy = TerrainStyle.CRYSTAL_LIGHT_ENERGY
		glow.omni_range = TerrainStyle.CRYSTAL_LIGHT_RANGE
		attach(surface, glow, "CrystalLight%d" % i)
		for j in TerrainStyle.CRYSTAL_COUNT:
			var p: Vector3 = colony + Vector3(rng.randf_range(-TerrainStyle.CRYSTAL_OFFSET.x, TerrainStyle.CRYSTAL_OFFSET.x), 0, rng.randf_range(-TerrainStyle.CRYSTAL_OFFSET.y, TerrainStyle.CRYSTAL_OFFSET.y))
			p.y = height_at(p.x, p.z, route) + TerrainStyle.CRYSTAL_Y_OFFSET
			var node := mesh_node(surface, "LumenCrystal%d_%d" % [i, j], shard, p, crystal)
			node.scale = Vector3(TerrainStyle.CRYSTAL_SCALE.x, rng.randf_range(TerrainStyle.CRYSTAL_SCALE.y, TerrainStyle.CRYSTAL_MAX_Y), TerrainStyle.CRYSTAL_SCALE.z)
			node.rotation = Vector3(rng.randf_range(-TerrainStyle.CRYSTAL_ROTATION.x, TerrainStyle.CRYSTAL_ROTATION.x), rng.randf() * TAU, TerrainStyle.CRYSTAL_ROTATION.z)
	# Shallow foundation slabs anchor the original buildings in the regolith.
	box(surface, "HabitatFoundation", TerrainStyle.HABITAT_FOUNDATION_POSITION, TerrainStyle.HABITAT_FOUNDATION_SIZE, dark)
	for i in SITES.size():
		var site: Vector3 = SITES[i]
		terrace(surface, "SiteBedrock%02d" % i, site + Layout.SITE_BEDROCK_OFFSET, Layout.SITE_BEDROCK_SIZE, Layout.SITE_BEDROCK_LAYERS)
		cylinder(surface, "DefenseExcavation%02d" % i, site + Layout.SITE_EXCAVATION_OFFSET, TerrainStyle.SITE_EXCAVATION_TOP_RADIUS, TerrainStyle.SITE_EXCAVATION_BOTTOM_RADIUS, TerrainStyle.SITE_EXCAVATION_HEIGHT, stone, TerrainStyle.SITE_EXCAVATION_SIDES)
	return surface

func rock_mesh(pointed: bool) -> ArrayMesh:
	if _rock_cache.has(pointed):
		return _rock_cache[pointed]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := TerrainStyle.ROCK_POINTED_SEGMENTS if pointed else TerrainStyle.ROCK_ROUND_SEGMENTS
	for i in n:
		var a := float(i) * TAU / n
		var b := float(i + 1) * TAU / n
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		var u := Vector3(cos(a) * TerrainStyle.ROCK_SIDE_SCALE + TerrainStyle.ROCK_SIDE_OFFSET.x, TerrainStyle.ROCK_SIDE_OFFSET.y, sin(a) * TerrainStyle.ROCK_SIDE_SCALE)
		var v := Vector3(cos(b) * TerrainStyle.ROCK_SIDE_SCALE + TerrainStyle.ROCK_SIDE_OFFSET.x, TerrainStyle.ROCK_SIDE_OFFSET.y, sin(b) * TerrainStyle.ROCK_SIDE_SCALE)
		var tip := Vector3(TerrainStyle.ROCK_TIP.x, TerrainStyle.ROCK_TIP.y if pointed else TerrainStyle.ROCK_ROUND_TIP_Y, TerrainStyle.ROCK_TIP.z)
		var facet := Color.WHITE.lerp(TerrainStyle.ROCK_FACET_COLOR, float(i % 3) * 0.3)
		triangle(st, p, u, q, facet.darkened(TerrainStyle.ROCK_FACET_DARKEN))
		triangle(st, q, u, v, facet)
		triangle(st, u, tip, v, facet.lightened(TerrainStyle.ROCK_FACET_LIGHTEN))
	st.generate_normals()
	_rock_cache[pointed] = st.commit()
	return _rock_cache[pointed]

## Shared road geometry keeps additional approaches at the original scale.
func create_approach(route: PackedVector3Array) -> Node3D:
	var approach := Node3D.new()
	approach.name = "EnemyApproach"
	Metadata.set_display_name(approach, "Moonpass — Enemy Approach")
	var path := Path3D.new()
	path.curve = Curve3D.new()
	for point in route:
		path.curve.add_point(point)
	attach(approach, path, "EnemyPath")
	var route_mat := TerrainStyle.ROUTE_MATERIAL
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# A continuous mitered ribbon follows the exact movement path.
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in route.size():
		var before: Vector3 = route[maxi(0, i - 1)]
		var after: Vector3 = route[mini(route.size() - 1, i + 1)]
		var tangent := (after - before).normalized()
		var side := Vector3(-tangent.z, 0, tangent.x) * TerrainStyle.APPROACH_ROAD_WIDTH
		left.append(route[i] + side)
		right.append(route[i] - side)
	for i in route.size() - 1:
		triangle(st, left[i], left[i + 1], right[i], Color.WHITE)
		triangle(st, right[i], left[i + 1], right[i + 1], Color.WHITE)
	st.generate_normals()
	mesh_node(approach, "CompactedMoonDust", st.commit(), Vector3.ZERO, route_mat)
	for edge in [-1, 1]:
		var rail := SurfaceTool.new()
		rail.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in route.size() - 1:
			var a: Vector3 = left[i] if edge < 0 else right[i]
			var b: Vector3 = left[i + 1] if edge < 0 else right[i + 1]
			var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * TerrainStyle.APPROACH_EDGE_WIDTH
			var lift := Vector3(0, TerrainStyle.APPROACH_EDGE_LIFT, 0)
			triangle(rail, a - side + lift, a + side + lift, b - side + lift, Color.WHITE)
			triangle(rail, a + side + lift, b + side + lift, b - side + lift, Color.WHITE)
		rail.generate_normals()
		mesh_node(approach, "AmberRouteEdge%d" % edge, rail.commit(), Vector3.ZERO, amber)
	var length := path.curve.get_baked_length()
	for i in range(1, int(length / TerrainStyle.APPROACH_GUIDE_SPACING)):
		var distance := i * TerrainStyle.APPROACH_GUIDE_SPACING
		var p := path.curve.sample_baked(distance)
		var direction := (path.curve.sample_baked(minf(distance + 0.1, length)) - p).normalized()
		var side := Vector3(-direction.z, 0, direction.x)
		for sign_value in [-1, 1]:
			var position: Vector3 = p + side * sign_value * TerrainStyle.APPROACH_GUIDE_OFFSET
			box(approach, "GuidePost%d_%d" % [i, sign_value], position + Vector3(0, TerrainStyle.APPROACH_GUIDE_POST_Y, 0), TerrainStyle.APPROACH_GUIDE_POST_SIZE, dark)
			box(approach, "AmberGuide%d_%d" % [i, sign_value], position + Vector3(0, TerrainStyle.APPROACH_GUIDE_LIGHT_Y, 0), TerrainStyle.APPROACH_GUIDE_LIGHT_SIZE, amber)
		# Inlaid arrows point toward the station.
		for sign_value in [-1, 1]:
			var mark := box(approach, "Direction%d_%d" % [i, sign_value], p + side * sign_value * TerrainStyle.APPROACH_DIRECTION_OFFSET + Vector3(0, TerrainStyle.APPROACH_DIRECTION_SIZE.y, 0), TerrainStyle.APPROACH_DIRECTION_SIZE, amber)
			mark.rotation.y = atan2(direction.x, direction.z) + sign_value * TerrainStyle.APPROACH_DIRECTION_ANGLE
	for i in [-1, 1]:
		var p: Vector3 = route[0] + Vector3(i * TerrainStyle.APPROACH_PYLON_OFFSET, 0, 0)
		box(approach, "IngressPylon%d" % i, p + Vector3(0, TerrainStyle.APPROACH_PYLON_Y, 0), TerrainStyle.APPROACH_PYLON_SIZE, dark)
		box(approach, "IngressLight%d" % i, p + Vector3(0, TerrainStyle.APPROACH_LIGHT_Y, 0), TerrainStyle.APPROACH_LIGHT_SIZE, amber)
	var spawn := Marker3D.new()
	spawn.position = route[0]
	attach(approach, spawn, "EnemySpawn")
	var destination := Marker3D.new()
	destination.position = route[-1]
	attach(approach, destination, "HabitatApproach")
	var label := Label3D.new()
	label.text = "INBOUND"
	label.font_size = TerrainStyle.APPROACH_LABEL_FONT_SIZE
	label.pixel_size = TerrainStyle.APPROACH_LABEL_PIXEL_SIZE
	label.outline_size = 0
	label.modulate = TerrainStyle.APPROACH_LABEL_COLOR
	label.position = route[0] + TerrainStyle.APPROACH_LABEL_POSITION
	label.rotation.x = -PI / 2
	attach(approach, label, "ApproachMarking")
	return approach

## A fractured, flat-topped slab. The shared silhouette makes stacks read as strata.
func slab_mesh(seed_value: int) -> ArrayMesh:
	if _slab_cache.has(seed_value):
		return _slab_cache[seed_value]
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var ring: Array[Vector3] = []
	for i in TerrainStyle.SLAB_RING:
		var angle := TAU * i / float(TerrainStyle.SLAB_RING) + PI / 8
		var r := local_rng.randf_range(TerrainStyle.SLAB_RADIUS.x, TerrainStyle.SLAB_RADIUS.y)
		ring.append(Vector3(cos(angle) * r, 0, sin(angle) * r))
	for i in TerrainStyle.SLAB_RING:
		var p := ring[i]
		var q := ring[(i + 1) % TerrainStyle.SLAB_RING]
		var u := p * TerrainStyle.SLAB_TOP_SCALE + TerrainStyle.SLAB_TOP_OFFSET
		var v := q * TerrainStyle.SLAB_TOP_SCALE + TerrainStyle.SLAB_TOP_OFFSET
		triangle(st, p, u, q, Color.WHITE)
		triangle(st, q, u, v, Color.WHITE)
		triangle(st, u, Vector3(0, 1, 0), v, Color.WHITE)
	st.generate_normals()
	_slab_cache[seed_value] = st.commit()
	return _slab_cache[seed_value]

func terrace(parent: Node3D, title: String, base: Vector3, size: Vector3, layers: int) -> void:
	var materials := TerrainStyle.TERRACE_MATERIALS
	for level in layers:
		var taper := 1.0 - float(level) / layers * TerrainStyle.TERRACE_TAPER
		var mesh := slab_mesh(TerrainStyle.TERRACE_SLAB_SEED + level)
		var mat: Material = materials[level % materials.size()]
		var h := size.y / layers
		var slab := mesh_node(parent, title + "Layer%d" % level, mesh, base + Vector3(level * TerrainStyle.TERRACE_SLAB_OFFSET.x, level * h, 0), mat)
		slab.scale = Vector3(size.x * taper, h * TerrainStyle.TERRACE_LAYER_HEIGHT_SCALE, size.z * taper)
		# Individual upright fractures break up the large faces of each stratum.
		for j in TerrainStyle.TERRACE_FRACTURES:
			var a := j * TAU / float(TerrainStyle.TERRACE_FRACTURES)
			var p := base + Vector3(cos(a) * size.x * taper * TerrainStyle.TERRACE_FRACTURE_RADIUS, level * h + TerrainStyle.TERRACE_FRACTURE_INSET, sin(a) * size.z * taper * TerrainStyle.TERRACE_FRACTURE_RADIUS)
			var chip := mesh_node(parent, title + "Fracture%d_%d" % [level, j], mesh, p, mat)
			chip.scale = Vector3(size.x * TerrainStyle.TERRACE_FRACTURE_SCALE.x, h * rng.randf_range(TerrainStyle.TERRACE_FRACTURE_HEIGHT.x, TerrainStyle.TERRACE_FRACTURE_HEIGHT.y), size.z * TerrainStyle.TERRACE_FRACTURE_SCALE.y)
			chip.rotation.y = -a
		if level == 1 and size.y > TerrainStyle.TERRACE_MIN_SEAM_HEIGHT:
			var seam := mesh_node(parent, title + "OchreStratum", mesh, base + TerrainStyle.TERRACE_SEAM_OFFSET + Vector3(0, h, 0), TerrainStyle.SEAM_MATERIAL)
			seam.scale = Vector3(size.x * TerrainStyle.TERRACE_SEAM_SCALE.x, TerrainStyle.TERRACE_SEAM_HEIGHT, size.z * TerrainStyle.TERRACE_SEAM_SCALE.y)

func build_arch(parent: Node3D, base: Vector3) -> void:
	var rock := slab_mesh(TerrainStyle.ARCH_SLAB_SEED)
	for i in TerrainStyle.ARCH_BLOCKS:
		var a := float(i) / float(TerrainStyle.ARCH_BLOCKS - 1) * PI
		var p := base + Vector3(cos(a) * TerrainStyle.ARCH_RADIUS, sin(a) * TerrainStyle.ARCH_HEIGHT + TerrainStyle.ARCH_BASE_HEIGHT, 0)
		var block := mesh_node(parent, "MoonArchBlock%02d" % i, rock, p, TerrainStyle.ARCH_MATERIALS[0] if i % 3 else TerrainStyle.ARCH_MATERIALS[1])
		block.scale = TerrainStyle.ARCH_SCALE
		block.rotation.z = a - PI / 2

func inside_shelf(x: float, z: float, inset := 1.0) -> bool:
	return pow(absf(x) / (TerrainStyle.SHELF_RADIUS.x * inset), TerrainStyle.SHELF_POWER) + pow(absf(z - TerrainStyle.SHELF_CENTER.y) / (TerrainStyle.SHELF_RADIUS.y * inset), TerrainStyle.SHELF_POWER) < 1.0

func shelf_wall(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var levels := TerrainStyle.SHELF_WALL_LEVELS
	var colors := TerrainStyle.SHELF_WALL_COLORS
	for i in 3:
		var p := a.lerp(Vector3(a.x * TerrainStyle.SHELF_WALL_INSET, TerrainStyle.SHELF_WALL_DEPTH, a.z), levels[i])
		var q := b.lerp(Vector3(b.x * TerrainStyle.SHELF_WALL_INSET, TerrainStyle.SHELF_WALL_DEPTH, b.z), levels[i])
		var u := a.lerp(Vector3(a.x * TerrainStyle.SHELF_WALL_INSET, TerrainStyle.SHELF_WALL_DEPTH, a.z), levels[i + 1])
		var v := b.lerp(Vector3(b.x * TerrainStyle.SHELF_WALL_INSET, TerrainStyle.SHELF_WALL_DEPTH, b.z), levels[i + 1])
		var tint: Color = colors[i].lightened(rng.randf_range(0, TerrainStyle.SHELF_WALL_TINT))
		triangle(st, p, u, q, tint)
		triangle(st, q, u, v, tint)
