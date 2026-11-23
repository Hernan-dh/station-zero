extends "res://scripts/tools/stone_kit.gd"
## Bake C2 from concept_sheet_1 into an editable stone model.
## godot --headless --path . --script res://scripts/tools/build_portal_gate.gd

const ModelStyle = preload("res://scripts/model_style.gd")

var violet: Material = preload("res://resources/materials/portal_crystal.tres")

func _initialize() -> void:
	rng.seed = ModelStyle.PORTAL_SEED
	for color in ModelStyle.PORTAL_STONE_COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = ModelStyle.PORTAL_STONE_ROUGHNESS
		stone.append(mat)
	var model := group(null, "PortalGateModel")
	var fissure := StandardMaterial3D.new()
	fissure.albedo_color = ModelStyle.PORTAL_FISSURE_COLOR
	fissure.roughness = ModelStyle.PORTAL_FISSURE_ROUGHNESS
	# A low, irregular stone apron, with an open stairway into the aperture.
	rock(model, "Foundation", Vector3(0, .13, 0), Vector3(5.2, .36, 2.25), 2)
	for i in 3:
		var height := .18 * (3 - i)
		armor_box(model, "ThresholdStep%d" % i, Vector3(0, height * .5 + .05, .54 + i * .36), Vector3(1.95 + i * .14, height, .48), .07, stone[1])
		box(model, "WornStepEdge%d" % i, Vector3(0, height + .048, .74 + i * .36), Vector3(1.85 + i * .14, .025, .045), stone[3])
	var center := ModelStyle.PORTAL_CENTER
	for i in ModelStyle.PORTAL_RING_SEGMENTS:
		# The missing crown stone and raised left cap preserve the broken silhouette.
		if i == 4: continue
		var start := i * TAU / ModelStyle.PORTAL_RING_SEGMENTS + ModelStyle.PORTAL_RING_GAP
		var end := (i + 1) * TAU / ModelStyle.PORTAL_RING_SEGMENTS - ModelStyle.PORTAL_RING_GAP
		var outer := rng.randf_range(ModelStyle.PORTAL_RING_OUTER_MIN, ModelStyle.PORTAL_RING_OUTER_MAX)
		var inner := rng.randf_range(ModelStyle.PORTAL_RING_INNER_MIN, ModelStyle.PORTAL_RING_INNER_MAX)
		var outline := PackedVector2Array([
			Vector2(cos(start), sin(start)) * inner,
			Vector2(cos(end), sin(end)) * inner,
			Vector2(cos(end), sin(end)) * (outer - .12),
			Vector2(cos(lerpf(start, end, .64)), sin(lerpf(start, end, .64))) * (outer + .07),
			Vector2(cos(start), sin(start)) * outer])
		var offset := center + Vector3(0, 0, rng.randf_range(-.04, .04))
		if i == 5: offset += Vector3(-.06, .13, 0)
		var depth := rng.randf_range(ModelStyle.PORTAL_RING_DEPTH_MIN, ModelStyle.PORTAL_RING_DEPTH_MAX)
		stone_prism(model, "RingStone%02d" % i, outline, offset, depth, stone[i % stone.size()])
		# Narrow inner masonry extends through the ring, visible from either side.
		var mid := (start + end) * .5
		if i % 3 != 0:
			var cracks := group(model, "StoneFracture%02d" % i, offset + Vector3(0,0,depth*.5+.006))
			cracks.rotation.z = mid - PI * .5
			beam(cracks, "LowerSplit", Vector3(-.02,inner+.13,0), Vector3(.055,1.9,0), .016, fissure)
			beam(cracks, "UpperSplit", Vector3(.055,1.9,0), Vector3(-.04,outer-.16,0), .013, fissure)
			beam(cracks, "Fork", Vector3(.055,1.9,0), Vector3(.15,1.96,0), .01, fissure)
		for j in 2:
			var a := lerpf(start, end, float(j) * .5)
			var b := lerpf(start, end, float(j + 1) * .5) - .012
			stone_prism(model, "InnerLining%02d_%d" % [i,j], PackedVector2Array([
				Vector2(cos(a),sin(a)) * ModelStyle.PORTAL_LINING_INNER, Vector2(cos(b),sin(b)) * ModelStyle.PORTAL_LINING_INNER,
				Vector2(cos(b),sin(b)) * ModelStyle.PORTAL_LINING_OUTER, Vector2(cos(a),sin(a)) * ModelStyle.PORTAL_LINING_OUTER]), center + Vector3(0,0,ModelStyle.PORTAL_LINING_OFFSET), ModelStyle.PORTAL_LINING_DEPTH, stone[2])
		if i % 3 == 0:
			var p := center + Vector3(cos(mid), sin(mid), 0) * ModelStyle.PORTAL_RUNE_RADIUS + Vector3(0,0,ModelStyle.PORTAL_RUNE_DEPTH)
			var rune := group(model, "InlaidRune%02d" % i, p)
			rune.rotation.z = mid - PI * .5
			beam(rune, "Stem", Vector3(0,-.12,0), Vector3(0,.12,0), .024, violet)
			beam(rune, "Branch", Vector3(-.08,.03,0), Vector3(0,.12,0), .024, violet)
			beam(rune, "Foot", Vector3(0,-.1,0), Vector3(.07,-.04,0), .024, violet)
	# Jagged shards around the fracture; these are independent editable pieces.
	rock(model, "BrokenCrownShard", Vector3(.3,4.38,-.03), Vector3(.42,.45,.66), 1).rotation.z = .4
	rock(model, "OverhangingCap", Vector3(-.72,4.51,.02), Vector3(1.12,.25,.73), 3).rotation.z = .22
	for side in [-1, 1]:
		var anchor := group(model, "CrystalAnchorLeft" if side == -1 else "CrystalAnchorRight", Vector3(side * 1.91,.62,.44))
		rock(anchor, "StandingStone", Vector3.ZERO, Vector3(.91,1.34,.8), 1).rotation.z = side * -.13
		var socket := armor_box(anchor, "ObsidianSocket", Vector3(0,.13,.42), Vector3(.47,.59,.12), .19, stone[2])
		socket.rotation.z = PI * .25
		crystal(anchor, "VioletCrystal", Vector3(0,.16,.53), Vector3(.22,.39,.17), violet)
		crystal(anchor, "CrystalHeart", Vector3(0,.16,.64), Vector3(.09,.18,.05), preload("res://resources/materials/portal_core.tres"))
		rock(model, "OuterSpire%d" % side, Vector3(side*2.55,.61,-.02), Vector3(.37,1.16,.53), 2).rotation.z = side * -.2
		for i in 7:
			rock(model, "Rubble%d_%d" % [side,i], Vector3(side*rng.randf_range(1.15,2.7),rng.randf_range(.12,.23),rng.randf_range(.3,1.12)), Vector3(rng.randf_range(.25,.65),rng.randf_range(.22,.47),rng.randf_range(.3,.6)), i % stone.size())
	save_model(model, "portal_gate")
	if not commit():
		return
	print("Baked Portal Gate: fractured stone ring, crystal anchors, threshold")
	quit()
