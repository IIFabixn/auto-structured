# WFC Strategies

This folder contains the strategy system for Wave Function Collapse generation.

## Overview

Strategies determine which cells should be filled during WFC generation. This allows for different generation patterns like filling all cells, creating sparse structures, hollow interiors, or custom rules for specific use cases.

## Built-in Strategies

### WfcStrategyFillAll
Fills every cell in the grid. This is the default behavior.

### WfcStrategySparse
Randomly fills cells based on a configurable probability (0-100%). Useful for creating scattered or sparse structures.

### WfcStrategyPerimeter
Fills only the outer edges of the grid, leaving the interior hollow. Perfect for creating walls or boundaries.

### WfcStrategyGroundWalls
Fills ground level and perimeter walls. Ideal for house/building generation - creates a floor and outer walls with empty interior for rooms.

## Creating Custom Strategies

To create your own generation strategy:

1. Create a new `.gd` file in this folder (`strategies/`)
2. Extend `WfcStrategyBase`
3. Implement the required methods
4. **That's it!** Your strategy will be automatically discovered and added to the dropdown

Example:

```gdscript
@tool
extends "res://addons/auto_structured/core/wfc/strategies/wfc_strategy_base.gd"
class_name MyCustomStrategy

func should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool:
    # Your custom logic here
    # Return true to fill the cell, false to leave it empty
    
    # Example: Only fill cells at even coordinates
    return position.x % 2 == 0 and position.z % 2 == 0

func get_name() -> String:
    return "My Custom Strategy"

func get_description() -> String:
    return "Fills cells in a checkerboard pattern"
```

**The strategy will automatically appear in the Preview Panel's strategy dropdown!**

No need to modify any other code - just save your file in this folder and it will be discovered on plugin load.

### Required Methods

- `should_collapse_cell(position: Vector3i, grid_size: Vector3i) -> bool`
  - Called for each cell during generation
  - Return `true` to fill the cell with a tile
  - Return `false` to leave the cell empty

- `get_name() -> String`
  - Returns the display name for your strategy

- `get_description() -> String`
  - Returns a brief description of what your strategy does

### Optional Methods

- `initialize(grid_size: Vector3i) -> void`
  - Called before generation starts
  - Use for any setup needed

- `finalize() -> void`
  - Called after generation completes
  - Use for any cleanup needed

## Using Strategies

In the Preview Panel UI:

1. Select your desired strategy from the toolbar dropdown
2. Configure any strategy-specific options (like probability for Sparse - a dialog will appear automatically)
3. Click "New" to start generation with the selected strategy

The strategy will be applied during WFC generation, determining which cells get filled.

Strategies are automatically discovered from this folder, so any custom strategies you create will immediately appear in the dropdown!
