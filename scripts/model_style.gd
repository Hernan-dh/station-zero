extends RefCounted
## Shared tuning for the baked equipment and entrance models. Generators keep
## geometry construction; palette, seed and placement adjustments live here.

const AETHER_SEED := 441
const AETHER_STONE_COLORS := [Color("686771"), Color("a39a87"), Color("4f535f"), Color("c0b29a"), Color("7c7f83")]
const AETHER_BLUE_COLOR := Color("22c9df")
const AETHER_BLUE_EMISSION := Color("19bded")
const AETHER_BLUE_ENERGY := 1.3
const AETHER_GOLD_COLOR := Color("ffd795")
const AETHER_GOLD_EMISSION := Color("ffc574")
const AETHER_GOLD_ENERGY := 1.6

const PORTAL_SEED := 207
const PORTAL_STONE_COLORS := [Color("766d68"), Color("8b7c6b"), Color("625c61"), Color("9b8871"), Color("6d6664")]
const PORTAL_STONE_ROUGHNESS := .96
const PORTAL_FISSURE_COLOR := Color("38303e")
const PORTAL_FISSURE_ROUGHNESS := 1.0
const PORTAL_CENTER := Vector3(0, 2.3, 0)
const PORTAL_RING_SEGMENTS := 17
const PORTAL_RING_GAP := .015
const PORTAL_RING_INNER_MIN := 1.61
const PORTAL_RING_INNER_MAX := 1.68
const PORTAL_RING_OUTER_MIN := 2.18
const PORTAL_RING_OUTER_MAX := 2.42
const PORTAL_RING_DEPTH_MIN := .65
const PORTAL_RING_DEPTH_MAX := .86
const PORTAL_LINING_INNER := 1.59
const PORTAL_LINING_OUTER := 1.77
const PORTAL_LINING_DEPTH := .89
const PORTAL_LINING_OFFSET := -.17
const PORTAL_RUNE_RADIUS := 1.93
const PORTAL_RUNE_DEPTH := .45

const SHIELD_FIELD_SUBDIVISIONS := 2
const SHIELD_FIELD_RADIUS := 1.0
const SHIELD_FIELD_CLIP_Y := 0.0

const SUNFALL_GOLD_COLOR := Color("eeb448")
const SUNFALL_GOLD_METALLIC := .55
const SUNFALL_GOLD_ROUGHNESS := .4
const SUNFALL_CELL_COLOR := Color("e99a29")
const SUNFALL_CELL_EMISSION := Color("be6512")
const SUNFALL_CELL_ENERGY := .35
const SUNFALL_GLOW_COLOR := Color("ffe8a5")
const SUNFALL_GLOW_EMISSION := Color("ffbf46")
const SUNFALL_GLOW_ENERGY := 2.0
const SUNFALL_BANNER_COLOR := Color("a83c34")
const SUNFALL_BANNER_POSITION := Vector3(.74, 1.12, -.13)
const SUNFALL_BANNER_SCALE := Vector3(.7, 1.02, .7)
const SUNFALL_CORE_POSITION := Vector3(0, 4.16, 0)
const SUNFALL_CORE_SIZE := Vector3(.22, .47, .22)
const SUNFALL_UPPER_HALO_POSITION := Vector3(0, 5.18, 0)
const SUNFALL_LOWER_HALO_POSITION := Vector3(0, 4.08, 0)
const SUNFALL_LOWER_HALO_ROLL := .12

const ENTRANCE_ARRIVAL_POSITION := Vector3(0, .71, 3.51)
const ENTRANCE_LABEL_POSITION := Vector3(0, 2.25, 3.25)
const ENTRANCE_LABEL_PIXEL_SIZE := .004
const ENTRANCE_LABEL_FONT_SIZE := 40

const WALL_PANEL_LENGTH := 2.6
const GATE_BASTION_MOVES := {
	"Bastion4": Vector3(6.96, .12, 1.55),
	"Bastion5": Vector3(6.96, .12, -2.85),
	"Bastion8": Vector3(2.2, .12, -5.69),
	"Bastion9": Vector3(-2.2, .12, -5.69),
	"Bastion12": Vector3(-6.96, .12, -2.85),
	"Bastion13": Vector3(-6.96, .12, 1.55),
}
const GATE_WALKWAY_INNER := 4.6
const GATE_WALKWAY_Y := .17
const GATE_WALKWAY_WIDTH := 1.85
const GATE_WALKWAY_HEIGHT := .18
const GATE_GUIDE_OFFSET := .88
const GATE_GUIDE_Y := .275
const GATE_GUIDE_WIDTH := .045
const GATE_RAMP_HALF_WIDTH := 1.65
const GATE_RAMP_INNER_HALF_WIDTH := .925
const GATE_RAMP_OUTER_OFFSET := .65
const GATE_RAMP_Y_OUTER := .14
const GATE_RAMP_Y_INNER := .26
const GATE_MARKER_POSITION := Vector3(0, .26, -.9)
