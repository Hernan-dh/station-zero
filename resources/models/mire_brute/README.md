# Mire Brute

Based on the Mire Brute panel in `references/sz_concept_5.png`.

- Place `res://scenes/mire_brute.tscn` for the complete presentation: rigged geometry, idle animation, toxin vapor, green fill light, and selection shapes. An instance stands on the outpost's rear approach.
- Use `res://scenes/models/mire_brute.tscn` for geometry alone. The scene faces local -Z; its feet rest at Y = 0. The source GLB faces +Z and is corrected by the wrapper.
- The nine-bone skeleton has rigid weights so stone armor keeps its shape. `Idle` and `Lumber` are looping clips; the component starts `Idle`. `Lumber` is an in-place clip for future movement integration. No combat or path movement is added by this model.
- Toggle the component's `vapor_enabled` property to stop emission. The vapor uses CPU particles and works with the project's Compatibility renderer.
- Blender source is in `source/mire_brute.blend`. That directory has `.gdignore` so Godot imports only the exported GLB.

Rebuild from the project root using the installed Blender:

```sh
blender -b --python scripts/tools/build_mire_brute.py
```

The generator creates both the editable Blender file and the GLB, with no external textures or add-ons. It uses a fixed random seed for repeatable armor details.
