extends "res://scripts/tools/outpost_kit.gd"
## Bake the three new airlocks and open perimeter gates.
## godot --headless --path . --script res://scripts/tools/build_habitat_entrances.gd
## Run build_outpost.gd first: the variants reuse its banner, annex and wall models.

const Layout = preload("res://scripts/world_layout.gd")
const ModelStyle = preload("res://scripts/model_style.gd")
const CORE := Layout.CORE
const ENTRANCES := Layout.ENTRANCES
var _ramp_meshes := {}

func _initialize() -> void:
	build_access_habitat()
	build_access_perimeter()
	quit()

func build_access_habitat() -> void:
	var habitat := create_habitat()
	# Move the utility wings forward to free the two lateral airlocks.
	for suffix in ["", "2"]:
		habitat.get_node("ServiceWing" + suffix).position.z = 2.0
		habitat.get_node("TransferConduit" + suffix).position.z = 1.05
	for title in ENTRANCES:
		var entrance := group(habitat, title + "Entrance", CORE)
		entrance.rotation.y = ENTRANCES[title]
		Metadata.set_display_name(entrance, title + " Habitat Airlock")
		entrance.add_to_group("habitat_entrances", true)
		for child in habitat.get_children():
			if str(child.name).begins_with("Airlock") or str(child.name).begins_with("Door") or child.name in ["LintelLight", "Stairs"]:
				var copy := child.duplicate() as Node3D
				copy.position -= CORE
				entrance.add_child(copy)
		var endpoint := Marker3D.new()
		endpoint.name = "Arrival"
		endpoint.position = ModelStyle.ENTRANCE_ARRIVAL_POSITION
		entrance.add_child(endpoint)
		var label := Label3D.new()
		label.name = "AirlockDesignation"
		label.text = title.to_upper()
		label.position = ModelStyle.ENTRANCE_LABEL_POSITION
		label.pixel_size = ModelStyle.ENTRANCE_LABEL_PIXEL_SIZE
		label.font_size = ModelStyle.ENTRANCE_LABEL_FONT_SIZE
		label.outline_size = 0
		entrance.add_child(label)
	# Remove the small hull ribs hidden behind the new door assemblies.
	for panel in ["HullPanel03", "HullPanel06", "HullPanel09"]:
		habitat.get_node(panel).free()
	save_model(habitat, "habitat_access")

func connect_wall(wall: Node3D, a: Vector3, b: Vector3) -> void:
	wall.position = (a + b) * .5
	wall.rotation.y = atan2(-(b - a).z, (b - a).x)
	wall.scale.x = a.distance_to(b) / ModelStyle.WALL_PANEL_LENGTH

func build_access_perimeter() -> void:
	var perimeter := create_perimeter()
	for wall in ["Wall03", "Wall07", "Wall11"]:
		perimeter.get_node(wall).free()
	# Retain each gate's original bastions and reconnect neighboring wall panels.
	var moves := ModelStyle.GATE_BASTION_MOVES
	for title in moves:
		perimeter.get_node(title).position = moves[title]
	for connection in [["Wall02", "Bastion3", "Bastion4"], ["Wall04", "Bastion5", "Bastion6"], ["Wall06", "Bastion7", "Bastion8"], ["Wall08", "Bastion9", "Bastion10"], ["Wall10", "Bastion11", "Bastion12"], ["Wall12", "Bastion13", "Bastion14"]]:
		connect_wall(perimeter.get_node(connection[0]), perimeter.get_node(connection[1]).position, perimeter.get_node(connection[2]).position)
	for title in ENTRANCES:
		var gate := group(perimeter, title + "Gate", CORE)
		gate.rotation.y = ENTRANCES[title]
		Metadata.set_display_name(gate, title + " Entrance Walkway")
		var outer: float = Layout.GATE_OUTER[title]
		# Narrow walkways join the original-size airlock stairs inside the wall.
		box(gate, "Walkway", Vector3(0, ModelStyle.GATE_WALKWAY_Y, (ModelStyle.GATE_WALKWAY_INNER + outer) * .5), Vector3(ModelStyle.GATE_WALKWAY_WIDTH, ModelStyle.GATE_WALKWAY_HEIGHT, outer - ModelStyle.GATE_WALKWAY_INNER), deck)
		for side in [-1, 1]:
			beam(gate, "WalkwayGuide", Vector3(side * ModelStyle.GATE_GUIDE_OFFSET, ModelStyle.GATE_GUIDE_Y, ModelStyle.GATE_WALKWAY_INNER + .05), Vector3(side * ModelStyle.GATE_GUIDE_OFFSET, ModelStyle.GATE_GUIDE_Y, outer), ModelStyle.GATE_GUIDE_WIDTH, cyan)
		# A broad, low ramp meets the dust road just outside the perimeter.
		if not _ramp_meshes.has(outer):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var a := Vector3(-ModelStyle.GATE_RAMP_HALF_WIDTH, ModelStyle.GATE_RAMP_Y_OUTER, outer + ModelStyle.GATE_RAMP_OUTER_OFFSET)
			var b := Vector3(ModelStyle.GATE_RAMP_HALF_WIDTH, ModelStyle.GATE_RAMP_Y_OUTER, outer + ModelStyle.GATE_RAMP_OUTER_OFFSET)
			var c := Vector3(-ModelStyle.GATE_RAMP_INNER_HALF_WIDTH, ModelStyle.GATE_RAMP_Y_INNER, outer)
			var d := Vector3(ModelStyle.GATE_RAMP_INNER_HALF_WIDTH, ModelStyle.GATE_RAMP_Y_INNER, outer)
			triangle(st, a, c, b)
			triangle(st, b, c, d)
			st.generate_normals()
			_ramp_meshes[outer] = st.commit()
		mesh(gate, "EntryRamp", _ramp_meshes[outer], Vector3.ZERO, deck)
		var marker := Marker3D.new()
		marker.name = "GateCenter"
		marker.position = Vector3(ModelStyle.GATE_MARKER_POSITION.x, ModelStyle.GATE_MARKER_POSITION.y, outer + ModelStyle.GATE_MARKER_POSITION.z)
		gate.add_child(marker)
	save_model(perimeter, "outpost_perimeter_access")
