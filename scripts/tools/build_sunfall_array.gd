extends "res://scripts/tools/build_portal_gate.gd"
## Bake the Sunfall Array from concept_sheet_4 into editable scene geometry.

func _initialize() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("eeb448")
	gold.metallic = .55
	gold.roughness = .4
	var cell := StandardMaterial3D.new()
	cell.albedo_color = Color("e99a29")
	cell.emission_enabled = true
	cell.emission = Color("be6512")
	cell.emission_energy_multiplier = .35
	var glow := StandardMaterial3D.new()
	glow.resource_name = "SolarEnergy"
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffe8a5")
	glow.emission_enabled = true
	glow.emission = Color("ffbf46")
	glow.emission_energy_multiplier = 2.0
	var n := group(null, "SunfallArrayModel")
	cylinder(n,"OctagonalFoundation",Vector3(0,.12,0),1.35,1.55,.24,dark,8)
	cylinder(n,"ReactorFoot",Vector3(0,.4,0),.85,1.05,.48,armor,8)
	ring(n,"FoundationConduit",Vector3(0,.56,0),.91,.035,gold)
	cylinder(n,"CentralPylon",Vector3(0,2.06,0),.52,.69,3.05,dark,8)
	for i in 4:
		var a := i * TAU/4.0
		var face := group(n,"ArmorFace%d" % i)
		face.rotation.y = a
		armor_box(face,"IvoryCasing",Vector3(0,2.13,.53),Vector3(.77,2.72,.2),.13,pale)
		box(face,"ReactorRecess",Vector3(0,2.05,.643),Vector3(.24,2.22,.035),dark)
		box(face,"SolarChannel",Vector3(0,2.05,.669),Vector3(.095,2.12,.027),glow)
		for y in [.96,3.22]:
			armor_box(face,"LockingCollar",Vector3(0,y,.67),Vector3(.62,.23,.22),.05,gold)
		for x in [-.27,.27]:
			for y in [1.22,2.82]:
				cylinder(face,"Fastener",Vector3(x,y,.66),.042,.042,.07,dark,6).rotation.x = PI/2
		var leg := group(n,"Stabilizer%d" % i)
		leg.rotation.y = a + PI/4
		beam(leg,"LoadBearingStrut",Vector3(0,.23,1.52),Vector3(0,1.25,.62),.33,dark)
		var plate := armor_box(leg,"SplayedArmor",Vector3(0,.65,1.03),Vector3(.64,1.27,.32),.13,pale)
		plate.rotation.x = -.7
		armor_box(leg,"GroundShoe",Vector3(0,.19,1.5),Vector3(.79,.32,.78),.09,pale)
		box(leg,"AmberFootStripe",Vector3(0,.37,1.55),Vector3(.52,.035,.1),gold)
	cylinder(n,"CrownSocket",Vector3(0,3.62,0),.63,.7,.3,pale,8)
	cylinder(n,"EmitterLens",Vector3(0,3.8,0),.37,.45,.13,glow,12)
	# Four separate inclined collectors leave open space around the pylon.
	for side in [-1,1]:
		for row in [-1,1]:
			var wing := group(n,"Collector%d_%d" % [side,row],Vector3(side*1.73,3.12,row*.88))
			wing.rotation = Vector3(row*.36,0,side*.38)
			beam(n,"CollectorSupport%d_%d" % [side,row],Vector3(side*.48,2.85,row*.3),wing.position,.14,dark)
			armor_box(wing,"PanelFrame",Vector3.ZERO,Vector3(1.82,.12,1.12),.05,gold)
			box(wing,"PanelBacking",Vector3(0,-.08,0),Vector3(1.63,.07,.95),dark)
			for x in 4:
				for z in 3:
					box(wing,"PhotonicCell%d_%d" % [x,z],Vector3(-.65+x*.433,.071,-.35+z*.35),Vector3(.39,.025,.305),cell)
			for x in [-.86,.86]:
				box(wing,"BrightEdge",Vector3(x,.085,0),Vector3(.028,.025,1.06),glow)
	var core := group(n,"SolarCore",Vector3(0,4.16,0))
	crystal(core,"SunHeart",Vector3.ZERO,Vector3(.22,.47,.22),glow)
	var cage := ring(core,"MeridianCage",Vector3.ZERO,.38,.019,gold)
	cage.rotation.x = PI/2
	cage = ring(core,"CrossMeridian",Vector3.ZERO,.38,.019,gold)
	cage.rotation.z = PI/2
	ring(core,"CoreEquator",Vector3.ZERO,.38,.018,glow)
	var halo := group(n,"UpperHalo",Vector3(0,5.18,0))
	for i in 8:
		arc(halo,"HaloSegment%d" % i,1.57,i*TAU/8.0+.045,(i+1)*TAU/8.0-.045,.035,glow)
	var lower := group(n,"LowerHalo",Vector3(0,4.08,0))
	lower.rotation.z = .12
	ring(lower,"FocusOrbit",Vector3.ZERO,.78,.016,glow)
	beam(n,"AlignmentSpire",Vector3(0,4.52,0),Vector3(0,5.85,0),.018,glow)
	var banner := instance(n,"outpost_banner","CrimsonStandard",Vector3(.74,1.12,-.13))
	banner.scale = Vector3(.7,1.02,.7)
	var cloth := banner.get_node("Pennant") as MeshInstance3D
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("a83c34")
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = red
	save_model(n,"sunfall_array")
	print("Baked Sunfall Array: four collectors, armored pylon, sun core and halos")
	quit()

func arc(p: Node3D, title: String, radius: float, start: float, end: float, width: float, mat: Material) -> void:
	var g := group(p,title)
	for i in 10:
		var a := lerpf(start,end,i/10.0)
		var b := lerpf(start,end,(i+1)/10.0)
		beam(g,"Filament%d" % i,Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),width,mat)
