<!-- 206c715c-0c81-48e0-8736-2e11386965ff 2fbc281b-f974-4180-ad53-e030e53df504 -->
# Add Floating Text Feedback for Cycling Zone Clicks

## Overview

Create a floating text system that appears when clicking cycling zones, showing the quality rating and XP earned with color-coded text.

## Implementation Steps

### 1. Create Floating Text Scene

Create `scenes/ui/floating_text/floating_text.tscn` and `floating_text.gd`:

- Label node for displaying text
- AnimationPlayer or Tween for float-up animation
- Auto-free after animation completes
- Configurable text, color, and position

### 2. Floating Text Script Logic

In `floating_text.gd`:

- `show_text(text: String, color: Color, position: Vector2)` function
- Float upward animation (move up ~50-100 pixels)
- Fade out animation
- Duration: ~1-2 seconds
- Auto `queue_free()` when complete

### 3. Integrate with Cycling Technique

In `cycling_technique.gd`:

- Preload the floating text scene
- In `_handle_zone_click()`: spawn floating text at zone position
- Pass quality text (e.g., "PERFECT +10 XP"), color, and position
- Handle missed clicks in `_on_zone_clicked()` or similar

### 4. Handle Missed Clicks

- Track when zones are exited without being clicked
- Show "MISSED" in red at the zone's position
- This may require tracking active zones and checking on exit

### 5. Color Mapping

- **PERFECT**: Gold (`Color.GOLD` or `Color(1.0, 0.84, 0.0)`)
- **GOOD**: Green (`Color.GREEN` or `Color(0.0, 1.0, 0.0)`)
- **OK**: White (`Color.WHITE`)
- **MISSED**: Red (`Color.RED`)

## Files to Create/Modify

### New Files:

- `scenes/ui/floating_text/floating_text.tscn`
- `scenes/ui/floating_text/floating_text.gd`

### Modified Files:

- `scenes/game_systems/cycling/cycling_technique/cycling_technique.gd`
  - Add preload for floating text scene
  - Spawn floating text in `_handle_zone_click()`
  - Add logic for missed click detection

## Technical Details

### Floating Text Animation

```gdscript
# Example animation approach
var tween = create_tween()
tween.parallel().tween_property(self, "position:y", position.y - 100, 1.5)
tween.parallel().tween_property(self, "modulate:a", 0.0, 1.5)
tween.finished.connect(queue_free)
```

### Text Format

- Success: "{QUALITY} +{XP} XP" (e.g., "PERFECT +10 XP")
- Missed: "MISSED"