# UI Enhancement Implementation Plan

## User Workflow Implementation

### Phase 1: Enhanced Import Dialog ✨

**Goal:** Streamline tile import with simple defaults + advanced options

#### 1.1 User Flow

```
User clicks "Add Tile" button in ModuleLibraryPanel
    ↓
1. Standard Godot FileDialog opens
   • Multi-select enabled (.tscn, .glb, .gltf, .obj, .fbx)
   • User selects one or more 3D models
    ↓
2. TileImportConfigDialog shows
   • Lists all selected files with thumbnails
   • Simple per-tile settings (size, template)
   • Advanced collapsible section (socket types, tags, etc.)
    ↓
3. User clicks Import
   • Tiles created with configured settings
   • Auto-added to current library
   • Optionally opens socket editor for fine-tuning
```

#### 1.2 Create TileImportConfigDialog (`ui/dialogs/tile_import_config_dialog.gd`)

**Visual Design:**

**Main View (Bulk-First, Clean):**
```
┌─────────────────────────────────────────────────┐
│ Import 4 Tiles                            [×]   │
├─────────────────────────────────────────────────┤
│ 📦 Batch Settings                               │
│ ┌───────────────────────────────────────────┐  │
│ │ Size: [x 1 ▼] [y 1 ▼] [z 1 ▼]            │  │
│ │ Template: [Wall - 4 Way ▼]                │  │
│ │ Tags: [dungeon, stone] [+]                │  │
│ │                                           │  │
│ │ ☑ Auto-detect symmetry                    │  │
│ │ ☑ Generate rotational variants            │  │
│ │ □ Include self-match                      │  │
│ │                                           │  │
│ │ [Apply to All] [Apply to Selected (2)]   │  │  ← Smart bulk actions
│ └───────────────────────────────────────────┘  │
│                                                 │
│ ─────────────────────────────────────────────  │
│                                                 │
│ 📋 Tiles (4)       [Select All] [Deselect All] │
│ ┌─┬──┬──────────────────────────────────────┐ │
│ │☑│🏰│ wall_01.glb               [Override]│ │  ← Checkbox selection
│ └─┴──┴──────────────────────────────────────┘ │
│ ┌─┬──┬──────────────────────────────────────┐ │
│ │☑│🏰│ wall_02.glb               [Override]│ │  ← Selected
│ └─┴──┴──────────────────────────────────────┘ │
│ ┌─┬──┬──────────────────────────────────────┐ │
│ │☐│🏰│ wall_corner.glb  📌       [Override]│ │  ← Has override (📌)
│ └─┴──┴──────────────────────────────────────┘ │
│ ┌─┬──┬──────────────────────────────────────┐ │
│ │☐│🏠│ floor_01.glb              [Override]│ │
│ └─┴──┴──────────────────────────────────────┘ │
│                                                 │
│                  [ Import ]      [ Cancel ]     │
└─────────────────────────────────────────────────┘
```

**Individual Override View (On-Demand):**
```
┌─┬──┬──────────────────────────────────────────┐
│☑│🏰│ wall_corner.glb          [×] [↻]  [▲]  │  ← Close / Reset / Collapse
├─┴──┴──────────────────────────────────────────┤
│ ✏️  Override Settings (only for this tile)   │
│                                               │
│ Name: [wall_corner________]                   │
│ Size: [x 2 ▼] [y 3 ▼] [z 1 ▼]               │
│ Template: [Corner - L Shape ▼]  📌           │
│                                               │
│ ˅ Advanced                                    │
│   Socket Types:                               │
│   • North: [wall_connection ▼]               │
│   • West:  [wall_connection ▼]               │
│   • (Others: none)                            │
│                                               │
│   Tags: [dungeon, stone, corner] [+]         │
│   ☑ Auto-detect symmetry                      │
│   □ Generate rotational variants              │
└───────────────────────────────────────────────┘
```

**Key Features:**

