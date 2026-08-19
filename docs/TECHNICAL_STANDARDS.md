# Mesoplasia RPG Technical Standards

## Technology Baseline

- Engine: Godot 4.7.
- Project type: 2D top-down fantasy RPG.
- Scripting language: GDScript.
- Renderer: Compatibility. Changing the renderer requires explicit approval.
- Input code must use named Godot Input Map actions rather than hard-coded keyboard checks.

## Display and Pixel Art

- The primary internal game resolution is `640 × 360` pixels (`16:9`).
- The initial desktop test window is `1280 × 720` pixels, an exact 2× scale of the internal resolution.
- The project uses `viewport` stretch mode, `keep` stretch aspect, and `integer` stretch scale mode.
- Layouts and presentation should support clean integer scaling to larger `16:9` displays.
- Pixel-art textures use nearest-neighbor filtering by default rather than smoothing.
- Pixel-art source assets should normally be imported without filtering or mipmaps unless a specific asset has different requirements.

Together, the low-resolution viewport, aspect preservation, integer scaling, and nearest-neighbor filtering are intended to preserve a consistent pixel-art presentation with cleanly scaled pixels.

## World and Character Scale

- The initial world tile standard is `32 × 32` pixels.
- Character gameplay footprints should be designed around the `32 × 32` tile grid.
- Visible character sprites may extend beyond one tile when their design or animation requires it; visual bounds do not need to equal the gameplay footprint.

## Movement Direction Standard

- Initial movement is top-down and four-directional.
- Future movement code and animation organization should avoid assumptions that prevent adding eight-direction movement later.
- No movement implementation is part of this baseline.

## Input Actions

The initial keyboard bindings are provisional and may change as controls are tested. Letter-key bindings use physical key positions so the WASD layout remains spatially consistent across keyboard layouts.

| Action | Temporary keyboard bindings | Intended role |
| --- | --- | --- |
| `move_up` | W, Up Arrow | Move north/up |
| `move_down` | S, Down Arrow | Move south/down |
| `move_left` | A, Left Arrow | Move west/left |
| `move_right` | D, Right Arrow | Move east/right |
| `interact` | E | Interact or confirm in the game world |
| `attack` | Space | Primary attack or primary action |
| `secondary_action` | Q | Context-dependent secondary action |
| `pause` | Escape | Pause or open the pause menu |

These named actions provide the device-independent boundary needed for controller support. Controller bindings and controller-specific behavior are intentionally deferred until their desired layout and gameplay semantics are approved; gameplay code should consume these actions without depending on a particular input device.
