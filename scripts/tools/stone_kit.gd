extends "res://scripts/tools/build_kit.gd"
## Shared helpers for the carved-stone generators. Carries its own material
## palette and random source, so no generator depends on another one's state.

var stone: Array[Material] = []
var _crystal_meshes := {}

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
	if _crystal_meshes.has(size):
		mesh(p,title,_crystal_meshes[size],pos,mat)
		return
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
	_crystal_meshes[size] = st.commit()
	mesh(p,title,_crystal_meshes[size],pos,mat)

func arc(p: Node3D, title: String, radius: float, start: float, end: float, width: float, mat: Material) -> void:
	var g := group(p,title)
	for i in 10:
		var a := lerpf(start,end,i/10.0)
		var b := lerpf(start,end,(i+1)/10.0)
		beam(g,"Filament%d" % i,Vector3(cos(a)*radius,0,sin(a)*radius),Vector3(cos(b)*radius,0,sin(b)*radius),width,mat)