1. **Batch Settings (Primary Workflow):**
   - **Prominent Section:** Always visible at top
   - **Common Settings:**
     - Size: X, Y, Z spinboxes (default: 1, 1, 1)
     - Template dropdown: None, Wall - 4 Way, Wall - Linear, Floor - 4 Way, Corner - L Shape, Custom...
     - Tags: Multi-tag input with auto-complete
     - Auto-detect symmetry checkbox
     - Generate rotational variants checkbox
     - Include self-match checkbox
   - **Smart Actions:**
     - **"Apply to All":** Applies batch settings to ALL tiles (resets any overrides)
     - **"Apply to Selected (N)":** Applies batch settings to N selected tiles only
     - Context-aware: "Apply to Selected" button only enabled when tiles are checked

2. **Tile Selection List:**
   - **Checkbox selection** for each tile
   - **Multi-select support:** Ctrl+Click, Shift+Click for ranges
   - **Bulk selection:** "Select All" / "Deselect All" buttons
   - **Clean collapsed view** by default (just thumbnail + filename)
   - **Visual indicators:**
     - 📌 icon shows tiles with individual overrides
     - Highlighted border for selected tiles
     - Checkboxes for batch operation targeting

3. **Individual Override (On-Demand):**
   - **Click [Override]** to expand a tile
   - **Full configuration** appears inline
   - **Name editing:** Change tile name from filename
   - **All batch settings** available for this specific tile
   - **Advanced section** collapsible within override:
     - Socket type override per direction
     - Custom tags for this tile
     - Individual symmetry/variant/self-match settings
   - **Controls:**
     - [×] Close override (collapse back)
     - [↻] Reset to batch settings (remove override)
     - [▲] Collapse (keep override but hide details)

4. **Workflow Examples:**

   **Example 1: Import 10 walls + 2 floors**
   1. Set batch: Size 2x3x1, Template "Wall - 4 Way", Tags "dungeon, wall"
   2. Check all 10 wall tiles
   3. Click "Apply to Selected (10)"
   4. Check the 2 floor tiles
   5. Change batch template to "Floor - 4 Way"
   6. Click "Apply to Selected (2)"
   7. Import

   **Example 2: Mostly same, one exception**
   1. Set batch settings for standard walls
   2. Click "Apply to All"
   3. Click [Override] on corner piece
   4. Change template to "Corner - L Shape"
   5. Import

   **Example 3: Granular control**
   1. Set reasonable batch defaults
   2. Click "Apply to All"
   3. Override 3 tiles individually with [Override] button
   4. Use checkboxes to select 5 other tiles
   5. Adjust batch settings for those 5
   6. Click "Apply to Selected (5)"
   7. Import

5. **Advanced Features:**
   - **Right-click context menu** on tiles:
     - "Apply batch settings to this"
     - "Copy settings from this tile to selected"
     - "Reset to batch settings"
     - "Remove from import"
     - "Expand all overrides" / "Collapse all"
   - **Smart Detection:**
     - Analyze filenames for patterns (wall_*, floor_*, etc.)
     - Check mesh geometry (height > width*2 = wall)
     - Suggest templates automatically
     - Group similar tiles visually
   - **Keyboard shortcuts:**
     - Ctrl+A: Select all tiles
     - Ctrl+D: Deselect all
     - Space: Toggle selected tile expansion

6. **Validation & Feedback:**
   - Real-time validation using ValidationEventBus
   - Warning icons for tiles with missing socket types
   - Error indicators for invalid configurations
   - Summary: "4 tiles ready, 0 warnings"

**Implementation:**

