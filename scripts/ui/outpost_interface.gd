extends CanvasLayer

const InterfaceStyle = preload("res://scripts/interface_style.gd")
const BeaconControls = preload("res://scripts/ui/beacon_controls.gd")
const ArrayControls = preload("res://scripts/ui/array_controls.gd")
const SelectionUI = preload("res://scripts/selection_ui.gd")
const Beacon = preload("res://scripts/components/navigation_beacon.gd")
const CommunicationsArray = preload("res://scripts/components/communications_array.gd")
const ArcLauncher = preload("res://scripts/components/arc_launcher.gd")
const ArcLauncherControls = preload("res://scripts/ui/arc_launcher_controls.gd")
const ShieldGenerator = preload("res://scripts/components/shield_generator.gd")
const ShieldGeneratorControls = preload("res://scripts/ui/shield_generator_controls.gd")
const PortalGate = preload("res://scripts/components/portal_gate.gd")
const PortalGateControls = preload("res://scripts/ui/portal_gate_controls.gd")
const AetherRelay = preload("res://scripts/components/aether_relay.gd")
const AetherRelayControls = preload("res://scripts/ui/aether_relay_controls.gd")
const SunfallArray = preload("res://scripts/components/sunfall_array.gd")
const SunfallArrayControls = preload("res://scripts/ui/sunfall_array_controls.gd")
const IVORY = InterfaceStyle.IVORY
const TEAL = InterfaceStyle.TEAL

@export var selection_ui: SelectionUI
@export var beacon: Beacon
@export var communications_array: CommunicationsArray
@export var arc_launcher: ArcLauncher
@export var shield_generator: ShieldGenerator
@export var portal_gate: PortalGate
@export var aether_relay: AetherRelay
@export var sunfall_array: SunfallArray

func _ready() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	InterfaceStyle.label(ui, "S T A T I O N   Z E R O", InterfaceStyle.FONT_TITLE, IVORY, InterfaceStyle.HEADER_POSITION)
	InterfaceStyle.label(ui, "SELENE REACH   /   CRYSTAL HIGHLANDS", InterfaceStyle.FONT_BODY, InterfaceStyle.MUTED, InterfaceStyle.SUBTITLE_POSITION)
	var accent := ColorRect.new()
	accent.position = InterfaceStyle.ACCENT_POSITION
	accent.size = InterfaceStyle.ACCENT_SIZE
	accent.color = InterfaceStyle.ACCENT
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(accent)
	var beacon_controls := BeaconControls.new()
	beacon_controls.bind(beacon)
	selection_ui.add_object_controls(beacon, beacon_controls, InterfaceStyle.PANEL_TOP_BEACON)
	var array_controls := ArrayControls.new()
	array_controls.bind(communications_array)
	selection_ui.add_object_controls(communications_array, array_controls, InterfaceStyle.PANEL_TOP_ARRAY)
	var arc_controls := ArcLauncherControls.new()
	arc_controls.bind(arc_launcher)
	selection_ui.add_object_controls(arc_launcher, arc_controls, InterfaceStyle.PANEL_TOP_ARC)
	var shield_controls := ShieldGeneratorControls.new()
	shield_controls.bind(shield_generator)
	selection_ui.add_object_controls(shield_generator, shield_controls, InterfaceStyle.PANEL_TOP_SHIELD)
	var portal_controls := PortalGateControls.new()
	portal_controls.bind(portal_gate)
	selection_ui.add_object_controls(portal_gate, portal_controls, InterfaceStyle.PANEL_TOP_PORTAL)
	var relay_controls := AetherRelayControls.new()
	relay_controls.bind(aether_relay)
	selection_ui.add_object_controls(aether_relay, relay_controls, InterfaceStyle.PANEL_TOP_RELAY)
	var sunfall_controls := SunfallArrayControls.new()
	sunfall_controls.bind(sunfall_array)
	selection_ui.add_object_controls(sunfall_array, sunfall_controls, InterfaceStyle.PANEL_TOP_SUNFALL)
	var footer := Control.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.position.y = InterfaceStyle.FOOTER_Y
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(footer)
	InterfaceStyle.label(footer, "●  OUTPOST ONLINE", InterfaceStyle.FONT_VALUE, TEAL, Vector2(InterfaceStyle.FOOTER_LEFT, InterfaceStyle.FOOTER_TEXT_Y))
	InterfaceStyle.label(footer, "SECTOR 00   /   MOONPASS DEFENSE", InterfaceStyle.FONT_BODY, InterfaceStyle.MUTED, Vector2(InterfaceStyle.FOOTER_LEFT, InterfaceStyle.FOOTER_SUBTITLE_Y))

