extends "res://scripts/tools/build_outpost.gd"
## Bake C2 from concept_sheet_1 into an editable stone model.
## godot --headless --path . --script res://scripts/tools/build_portal_gate.gd

var stone: Array[Material] = []
var violet: Material = preload("res://resources/materials/portal_crystal.tres")
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 207
	for color in ["766d68", "8b7c6b", "625c61", "9b8871", "6d6664"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = .96
		stone.append(mat)
	var model := group(null, "PortalGateModel")
	var fissure := StandardMaterial3D.new()
	fissure.albedo_color = Color("38303e")
	fissure.roughness = 1.0
	# A low, irregular stone apron, with an open stairway into the aperture.
	rock(model, "Foundation", Vector3(0, .13, 0), Vector3(5.2, .36, 2.25), 2)
	for i in 3:
		var height := .18 * (3 - i)
		armor_box(model, "ThresholdStep%d" % i, Vector3(0, height * .5 + .05, .54 + i * .36), Vector3(1.95 + i * .14, height, .48), .07, stone[1])
		box(model, "WornStepEdge%d" % i, Vector3(0, height + .048, .74 + i * .36), Vector3(1.85 + i * .14, .025, .045), stone[3])
	var center := Vector3(0, 2.3, 0)
	for i in 17:
		# The missing crown stone and raised left cap preserve the broken silhouette.
		if i == 4: continue
		var start := i * TAU / 17.0 + .015
		var end := (i + 1) * TAU / 17.0 - .015
		var outer := rng.randf_range(2.18, 2.42)
		var inner := rng.randf_range(1.61, 1.68)
		var outline := PackedVector2Array([
			Vector2(cos(start), sin(start)) * inner,
			Vector2(cos(end), sin(end)) * inner,
			Vector2(cos(end), sin(end)) * (outer - .12),
			Vector2(cos(lerpf(start, end, .64)), sin(lerpf(start, end, .64))) * (outer + .07),
			Vector2(cos(start), sin(start)) * outer])
		var offset := center + Vector3(0, 0, rng.randf_range(-.04, .04))
		if i == 5: offset += Vector3(-.06, .13, 0)
		var depth := rng.randf_range(.65, .86)
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
				Vector2(cos(a),sin(a)) * 1.59, Vector2(cos(b),sin(b)) * 1.59,
				Vector2(cos(b),sin(b)) * 1.77, Vector2(cos(a),sin(a)) * 1.77]), center + Vector3(0,0,-.17), .89, stone[2])
		if i % 3 == 0:
			var p := center + Vector3(cos(mid), sin(mid), 0) * 1.93 + Vector3(0,0,.45)
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
	print("Baked Portal Gate: fractured stone ring, crystal anchors, threshold")
	quit()

func stone_prism(p: Node3D, title: String, outline: PackedVector2Array, pos: Vector3, depth: float, mat: Material) -> MeshInstance3D:
	var middle := Vector2.ZERO
	for point in outline: middle += point
	middle /= outline.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1) % outline.size()]
		var inset_a := a.lerp(middle, .16)
		var inset_b := b.lerp(middle, .16)
		var fa := Vector3(inset_a.x,inset_a.y,depth*.5)
		var fb := Vector3(inset_b.x,inset_b.y,depth*.5)
		var ea := Vector3(a.x,a.y,depth*.5-.09)
		var eb := Vector3(b.x,b.y,depth*.5-.09)
		var ba := Vector3(a.x,a.y,-depth*.5)
		var bb := Vector3(b.x,b.y,-depth*.5)
		triangle(st, Vector3(middle.x,middle.y,depth*.5), fa, fb)
		triangle(st, fa, ea, eb)
		triangle(st, fa, eb, fb)
		triangle(st, ea, ba, bb)
		triangle(st, ea, bb, eb)
		triangle(st, Vector3(middle.x,middle.y,-depth*.5), bb, ba)
	st.generate_normals()
	return mesh(p,title,st.commit(),pos,mat)

func rock(p: Node3D, title: String, pos: Vector3, size: Vector3, variant: int) -> MeshInstance3D:
	var outline := PackedVector2Array()
	for i in 7:
		var a := -i * TAU/7.0
		outline.append(Vector2(cos(a)*size.x, sin(a)*size.y) * rng.randf_range(.44,.57))
	return stone_prism(p,title,outline,pos,size.z,stone[variant])

func crystal(p: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := i * TAU / 5.0
		var b := (i+1) * TAU / 5.0
		var va := Vector3(cos(a)*size.x,0,sin(a)*size.z)
		var vb := Vector3(cos(b)*size.x,0,sin(b)*size.z)
		triangle(st, Vector3(0,size.y,0), va, vb)
		triangle(st, Vector3(0,-size.y*.8,0), vb, va)
	st.generate_normals()
	mesh(p,title,st.commit(),pos,mat)
