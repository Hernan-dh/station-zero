extends "res://scripts/tools/build_outpost.gd"
## Bake the three new airlocks and open perimeter gates. Originals stay reusable.
## godot --headless --path . --script res://scripts/tools/build_habitat_entrances.gd

const CORE := Vector3(0, 0, -.65)
const ENTRANCES := {"Left": -PI / 2, "Right": PI / 2, "Rear": PI}

func _initialize() -> void:
	build_access_habitat()
	build_access_perimeter()
	quit()

func build_access_habitat() -> void:
	var habitat := load("res://scenes/models/habitat.tscn").instantiate() as Node3D
	# Move the utility wings forward to free the two lateral airlocks.
	for suffix in ["", "2"]:
		habitat.get_node("ServiceWing" + suffix).position.z = 2.0
		habitat.get_node("TransferConduit" + suffix).position.z = 1.05
	for title in ENTRANCES:
		var entrance := group(habitat, title + "Entrance", CORE)
		entrance.rotation.y = ENTRANCES[title]
		entrance.set_meta("display_name", title + " Habitat Airlock")
		entrance.add_to_group("habitat_entrances", true)
		for child in habitat.get_children():
			if str(child.name).begins_with("Airlock") or str(child.name).begins_with("Door") or child.name in ["LintelLight", "Stairs"]:
				var copy := child.duplicate() as Node3D
				copy.position -= CORE
				entrance.add_child(copy)
		var endpoint := Marker3D.new()
		endpoint.name = "Arrival"
		endpoint.position = Vector3(0, .71, 3.51)
		entrance.add_child(endpoint)
		var label := Label3D.new()
		label.name = "AirlockDesignation"
		label.text = title.to_upper()
		label.position = Vector3(0, 2.25, 3.25)
		label.pixel_size = .004
		label.font_size = 40
		label.outline_size = 0
		entrance.add_child(label)
	# Remove the small hull ribs hidden behind the new door assemblies.
	for panel in ["HullPanel03", "HullPanel06", "HullPanel09"]:
		habitat.get_node(panel).free()
	save_model(habitat, "habitat_access")

func connect_wall(wall: Node3D, a: Vector3, b: Vector3) -> void:
	wall.position = (a + b) * .5
	wall.rotation.y = atan2(-(b - a).z, (b - a).x)
	wall.scale.x = a.distance_to(b) / 2.6

func build_access_perimeter() -> void:
	var perimeter := load("res://scenes/models/outpost_perimeter.tscn").instantiate() as Node3D
	for wall in ["Wall03", "Wall07", "Wall11"]:
		perimeter.get_node(wall).free()
	# Retain each gate's original bastions and reconnect neighboring wall panels.
	var moves := {"Bastion4": Vector3(6.96, .12, 1.55), "Bastion5": Vector3(6.96, .12, -2.85), "Bastion8": Vector3(2.2, .12, -5.69), "Bastion9": Vector3(-2.2, .12, -5.69), "Bastion12": Vector3(-6.96, .12, -2.85), "Bastion13": Vector3(-6.96, .12, 1.55)}
	for title in moves:
		perimeter.get_node(title).position = moves[title]
	for connection in [["Wall02", "Bastion3", "Bastion4"], ["Wall04", "Bastion5", "Bastion6"], ["Wall06", "Bastion7", "Bastion8"], ["Wall08", "Bastion9", "Bastion10"], ["Wall10", "Bastion11", "Bastion12"], ["Wall12", "Bastion13", "Bastion14"]]:
		connect_wall(perimeter.get_node(connection[0]), perimeter.get_node(connection[1]).position, perimeter.get_node(connection[2]).position)
	for title in ENTRANCES:
		var gate := group(perimeter, title + "Gate", CORE)
		gate.rotation.y = ENTRANCES[title]
		gate.set_meta("display_name", title + " Entrance Walkway")
		var outer := 7.85 if title != "Rear" else 6.45
		# Narrow walkways join the original-size airlock stairs inside the wall.
		box(gate, "Walkway", Vector3(0, .17, (4.6 + outer) * .5), Vector3(1.85, .18, outer - 4.6), deck)
		for side in [-1, 1]:
			beam(gate, "WalkwayGuide", Vector3(side * .88, .275, 4.65), Vector3(side * .88, .275, outer), .045, cyan)
		# A broad, low ramp meets the dust road just outside the perimeter.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-1.65, .14, outer + .65)
		var b := Vector3(1.65, .14, outer + .65)
		var c := Vector3(-.925, .26, outer)
		var d := Vector3(.925, .26, outer)
		triangle(st, a, c, b)
		triangle(st, b, c, d)
		st.generate_normals()
		mesh(gate, "EntryRamp", st.commit(), Vector3.ZERO, deck)
		var marker := Marker3D.new()
		marker.name = "GateCenter"
		marker.position = Vector3(0, .26, outer - .9)
		gate.add_child(marker)
	save_model(perimeter, "outpost_perimeter_access")