```gdscript
@tool
class_name TileImportConfigDialog extends AcceptDialog

signal tiles_confirmed(tile_configs: Array[Dictionary])

# Each config Dictionary contains:
# {
#   "file_path": String,
#   "tile_name": String,
#   "size": Vector3i,
#   "template_id": String,
#   "socket_types": Dictionary,  # direction -> type_id
#   "tags": Array[String],
#   "auto_detect_symmetry": bool,
#   "generate_variants": bool,
#   "include_self_match": bool,
#   "requirements": Array[Dictionary]
# }

@onready var tile_list_container: VBoxContainer
@onready var apply_to_all_menu: MenuButton

var tile_config_controls: Array[TileConfigControl] = []
var file_paths: PackedStringArray = []

func setup(files: PackedStringArray) -> void:
	file_paths = files
	_generate_tile_configs()
	_populate_ui()

func _generate_tile_configs() -> void:
	# Create default config for each file
	for file_path in file_paths:
		var config = {
			"file_path": file_path,
			"tile_name": file_path.get_file().get_basename(),
			"size": Vector3i(1, 1, 1),
			"template_id": "",  # Empty = no template
			"socket_types": {},
			"tags": [],
			"auto_detect_symmetry": true,
			"generate_variants": false,
			"include_self_match": false,
			"requirements": []
		}
		tile_config_controls.append(_create_config_control(config))

func _create_config_control(config: Dictionary) -> TileConfigControl:
	# Create UI control for single tile configuration
	# Includes thumbnail, basic settings, advanced section
	pass

func _on_apply_template_to_all(template_id: String) -> void:
	for control in tile_config_controls:
		control.set_template(template_id)

func _on_smart_detect_pressed() -> void:
	# Analyze mesh geometry and suggest templates
	for control in tile_config_controls:
		var suggested_template = _detect_template(control.get_file_path())
		control.set_template(suggested_template)

func _detect_template(file_path: String) -> String:
	# Simple heuristics:
	# - Check filename for keywords (wall, floor, corner)
	# - Analyze mesh bounds (height > width*2 = wall?)
	# - Return best guess template_id
	pass

func _on_import_pressed() -> void:
	var configs: Array[Dictionary] = []
	for control in tile_config_controls:
		configs.append(control.get_config())
	
	tiles_confirmed.emit(configs)
	hide()
```

**Sub-Control: TileConfigControl** (`ui/controls/tile_config_control.gd`)
```gdscript
@tool
class_name TileConfigControl extends PanelContainer

@onready var thumbnail: TextureRect
@onready var name_edit: LineEdit
@onready var size_x: SpinBox
@onready var size_y: SpinBox
@onready var size_z: SpinBox
@onready var template_option: OptionButton
@onready var advanced_section: PanelContainer
@onready var remove_button: Button

var config: Dictionary

func set_config(new_config: Dictionary) -> void:
	config = new_config
	_update_ui()

func get_config() -> Dictionary:
	_update_config_from_ui()
	return config

func _on_template_changed(idx: int) -> void:
	var template_id = template_option.get_item_metadata(idx)
	config["template_id"] = template_id
	
	# Apply template to socket_types
	if template_id != "":
		var template = SocketTemplateLibrary.get_template(template_id)
		config["socket_types"] = template.get_socket_types()
```

#### 1.3 Integrate with ModuleLibraryPanel

**Modify `add_tiles()` in `module_library_panel.gd`:**

```gdscript
func add_tiles() -> void:
	# Step 1: Open Godot FileDialog (existing)
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	file_dialog.add_filter("*.tscn,*.glb,*.gltf,*.obj,*.fbx", "3D Models")
	file_dialog.files_selected.connect(_on_import_files_selected)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

func _on_import_files_selected(files: PackedStringArray) -> void:
	# Step 2: Show TileImportConfigDialog
	var import_dialog = TileImportConfigDialog.new()
	import_dialog.setup(files)
	import_dialog.tiles_confirmed.connect(_on_import_configs_confirmed)
	add_child(import_dialog)
	import_dialog.popup_centered_ratio(0.8)

func _on_import_configs_confirmed(tile_configs: Array[Dictionary]) -> void:
	# Step 3: Create tiles with configurations
	for config in tile_configs:
		var tile = _create_tile_from_config(config)
		current_library.add_tile(tile)  # Uses new signal-emitting method
	
	# Step 4: Show success notification
	_show_notification("%d tiles imported successfully" % tile_configs.size())
	
	# Step 5: Optionally open socket editor for fine-tuning
	# (if user wants to tweak individual sockets)
```

#### 1.4 Benefits of This Design

✅ **Simple by default:** Just size and template dropdown visible
✅ **Progressive disclosure:** Advanced options hidden until needed
✅ **Bulk operations:** Apply settings to multiple tiles at once
✅ **Smart defaults:** Auto-detect and suggest templates
✅ **Per-tile control:** Each tile can be configured independently
✅ **Visual feedback:** Thumbnails and socket previews
✅ **Validation:** Real-time error checking
✅ **Non-modal flow:** Can still reference other panels if needed

---

### Phase 2: WFC Configuration Dialog 🎛️

**Goal:** Easy WFC solver configuration from preview panel

#### 2.1 Create WFCConfigDialog (`ui/dialogs/wfc_config_dialog.gd`)

