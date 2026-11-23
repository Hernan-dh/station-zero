# Storm Mantis

Based on the Storm Mantis panel in `references/sz_concept_5.png`.

- Place `res://scenes/storm_mantis.tscn` for the complete presentation: rigged geometry, hovering flight animation, electric sparks, a blue fill light, crackling plasma arcs and selection shapes. The outpost instance patrols the left approach.
- Use `res://scenes/models/storm_mantis.tscn` for geometry alone. The scene faces local -Z and its origin is the centre of the body, not the ground, so the component can add its hover height. The source GLB faces +Z and is corrected by the wrapper.
- The thirteen-bone skeleton uses rigid weights so chitin plates keep their shape. `Idle` and `Flight` are looping clips. The component follows an existing approach path at a hover height, plays `Flight` while moving, banks into the route, and settles to a gentle hover with `Idle` when it stops.
- The component joins the `enemies` group and exposes `health`, `max_health`, `take_damage(amount)`, `is_alive()` and `get_aim_position()`, so automatic defenses such as the Arc Launcher can target it. Defeated mantises stop moving, switch off the lightning and sparks, emit `defeated` and are removed from the scene.
- Toggle the component's `lightning_enabled` property to stop the arcs, fill light and spark glow. Both the particles and the ImmediateMesh bolts work with the project's Compatibility renderer.
- Blender source is in `source/storm_mantis.blend`. That directory has `.gdignore` so Godot imports only the exported GLB.

Rebuild from the project root using the installed Blender:

```sh
blender -b --python scripts/tools/build_storm_mantis.py
```

The generator creates both the editable Blender file and the GLB, with no external textures or add-ons. It uses a fixed random seed for repeatable chitin detail.
