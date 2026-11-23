extends "res://scripts/tools/stone_kit.gd"
## Editable geometry from the Aether Relay in concept_sheet_4.png.

const ModelStyle = preload("res://scripts/model_style.gd")

func _initialize() -> void:
	rng.seed = ModelStyle.AETHER_SEED
	for color in ModelStyle.AETHER_STONE_COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .93
		stone.append(mat)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = ModelStyle.AETHER_BLUE_COLOR
	blue.emission_enabled = true
	blue.emission = ModelStyle.AETHER_BLUE_EMISSION
	blue.emission_energy_multiplier = ModelStyle.AETHER_BLUE_ENERGY
	var gold := StandardMaterial3D.new()
	gold.albedo_color = ModelStyle.AETHER_GOLD_COLOR
	gold.emission_enabled = true
	gold.emission = ModelStyle.AETHER_GOLD_EMISSION
	gold.emission_energy_multiplier = ModelStyle.AETHER_GOLD_ENERGY
	var gem := ShaderMaterial.new()
	gem.shader = load("res://resources/shaders/aether_crystal.gdshader")
	var model := group(null, "AetherRelayModel")
	rock(model, "BrokenFoundation", Vector3(0,.16,0), Vector3(5.3,.4,4.2), 2)
	for i in 10:
		var angle := i * TAU / 10.0
		var plinth := group(model, "RadialMasonry%d" % i, Vector3(sin(angle)*1.28,.34,cos(angle)*1.28))
		plinth.rotation.y = angle
		armor_box(plinth, "Stone", Vector3.ZERO, Vector3(.8,.48,.7), .1, stone[i%5])
		box(plinth,"CyanSeam",Vector3(0,.245,0),Vector3(.06,.025,.59),blue)
	cylinder(model,"PedestalFoot",Vector3(0,.49,0),.91,1.13,.3,stone[2],10)
	cylinder(model,"PedestalDrum",Vector3(0,.77,0),.68,.89,.37,stone[1],10)
	ring(model,"SocketInlay",Vector3(0,.98,0),.69,.045,blue)
	cylinder(model,"Crown",Vector3(0,1.03,0),.9,.65,.18,stone[3],10)
	cylinder(model,"SuspensionWell",Vector3(0,1.13,0),.64,.64,.04,dark,10)
	for side in [-1,1]:
		var pillar := group(model,"RuinPillar%d" % side,Vector3(side*1.92,0,-.6))
		pillar.rotation.z = side * -.065
		rock(pillar,"Foot",Vector3(0,.26,0),Vector3(.98,.5,.95),1)
		armor_box(pillar,"Upright",Vector3(0,1.05,0),Vector3(.44,1.7,.5),.07,stone[1])
		armor_box(pillar,"BrokenCapital",Vector3(0,1.99,0),Vector3(.91,.38,.67),.07,stone[4])
		box(pillar,"AncientInlay",Vector3(0,1.28,.258),Vector3(.055,.82,.018),blue)
		for j in 3:
			box(pillar,"Glyph%d" % j,Vector3(.07,1.05+j*.19,.27),Vector3(.16,.035,.025),blue)
		if side == -1:
			var banner := instance(pillar,"outpost_banner","FadedBanner",Vector3(0,1.8,.32))
			banner.scale = Vector3(.43,.43,.43)
	for i in 15:
		var angle := rng.randf()*TAU
		rock(model,"ScatteredRubble%02d" % i,Vector3(sin(angle)*rng.randf_range(1.8,2.6),.18,cos(angle)*rng.randf_range(1.5,2.1)),Vector3(rng.randf_range(.25,.65),rng.randf_range(.2,.5),rng.randf_range(.3,.65)),i%5)
	var floating := group(model,"SuspendedCrystal",Vector3(0,3.1,0))
	floating.set_meta(Metadata.MERGE_PIVOT, true)
	floating.set_meta(Metadata.PICKING_MOVING, true)
	crystal(floating,"Obelisk",Vector3.ZERO,Vector3(.52,1.64,.43),gem)
	# Fine luminous fracture lines follow the long facets.
	beam(floating,"FractureA",Vector3(-.12,1.18,.13),Vector3(.14,.45,.34),.018,blue)
	beam(floating,"FractureB",Vector3(.14,.45,.34),Vector3(.04,-.45,.29),.018,blue)
	beam(floating,"FractureC",Vector3(.04,-.45,.29),Vector3(-.1,-1.12,.14),.016,blue)
	for i in 3:
		var angle := i*TAU/3.0
		var plate := armor_box(floating,"StoneClasp%d" % i,Vector3(sin(angle)*.41,-.65,cos(angle)*.37),Vector3(.28,.53,.17),.07,stone[2])
		plate.rotation = Vector3(.22,angle,.12)
	var orbit := group(model,"GoldenOrbit",Vector3(0,3.08,0))
	orbit.set_meta(Metadata.MERGE_PIVOT, true)
	orbit.set_meta(Metadata.PICKING_MOVING, true)
	orbit.rotation = Vector3(.19,0,-.23)
	ring(orbit,"OrbitFilament",Vector3.ZERO,1.89,.018,gold)
	ring(orbit,"InnerFilament",Vector3(0,.055,0),1.83,.008,gold)
	for i in 4:
		var angle := i*TAU/4.0
		crystal(orbit,"OrbitStar%d" % i,Vector3(sin(angle)*1.89,0,cos(angle)*1.89),Vector3(.035,.15,.035),gold)
	var shards := group(model,"SatelliteShards",Vector3(0,3.1,0))
	shards.set_meta(Metadata.MERGE_PIVOT, true)
	shards.set_meta(Metadata.PICKING_MOVING, true)
	for i in 7:
		var angle := i*TAU/7.0
		var shard := group(shards,"Shard%d" % i,Vector3(sin(angle)*1.27, sin(angle*2.0)*.98,cos(angle)*1.14))
		shard.rotation = Vector3(.12,angle,.23)
		crystal(shard,"Gem",Vector3.ZERO,Vector3(.13,.33,.12),gem)
		crystal(shard,"Spark",Vector3(.23,.34,0),Vector3(.022,.08,.022),blue)
	save_model(model,"aether_relay")
	print("Baked Aether Relay: obelisk, orbit, satellites and ruined plinth")
	quit()
