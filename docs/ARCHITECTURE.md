# Architecture

Station Zero is a Godot project with its main scene at `res://scenes/outpost.tscn`. The analysis branch adds the Godot Editor MCP addon to inspect a running editor via a local MCP server. The addon and analysis tooling belong to this branch, not to `main`.

Inspect the exact `main` revision through Git. A running editor reflects the analysis working tree, which may differ from `main`; check the relevant revision before attributing findings. Maintain analysis findings separately from candidate tasks, whose descriptions must be written by a person.
