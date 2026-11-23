extends RefCounted
## Shared per-instance material setup for equipment models. Components that
## change material state must own duplicates, never the shared scene resources.

static func duplicate_materials(model: Node, sources: Array) -> Dictionary:
	return _duplicate(model, func(material: Material) -> bool: return material in sources)

static func duplicate_matching(model: Node, predicate: Callable) -> Dictionary:
	return _duplicate(model, predicate)

static func _duplicate(model: Node, predicate: Callable) -> Dictionary:
	var copies := {}
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var material: Material = part.material_override
		if material == null or not predicate.call(material):
			continue
		if not copies.has(material):
			copies[material] = material.duplicate()
		part.material_override = copies[material]
	return copies
