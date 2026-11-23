extends RefCounted
## Canonical route and gate layout shared by the content generators. Equipment
## and defense-site placements come from the saved main scene, so there is one
## editable source for outpost object transforms.

const Metadata = preload("res://scripts/metadata.gd")
const OUTPOST_SCENE := "res://scenes/outpost.tscn"
const CLEARING_NODES := ["DefenseSite01", "DefenseSite02", "PortalGate"]
const SITE_NODES := ["DefenseSite01", "DefenseSite02"]
const CLEARING_EQUIPMENT_NODES := ["CommunicationsArray", "NavigationBeacon"]
const EQUIPMENT_NODES := ["NavigationBeacon", "CommunicationsArray", "ArcLauncher", "ShieldGenerator", "PortalGate", "AetherRelay", "SunfallArray"]

const WAYPOINTS := [Vector3(-7, 0.14, 29), Vector3(-5, 0.14, 24), Vector3(3, 0.14, 20), Vector3(5, 0.14, 14), Vector3(0, 0.14, 8), Vector3(0, 0.14, 2.65)]
const TRAVEL_LENGTH := 42.0
const CORE := Vector3(0, 0, -.65)
const ENTRANCES := {"Left": -PI / 2, "Right": PI / 2, "Rear": PI}
const GATE_OUTER := {"Left": 7.85, "Right": 7.85, "Rear": 6.45}
const SITE_NUMBER_PREFIX := {"Rear": "B", "Left": "L", "Right": "R"}
const DEFENSE_MOUNT_POSITION := Vector3(0, .26, 0)
const SITE_BEDROCK_OFFSET := Vector3(0, -.3, 0)
const SITE_BEDROCK_SIZE := Vector3(2.1, .75, 2.0)
const SITE_BEDROCK_LAYERS := 2
const SITE_EXCAVATION_OFFSET := Vector3(0, .31, 0)

const FLANK_ROUTES := {
	"Rear": [Vector3(0, .14, -16), Vector3(0, .14, -11), Vector3(0, .14, -7.75)],
	"Left": [Vector3(-21, .14, 12), Vector3(-17, .14, 10), Vector3(-16, .14, 5), Vector3(-13, .14, 1), Vector3(-8.5, .14, -.65)],
	"Right": [Vector3(21, .14, 17), Vector3(20, .14, 12), Vector3(19, .14, 6), Vector3(15, .14, 1), Vector3(11, .14, -.65), Vector3(8.5, .14, -.65)],
}
const FLANK_SITE_OCCUPANTS := {"Rear": "", "Left": "AetherRelay", "Right": "SunfallArray"}
const FLANK_OUTWARD := {"Rear": Vector3(0, 0, -1), "Left": Vector3(-.94, 0, .34), "Right": Vector3(.8, 0, .6)}

## Reads the placed equipment, defense sites and their presentation values from
## the main scene. The terrain generator then has no second copy of those
## transforms to drift out of sync.
static func outpost_layout() -> Dictionary:
	var result := {
		"valid": false,
		"clearings": [],
		"sites": [],
		"equipment": {},
		"defense_site_scale": Vector3.ONE,
		"defense_site_y": 0.0,
		"site_number_position": Vector3.ZERO,
		"site_number_rotation": Vector3.ZERO,
		"site_number_font_size": 0,
		"site_number_pixel_size": 0.0,
	}
	var packed := load(OUTPOST_SCENE) as PackedScene
	if packed == null:
		push_error("Could not load %s." % OUTPOST_SCENE)
		return result
	var root := packed.instantiate()
	for node_name in CLEARING_NODES:
		var node := root.get_node_or_null(node_name) as Node3D
		if node == null:
			push_error("Layout node missing from %s: %s." % [OUTPOST_SCENE, node_name])
			root.free()
			return result
		result.clearings.append(Vector3(node.position.x, 0, node.position.z))
	for node_name in SITE_NODES:
		var node := root.get_node_or_null(node_name) as Node3D
		if node == null:
			push_error("Layout node missing from %s: %s." % [OUTPOST_SCENE, node_name])
			root.free()
			return result
		result.sites.append(Vector3(node.position.x, 0, node.position.z))
	for node_name in EQUIPMENT_NODES:
		var node := root.get_node_or_null(node_name) as Node3D
		if node == null:
			push_error("Layout node missing from %s: %s." % [OUTPOST_SCENE, node_name])
			root.free()
			return result
		result.equipment[node_name] = {
			"position": Vector3(node.position.x, 0, node.position.z),
			"display_name": Metadata.display_name(node),
		}
	var site := root.get_node_or_null("DefenseSite01") as Node3D
	if site == null:
		push_error("Layout node missing from %s: DefenseSite01." % OUTPOST_SCENE)
		root.free()
		return result
	result.defense_site_scale = site.scale
	result.defense_site_y = site.position.y
	var label := site.get_node_or_null("SiteNumber") as Label3D
	if label == null:
		push_error("SiteNumber missing from DefenseSite01 in %s." % OUTPOST_SCENE)
		root.free()
		return result
	result.site_number_position = label.position
	result.site_number_rotation = label.rotation
	result.site_number_font_size = label.font_size
	result.site_number_pixel_size = label.pixel_size
	result.valid = true
	root.free()
	return result
