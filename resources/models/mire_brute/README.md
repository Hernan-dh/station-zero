# Mire Brute

Based on the Mire Brute panel in `references/sz_concept_5.png`.

- Place `res://scenes/mire_brute.tscn` for the complete presentation: rigged geometry, idle animation, toxin vapor, green fill light, and selection shapes. The outpost instance starts at the rear approach spawn and walks to the habitat arrival.
- Use `res://scenes/models/mire_brute.tscn` for geometry alone. The scene faces local -Z; its feet rest at Y = 0. The source GLB faces +Z and is corrected by the wrapper.
- The nine-bone skeleton has rigid weights so stone armor keeps its shape. `Idle` and `Lumber` are looping clips. The component follows the existing rear `EnemyPath` from spawn to destination, faces the direction of travel, plays `Lumber` while moving, and settles to `Idle` when it stops. Set `approach_path` to follow another approach or leave it empty to use the nearest one.
- The component joins the `enemies` group and exposes `health`, `max_health`, `take_damage(amount)`, `is_alive()` and `get_aim_position()`, so automatic defenses such as the Arc Launcher can target it. Defeated brutes stop moving, switch off their vapor, emit `defeated` and are removed from the scene.
- Toggle the component's `vapor_enabled` property to stop emission. The vapor uses CPU particles and works with the project's Compatibility renderer.
- Blender source is in `source/mire_brute.blend`. That directory has `.gdignore` so Godot imports only the exported GLB.

Rebuild from the project root using the installed Blender:

```sh
blender -b --python scripts/tools/build_mire_brute.py
```

The generator creates both the editable Blender file and the GLB, with no external textures or add-ons. It uses a fixed random seed for repeatable armor details.