Features:
- Grid dimensions (X, Y, Z) with presets (Small 5x5x3, Medium 10x10x5, Large 20x20x10)
- Seed input with random generator button
- Strategy selection dropdown
- Advanced options collapsible:
  - Max iterations
  - Yield interval
  - Backtracking settings
  - Requirement enforcement
- Preview strategy description
- "Save as Preset" option
- Real-time validation feedback

```gdscript
@tool
class_name WFCConfigDialog extends AcceptDialog

signal config_confirmed(config: WfcSolverConfig, grid_size: Vector3i, seed: int)

@onready var size_x_spin: SpinBox
@onready var size_y_spin: SpinBox
@onready var size_z_spin: SpinBox
@onready var seed_edit: LineEdit
@onready var random_seed_button: Button
@onready var strategy_option: OptionButton
@onready var advanced_panel: PanelContainer
@onready var preset_option: OptionButton
```

#### 2.2 Enhance PreviewPanel

Add "Configure" button next to "New":
- Opens WFCConfigDialog with current settings
- Displays current configuration as tooltip
- Shows config name if using preset

---

### Phase 3: Step-Through Solver Mode 🐾

**Goal:** Interactive WFC solving with manual choice selection using inline UI

#### 3.1 Create SolverStepController (`core/wfc/solver_step_controller.gd`)

Features:
- Pause at choice points (multiple valid options)
- Visualize available choices
- Manual tile selection for current cell
- Continue solving after choice
- Rewind to previous choice (with backtracking)
- Export decision tree for replay

```gdscript
class_name SolverStepController extends RefCounted

enum StepMode {
    AUTO,           # Solve automatically
    PAUSE_ON_CHOICE,  # Pause when multiple options exist
    MANUAL_EACH     # Manual selection for every cell
}

signal step_paused(cell: WfcCell, options: Array[Dictionary])
signal step_completed(cell: WfcCell, chosen_variant: Dictionary)
signal solve_finished(success: bool)

var solver: WfcSolver
var mode: StepMode = StepMode.PAUSE_ON_CHOICE
var decision_history: Array[Dictionary] = []
```

#### 3.2 Update PreviewPanel for Inline Step Mode

**Visual Layout:**
```
┌─────────────────────────────────────┐
│  [New] [Edit] [Step] [Solve] [Menu]│  ← Existing toolbar
├─────────────────────────────────────┤
│                                     │
│         3D Viewport                 │
│     (with highlighted cell)         │
│          🟨 ← Critical cell         │
│        (glowing/pulsing)            │
│                                     │
├─────────────────────────────────────┤
│ ⚠️ Choice Required (Cell 5,2,1)    │  ← Choice panel (slides up)
│ ┌─────┬─────┬─────┬─────┬─────┐   │
│ │ 🏠  │ 🏠  │ 🏠  │ 🏠  │ 🏠  │   │  ← Tile options with thumbnails
│ │Wall │Wall │Floor│Door │Corner│   │
│ │  ↻  │  ↺  │     │     │  ↻  │   │  ← Rotation indicators
│ │★★★★☆│★★★★★│★★★☆☆│★★★☆☆│★★★★☆│   │  ← Fit quality
│ └─────┴─────┴────┴─────┴─────┘   │
│ [Auto-Pick] [Skip] [Step Back]     │
└─────────────────────────────────────┘
```

**Components:**

1. **Viewport Highlighting (`ui/controls/cell_highlighter.gd`):**
   - Highlighted cell glows/pulses in yellow/orange
   - Camera auto-focuses on critical cell with smooth transition
   - Semi-transparent overlay shows constraint conflicts
   - Adjacent cells dim slightly to emphasize choice point
   - Ghost preview of hovered option overlaid on cell

2. **Choice Panel (`ui/controls/choice_panel.gd`):**
   - Slides up from bottom when choice needed (animated)
   - Fixed height panel that expands/collapses
   - Shows 3-7 tile options in horizontal scroll
   - Auto-hides when choice made or skipped
   
