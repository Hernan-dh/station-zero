extends RefCounted
## Collapse static mesh nodes into one mesh per material. Pivots keep their
## hierarchy so animated branches keep working; protected meshes are left alone.
## Selectable subtrees are merged in place so metadata still owns real geometry.

const Metadata = preload("res://scripts/metadata.gd")

static func merge_model(root: Node3D) -> void:
	merge_static_meshes(root, root)

static func merge_static_meshes(root: Node3D, owner_root: Node) -> void:
	var region_nodes := {}
	var protected_nodes := {}
	# Metadata-tagged nodes own their geometry: pivots keep their hierarchy,
	# protected meshes stay separate, and selectable subtrees keep real geometry.
	for node in root.find_children("*", "Node3D", true, false):
		if node.get_meta(Metadata.MERGE_PIVOT, false):
			region_nodes[node] = true
		if node.get_meta(Metadata.MERGE_PROTECTED, false):
			protected_nodes[node] = true
		if Metadata.has_display_name(node):
			region_nodes[node] = true
	_merge_region(root, region_nodes, protected_nodes, owner_root)
	for region in region_nodes:
		_merge_region(region, region_nodes, protected_nodes, owner_root)
	_remove_empty(root, region_nodes, protected_nodes, owner_root)

static func _merge_region(region: Node, region_nodes: Dictionary, protected_nodes: Dictionary, owner_root: Node) -> void:
	var groups := {}
	var to_remove: Array[Node] = []
	_collect_region_meshes(region, Transform3D.IDENTITY, region_nodes, protected_nodes, groups, to_remove)
	for node in to_remove:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	var index := 0
	for key in groups:
		var group: Dictionary = groups[key]
		var merged := MeshInstance3D.new()
		merged.name = "MergedStatic%02d" % index
		merged.mesh = group.tool.commit()
		merged.material_override = group.material
		region.add_child(merged)
		merged.owner = owner_root
		index += 1

static func _collect_region_meshes(node: Node, transform: Transform3D, region_nodes: Dictionary, protected_nodes: Dictionary, groups: Dictionary, to_remove: Array[Node]) -> void:
	for child in node.get_children():
		if region_nodes.has(child) or protected_nodes.has(child):
			continue
		var child_transform := transform
		if child is Node3D:
			child_transform = transform * child.transform
		if child is MeshInstance3D and child.mesh != null and child.get_child_count() == 0:
			if not child.visible or child.get_meta_list().size() > 0:
				continue
			var material: Material = child.material_override
			if material == null:
				continue
			for surface in child.mesh.get_surface_count():
				var key := "%d" % material.get_instance_id()
				if not groups.has(key):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tool.set_smooth_group(-1)
					groups[key] = {"tool": tool, "material": material}
				var group: Dictionary = groups[key]
				group.tool.append_from(child.mesh, surface, child_transform)
			to_remove.append(child)
		elif child is Node3D:
			_collect_region_meshes(child, child_transform, region_nodes, protected_nodes, groups, to_remove)

static func _remove_empty(node: Node, region_nodes: Dictionary, protected_nodes: Dictionary, root: Node) -> void:
	for child in node.get_children():
		if region_nodes.has(child) or protected_nodes.has(child):
			_remove_empty(child, region_nodes, protected_nodes, root)
			continue
		_remove_empty(child, region_nodes, protected_nodes, root)
		if child == root:
			continue
		if child.get_class() == "Node3D" and child.get_child_count() == 0 and child.get_script() == null and child.get_meta_list().is_empty() and child.get_groups().is_empty():
			child.get_parent().remove_child(child)
			child.free()
