# Procedural Structure Generator for Godot 4  

Wave-Function-Collapse powered modular building tool

## Overview

Building believable houses, city blocks, and other architectural structures in 3D often means a **lot** of repetitive manual work — even when using a modular kit. Placing every wall, window, and roof piece by hand is time-consuming and error-prone.

This plugin aims to solve that by combining a **modular asset workflow** with a **Wave Function Collapse (WFC)** algorithm to generate complex structures directly inside the Godot 4 editor.

The result:

- You define a **set of modular building pieces** (walls, corners, roofs, windows, etc.)
- You describe how these pieces are allowed to connect
- The plugin uses WFC to **generate entire buildings or blocks automatically**
- The generated structures can then be **baked into normal scenes**, freely edited, and reused

It’s designed to integrate nicely with an **asset placer plugin**: this tool creates the houses, the placer plugin is then used to position those houses in the world and add props and details.

---

## Goals

- **Speed up level creation** for modular architecture-heavy games
- **Reduce repetitive work** when assembling houses, blocks, or villages
- Provide **controllable randomness** through constraints and WFC
- Generate structures that are:
  - Procedurally assembled
  - Still fully **editable** as regular Godot scenes
- Fit naturally into a modular workflow (using existing meshes and tiles)

---

## Core Concepts

### 1. Structure Panel

Rather than cluttering your scene hierarchy with generator nodes, the plugin introduces a dedicated **Structure panel** in the bottom panel area of the Godot editor.

This panel provides:

- **Live preview** of the generated structure with a simplified 2D top-down or grid-based view
  - Zoom and pan controls for navigation
  - "Frame structure" button to focus on the current model
  - Grid visualization and bounds display
- **Parameter controls** for dimensions, constraints, and seed
- **Export to scene** functionality to save finished structures as `.tscn` files
- **Import existing scenes** to modify or use as templates
- **Built-in presets** like "Simple House" or "Basic Tower" to get started quickly
- **Non-destructive workflow** - structure definitions (saved as **Structure Definition** resources) are separate from exported scene instances

This approach keeps the editor interface clean and integrated, matching Godot's design philosophy (similar to other bottom panels like the Output or Debugger panels) and keeps generation separate from your main scene work.

**Note for beginners:** Unlike some plugins, you don't simply drop a node in your scene and hit "Generate". Instead, you author structures in the dedicated bottom panel, then export them as reusable `.tscn` files. This keeps your scene hierarchy clean and your structures organized as proper assets.

---

### 2. Structure Definitions (Resource Type)

The plugin introduces a new resource type called **Structure Definition** (`.tres` file) that stores all the parameters for generating a structure:

- Grid dimensions and constraints
- Module library reference
- Style preset selection
- Seed value
- Custom rules and overrides

These definitions are edited in the Structure viewport and can be:

- Saved and versioned like any other Godot resource
- Shared between projects
- Used as templates for variations
- Referenced by optional scene helper nodes (future feature)

---

### 3. Module Library

The plugin works with a library of *modules* – small reusable building blocks such as:

- Wall segments (plain, windowed, door)
- Corners and edges
- Floors and ceilings
- Roof pieces (slopes, corners, caps)
- Special modules (balconies, arches, towers, etc.)

Each module stores metadata, e.g.:

- Reference to a `.tscn` scene
- Tags (e.g. `wall`, `window`, `roof`, `corner`)
- Connection data for each side (`north/south/east/west/up/down`), or "socket types" like:
  - `wall_plain`, `wall_window`, `roof_edge`, `interior`, `exterior`

These rules tell the WFC algorithm **which modules are allowed to be neighbors**.

#### Module Creation Workflow

When creating modules:

- **Pivot/origin alignment** - Modules should share consistent origin points for proper grid snapping
- **Socket definition** - Sockets can be defined through:
  - Custom properties on the module resource
  - Naming conventions (e.g., `north_wall_plain`, `east_window`)
  - Visual markers in the editor
- **Validation tools** - The plugin provides utilities to check module compatibility and highlight potential issues

---

### 4. WFC Generation Engine

The core WFC algorithm runs within the Structure viewport and exposes:

- **Grid dimensions** (width, depth, height in cells)
- **Module library** selection
- **Seed** for reproducible results
- **Style / rule presets** (e.g. "simple house", "row house", "tower", "block")
- **Constraint system**:
  - Minimum/maximum height
  - Require at least one door on ground level
  - Flat vs. sloped roof
  - Balcony density, window frequency, etc.