3. **Option Cards (`ui/controls/tile_option_card.gd`):**
   ```
   ┌─────────────┐
   │   [Image]   │  ← 3D thumbnail (64x64)
   │             │
   │  Wall_01    │  ← Tile name
   │   Rot: 90°  │  ← Rotation indicator (↻ ↺)
   │  ★★★★☆      │  ← Fit quality (1-5 stars)
   │             │
   │ Conflicts:0 │  ← Constraint violations
   │ Fits: 4/6   │  ← Neighbor compatibility
   └─────────────┘
   ```
   
   States:
   - Default: Gray border
   - Hovered: Blue border, shows ghost in viewport
   - Selected: Green border (pre-selected best option)
   - Risky: Yellow/Orange border with warning icon

4. **Interactive Features:**
   - **Hover Preview:** Hovering option card shows ghost/transparent overlay in viewport
   - **Click to Select:** Click card to commit choice
   - **Keyboard Shortcuts:**
     - `Space` = Accept pre-selected (best) option
     - `1-9` = Quick select by card number
     - `A` = Auto-pick best option and continue
     - `S` = Skip (let solver decide later)
     - `←` = Step back (undo last choice)
   - **Auto-Continue Toggle:** Option to automatically step after manual choice

5. **Contextual Information Display:**
   - Cell coordinates (e.g., "Cell 5,2,1")
   - Option count (e.g., "3 options available")
   - Suggestion text (e.g., "Wall expected based on neighbors")
   - Conflict warnings (e.g., "⚠️ This choice may limit future options")
   - Decision counter (e.g., "Manual Choice 5 of ~12")

6. **Viewport Overlay Enhancements:**
   - Connection lines to adjacent tiles (color-coded)
     - 🟢 Green = Good fit (high compatibility)
     - 🟡 Yellow = Okay fit (medium compatibility)
     - 🔴 Red = Forced fit (low compatibility)
   - Constraint violation visualization (X marks on sockets)
   - Propagation preview (show what would collapse with this choice)

7. **Smart Defaults & AI Assistance:**
   - Pre-select most compatible option (highlighted in green)
   - Show fit quality score for each option (★ rating)
   - Option to show only "safe" choices (hide risky ones)
   - "Why this suggestion?" tooltip explaining the AI's reasoning

8. **Panel Controls:**
   - **Auto-Pick Button:** Let solver choose best option automatically
   - **Skip Button:** Defer decision (mark as backtrack point)
   - **Step Back Button:** Undo last manual choice and rewind
   - **Settings Cog:** Toggle preview mode, auto-continue, show risky options

**Interaction Flow:**
```
Step Mode Active
    ↓
Solver hits choice point (multiple valid options)
    ↓
Camera smoothly focuses on cell + highlight activates
    ↓
Choice panel slides up with animated entrance
    ↓
Best option pre-selected (highlighted)
    ↓
User hovers different options → Ghost preview in viewport
    ↓
User clicks option (or presses Space for default)
    ↓
Cell fills with chosen tile, panel slides down
    ↓
[If auto-continue enabled] → Continue solving
[Otherwise] → Wait for Step button
```

**Configuration Options:**
- **Panel Position:** Bottom (default), Side, Floating
- **Preview Style:** Ghost overlay (default), Full replacement, Split view
- **Auto-behaviors:** Auto-continue after choice, Auto-focus camera, Auto-pick best
- **Visualization:** Show connection lines, Show fit scores, Dim adjacent cells
- **Conflict Handling:** Hide risky options, Show warnings only, Show all

---

### Phase 4: Export to Scene 📤

**Goal:** Export generated structure to Godot scene

#### 4.1 Create SceneExportDialog (`ui/dialogs/scene_export_dialog.gd`)

Features:
- Export location picker
- Options:
  - Merge meshes (MultiMeshInstance3D)
  - Keep individual nodes
  - Include collision shapes
  - Generate navigation mesh
  - Optimize materials
- Preview structure outline
- "Export to Current Scene" vs "New Scene File"
- Post-export actions:
  - Open in editor
  - Add to current scene
  - Copy to clipboard (node path)

```gdscript
@tool
class_name SceneExportDialog extends AcceptDialog

signal scene_exported(scene_path: String, export_mode: ExportMode)

enum ExportMode {
    NEW_FILE,
    CURRENT_SCENE,
    CLIPBOARD
}

enum MeshMode {
    INDIVIDUAL_NODES,
    MERGED_MULTIMESH,
    MERGED_SINGLE_MESH
}
```

#### 4.2 Add Export Functionality to PreviewPanel

