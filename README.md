# Station Zero

A small 3D sci-fantasy outpost scene built with Godot 4.7 (GL Compatibility).
The project is a self-contained demonstration: an orthographic camera, selectable
structures, small interactive equipment panels, and a baked lunar environment.

## Run

Open `project.godot` in the Godot editor, or run from the project root:

```sh
godot --path .
```

The main scene is `res://scenes/outpost.tscn`.

## Controls

| Action | Input |
| --- | --- |
| Select an object | Left click |
| Orbit the camera | Left drag |
| Pan the camera | Right drag or Shift + Left drag |
| Zoom | Mouse wheel |
| Reset the view | `R` |
| Toggle auto-orbit | `O` |
| Use a selected object's panel | Click buttons, sliders and toggles |

These bindings live in the project input map (`camera_reset`, `camera_auto_orbit`,
`camera_zoom_in`, `camera_zoom_out`, `select`, `camera_pan`).

## Project layout

- `scenes/` — runtime scenes. `outpost.tscn` is the main scene.
- `scenes/models/` — reusable baked model scenes.
- `resources/` — materials, meshes, moon terrain data, environment resources and
  the baked picking scene. Generated model and scene meshes are compressed
  external `.res` files under `resources/models/meshes/` and `resources/scenes/`.
- `scripts/components/` — state-owning outpost equipment scripts.
- `scripts/ui/` — the panels attached to selected equipment.
- `scripts/tools/` — content generators, the model mesh merger, the picking baker
  and the read-only content validator.
- `references/` — concept art (ignored by Godot).
- `tmp/` — throwaway probes and renders (never committed).

### Shared modules

- `scripts/world_layout.gd` — shared route and gate layout used by the terrain
  generators. Equipment placement, flank-site occupancy and defense-site
  presentation values are read from the saved main scene, which remains the
  single source of truth for object transforms.
- `scripts/terrain_style.gd` — terrain seeds, route/clearance tuning, terrain
  colours, material settings and decoration counts used by the generators.
- `scripts/component_style.gd` — shared runtime visual tuning for the equipment
  components.
- `scripts/component_setup.gd` — shared per-instance material duplication for
  equipment models.
- `scripts/model_style.gd` — shared seeds, palettes and placement tuning for the
  baked equipment and entrance models.
- `scripts/interface_style.gd` — UI colours, font sizes, panel sizes, offsets and
  shared panel/button/slider/progress setup. The selection and control panels
  share the same width.
- `scripts/metadata.gd` — the selection/content metadata contract (`display_name`,
  `selection_ignore`, `attachment_path`, `occupied`, `entrance`, etc.) plus a
  validation pass that reports malformed metadata instead of silently hiding it.

## Rebuilding content

Run Godot from the project root, once per generator, in this order:

```sh
godot --headless --path . --script res://scripts/tools/build_outpost.gd
godot --headless --path . --script res://scripts/tools/build_habitat_entrances.gd
godot --headless --path . --script res://scripts/tools/build_portal_gate.gd
godot --headless --path . --script res://scripts/tools/build_aether_relay.gd
godot --headless --path . --script res://scripts/tools/build_sunfall_array.gd
godot --headless --path . --script res://scripts/tools/build_shield_generator.gd
godot --headless --path . --script res://scripts/tools/merge_baked_models.gd
godot --headless --path . --script res://scripts/tools/build_enemy_flanks.gd
godot --headless --path . --script res://scripts/tools/bake_picking.gd
```

Rebuilds are transactional: generated meshes and scenes are written to a
staging area under `tmp/` and only moved into place when the whole generator
succeeds. A failed generation, validation or save leaves the previous resources
untouched; a failed commit restores every replaced or removed file. Verify the
failure paths with the deterministic headless check (exit code 0 means pass):

```sh
godot --headless --path . --script res://scripts/tools/check_rebuild_safety.gd
```

## Validating saved content

Run the read-only regression check after editing or regenerating content:

```sh
godot --headless --path . --script res://scripts/tools/check_content.gd
```

It verifies that every scene dependency exists, every generated external mesh
loads and is referenced, the selection metadata follows the shared contract, and
every baked picking body still attaches to a live `Node3D` with a valid collision
shape. It never saves scenes or resources. Failures name the file to restore or
the generator to rerun, and the exit code is nonzero when anything is wrong.

The environment generator builds the expanded terrain, outer highlands and four
approaches entirely in memory, then saves only runtime scenes. Static terrain
decorations are merged into one mesh per material, while decorations rejected by
the route/site grading pass are removed before merging. Approach decorations are
merged into a few meshes per approach, and flank site bedrock is merged as one
ground group. Flank-site transforms, numbering and labels come from the flank
sites already saved in the main scene; their occupancy is matched against the
structures and build sites placed there. A first build without saved flank sites
falls back to route samples plus the structure nearest each flank route, so there
is no second site table and the generated
flank scene does not need hand-edited overrides. Terrain and approach meshes are
saved as compressed external
resources, and terrain materials are shared external resources in
`resources/moon/materials/`, so the generators and baked scenes reference the
same materials. Re-run `bake_picking.gd` after changing outpost geometry, saved
transforms or selection metadata; see `resources/picking/README.md`.

Model generators merge static mesh nodes into one mesh per material while
keeping animated pivots, protected meshes and `display_name`-tagged subtrees
intact. Pivots and protected meshes are marked with metadata instead of a
filename table, so adding or renaming a model does not require editing the
merger. Airlocks, gates and other selectable owners therefore keep geometry that
picking can attach to. Generated meshes are saved once as compressed external
resources, keeping the text scenes small. Run `merge_baked_models.gd` for
hand-authored equipment models and `dedupe_scene_resources.gd` to collapse
identical mesh and material subresources in place.

The Mire Brute and Storm Mantis are built separately with Blender:

```sh
blender -b --python scripts/tools/build_mire_brute.py
blender -b --python scripts/tools/build_storm_mantis.py
```

See `resources/models/mire_brute/README.md` and
`resources/models/storm_mantis/README.md` for details.
