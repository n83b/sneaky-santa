# Sneaky Santa for Defold

A Defold port of Sneaky Santa: same house, rules, scoring and sound effects as the web version, built from sprites, a GUI scene and Lua scripts. It was built and checked with Defold 1.14.0.

## Open it

1. In the Defold editor, choose **Open From Disk…** and pick this folder's `game.project`.
2. Press **Project → Build** (⌘B / Ctrl+B) to play.

The window opens at 960×640. The game itself is 320×200 pixels and is scaled up by a whole number with nearest-neighbour filtering, so the pixels stay crisp. The custom render script in `render/` handles that.

## Controls

| Action | Touch / mouse | Keyboard | Gamepad |
| --- | --- | --- | --- |
| Walk | ◀ ▶ (hold) | ← → / A D | Left stick / D-pad |
| Jump | JUMP | Space / Z | A (bottom face button) |
| Hide, stairs, deliver, chimney | ACTION (label changes) | E / X / Enter, or ↑ ↓ | B / X, or D-pad up/down |
| Pause | Pause button | P / Esc | Start |

Enter, Space or A also starts a run from the title and end screens. The best score and the mute setting are saved with `sys.save`.

## How it's put together

```
game.project              Project settings (960×640 window, nearest filtering, pixel render script)
main/main.collection      Every sprite in the scene, already placed: house layers, doors, family, Santa
main/game.script          Runs the game: input → rules at 60 Hz → sprites, sounds and HUD
main/hud.gui              HUD layout: score, buttons, prompt, toast, start and end cards
main/hud.gui_script       HUD updates and multi-touch buttons
modules/level.lua         The house layout and tuning numbers (speeds, sight range, timings)
modules/game.lua          The rules: Santa, stairs, hiding, doors, family patrols, getting spotted, scoring
modules/art.lua           Image sizes and draw depths used by game.script
render/pixel.render_script  Whole-number scaling of the 320×200 world, GUI over the full window
input/game.input_binding  Keyboard, mouse, multi-touch and gamepad bindings
assets/game.atlas         All sprites and flipbooks (stars, embers, tree lights, doors, "!?!?")
assets/images/            The art as PNGs
assets/sounds/            The sound effects as WAVs
assets/fonts/             UI font (DejaVu Sans Bold, licence alongside)
```

**Coordinates.** The rules in `modules/` use the web version's coordinates: 320×200 with y pointing down. `game.script` flips y when it places sprites (`place()`), so the numbers in `level.lua` match the original code.

**Art.** Each room is its own sprite and stays hidden until Santa opens its door. The stairs, railings, shadows and room items (milk, cookies, presents, embers, tree lights) are separate sprites that switch on with their room. To change the look, edit the PNGs in `assets/images` and keep each image the same size, or move the object in `main.collection` to match.

**Sound.** The WAVs were rendered from the original synthesiser and are stored louder than they play. Each sound component in the `game` object has gain 0.25, which matches the web version's volume. Replace a WAV to swap in your own recording; sounds are played by name from `game.script` (`snd_<name>`).

**Rules and tuning.** `modules/game.lua` is plain Lua with no engine calls, so you can change rules there and in `level.lua` without touching the scene.