Add "Export" button:
- Opens SceneExportDialog
- Generates scene from current WfcGrid
- Applies transformations based on cell_world_size
- Creates proper node hierarchy

---

### Phase 5: Visual Flow Enhancements 🎨

**Goal:** Better visual feedback and workflow guidance

#### 5.1 Workflow Wizard Mode

Add optional "Guided Mode" toggle:
- Highlights next action (import → configure → preview → export)
- Shows tooltips and hints
- Disables out-of-sequence actions
- Progress indicator (Step 1 of 5)

#### 5.2 Enhanced Notifications

Create NotificationManager:
- Import summary: "5 tiles imported successfully"
- Validation warnings: "3 tiles missing sockets"
- Solver progress: "Solving... 45% complete (127/280 cells)"
- Export success: "Scene exported to res://structures/house_01.tscn"

#### 5.3 Keyboard Shortcuts

Add shortcuts:
- `Ctrl+I`: Import tiles
- `Ctrl+N`: New solver
- `Space`: Step forward (in step mode)
- `Ctrl+E`: Export scene
- `Ctrl+P`: Preview current tile
- `F5`: Regenerate (new seed)

---

## Implementation Priority

### 🚀 Phase 1 (High Priority - Core Workflow)
1. ✅ TileImportDialog with template selection
2. ✅ WFCConfigDialog for solver settings
3. ✅ Export to Scene functionality

### 🎯 Phase 2 (Medium Priority - Enhanced Features)
4. Step-through solver mode
5. Visual flow enhancements
6. Better notifications

### 💎 Phase 3 (Polish - Quality of Life)
7. Workflow wizard mode
8. Keyboard shortcuts
9. Preset management
10. Undo/redo for solver steps

---

## File Structure

```
addons/auto_structured/ui/
├── dialogs/
│   ├── tile_import_dialog.gd         # NEW
│   ├── tile_import_dialog.tscn       # NEW
│   ├── wfc_config_dialog.gd          # NEW
│   ├── wfc_config_dialog.tscn        # NEW
│   ├── scene_export_dialog.gd        # NEW
│   ├── scene_export_dialog.tscn      # NEW
│   ├── choice_selector_dialog.gd     # NEW (for step mode)
│   └── choice_selector_dialog.tscn   # NEW
├── panels/
│   ├── module_library_panel.gd       # ENHANCE
│   ├── preview_panel.gd              # ENHANCE
│   └── details_panel.gd              # Minor tweaks
├── controls/
│   ├── workflow_progress_bar.gd      # NEW
│   └── notification_toast.gd         # NEW
└── core/
    └── wfc/
        ├── solver_step_controller.gd # NEW
        └── scene_exporter.gd         # NEW
```

---

## Mock-up Flow

```
┌──────────────┐
│ 1. Create    │
│    Library   │  ← ModuleLibraryPanel
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 2. Import    │
│    Tiles     │  ← TileImportDialog (NEW)
│              │     • Select files
│              │     • Choose template
│              │     • Batch options
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 3. Configure │
│    Sockets   │  ← SocketSuggestionDialog (EXISTS)
│              │     • Auto-detect
│              │     • Apply template
│              │     • Manual edit
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 4. Preview   │
│    & Edit    │  ← DetailsPanel + PreviewPanel
│              │     • Modify specific tiles
│              │     • Test compatibility
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 5. Configure │
│    WFC       │  ← WFCConfigDialog (NEW)
│              │     • Grid size
│              │     • Seed
│              │     • Strategy
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 6. Generate  │
│    Structure │  ← PreviewPanel + SolverStepController (NEW)
│              │     • Auto solve
│              │     • Step through
│              │     • Manual choices
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 7. Export    │
│    Scene     │  ← SceneExportDialog (NEW)
│              │     • Choose format
│              │     • Set location
│              │     • Post-process
└──────────────┘
```

---

## Next Steps

**Start with Phase 1, Priority 1:**

1. Create `TileImportDialog` scene and script
2. Integrate with `ModuleLibraryPanel`
3. Create `WFCConfigDialog` scene and script
4. Update `PreviewPanel` to use config dialog
5. Implement basic scene export
6. Test complete workflow

Would you like me to start implementing these enhancements? I recommend starting with the TileImportDialog since it's the entry point of your workflow.