- **Failure handling** - If WFC cannot find a valid solution, it can:
  - Backtrack to the last valid state
  - Relax constraints automatically
  - Notify the user with specific conflict information

The preview updates in real-time as you adjust parameters, showing the structure as it generates.

---

### 5. Export & Integration

Once a structure is generated in the viewport, you can:

- **Export to `.tscn`** - Save the structure as a standard Godot scene file
- **Manual refinement** - Open the exported scene to:
  - Remove or replace specific modules
  - Add custom details, props, or decorations
  - Adjust materials and lighting
- **Import existing scenes** - Load previously exported structures back into the Structure viewport to modify or use as templates
- **Reusable assets** - Exported scenes are fully editable standard Godot nodes, ready to instance in your levels
- **Regeneration support** (future feature) - Exported scenes may include metadata linking back to the original Structure Definition, allowing you to:
  - Reopen in the Structure viewport with one click
  - Generate variants with different seeds
  - Update if the definition changes

The WFC output is a **starting point**, not a final, untouchable procedural mesh.

**Optional Scene Helper** (v2 feature): A lightweight `StructureInstance` node may be added in future versions to let you reference and regenerate structures directly within scene hierarchies, but this is purely for convenience – the core workflow remains viewport-based.

---

## Workflow Example

### Getting Started (Quickstart)

**For absolute beginners:**

1. **Open the Structure viewport** (toolbar button or bottom panel).
2. **Start with a preset** - Select "Simple House" or "Basic Tower" from the built-in examples.
3. **Hit Generate** - See a structure appear instantly.
4. **Tweak parameters** (optional) - Adjust seed, dimensions, or constraints and watch it regenerate.
5. **Export to scene** - Save as `.tscn` and drag it into your level.

**For customization:**

1. **Prepare a modular set** of building pieces in Godot (snap-friendly, grid-aligned).
2. **Register those pieces** in the **Module Library** inside the plugin:
   - Define socket/connection types for each module
   - Set up adjacency rules
   - Validate compatibility using the provided tools
3. **Open the Structure viewport** and create a new **Structure Definition**.
4. **Configure generation parameters**:
   - Grid dimensions (e.g. 10×10×3)
   - Module library selection
   - Style preset or custom rules
   - Constraints (doors, roof type, window density)
   - Random seed for reproducibility
5. **Preview live** - The structure updates in real-time as you tweak parameters. Use camera controls (orbit, pan, "Frame structure" button) to inspect from all angles.
6. **Save the Structure Definition** as a `.tres` resource for later reuse or versioning.
7. **Export to `.tscn`** when satisfied with the result.
8. **Refine if needed** - Open the exported scene to add custom details or make manual adjustments.
9. **Use an asset placer plugin** to:
   - Instance these structure scenes across your world (villages, towns, city districts)
   - Add props (barrels, lamps, foliage, fences, etc.) for final polish.

---

## Future Ideas

This plugin is intentionally designed to be extendable. Possible future features include:

- **2D-only mode** (for floorplans or tilemaps)
- Multi-floor logic (stair placement, vertical constraints)
- Generation of **entire villages or districts** by:
  - Treating whole houses as higher-level tiles in another WFC pass
  - Integrating road tiles, plazas, and open spaces
- Themed rule sets:
  - Medieval village
  - Dense urban block
  - Industrial district
- Rule visualization and debugging:
  - Highlighting contradictions
  - Showing per-cell possibilities/entropy

---

## Why Wave Function Collapse?

WFC is a great match for modular architecture because:

- It respects **local constraints** (which piece can be next to which)
- It produces layouts that are:
  - Structured enough to look intentional
  - Varied enough to avoid repetition
- It maps naturally to **grid-based modular kits**, which are common in 3D workflows

This plugin aims to package that power into a **Godot 4 editor-friendly** workflow, so you can stay in your usual environment while massively speeding up content creation.

---

## Summary

This plugin is a **procedural structure generator** for Godot 4, built around a Wave Function Collapse algorithm and a modular asset workflow. It’s designed to:

- Rapidly generate houses and other structures from modular pieces  
- Let you keep full manual control afterwards  
- Integrate with existing placement tools to build entire towns and cities

The goal is to make building rich, modular environments **faster, more fun, and more creative**, without sacrificing editability or artistic control.
