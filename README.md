# Sneaky Santa

A kid-friendly 2D stealth platformer. Santa slides down the chimney, sneaks through a dark three-storey house, leaves the presents under the tree and gets back up the chimney without being spotted by the family.

Vanilla JavaScript and Canvas 2D. No frameworks, no dependencies, no build step.

## Play

Open `index.html` through any web server (ES modules don't load from `file://`):

```sh
php -S localhost:8000
# or
python3 -m http.server
```

On an iPad, host it anywhere (GitHub Pages works), open it in Safari, then **Share → Add to Home Screen** to play full screen without browser bars.

## Controls

| Action | Touch | Keyboard | Gamepad |
| --- | --- | --- | --- |
| Walk | ◀ ▶ buttons (or drag on the left side) | ← → / A D | Left stick / D-pad |
| Jump | JUMP | Space | A |
| Hide, stairs, deliver, chimney | ACTION (label changes with context) | E, or ↑ ↓ | B / X, or D-pad up/down |
| Pause | Pause button | P / Esc | |

## How it plays

- Rooms stay dark until Santa opens their door. Opening a door wakes anyone asleep inside (Z's, then `!?!?`, then they get up).
- Each family member has a sight cone. Stay in it too long and you're spotted, which sends Santa back to the roof to start again.
- Hide in wardrobes, cupboards, under tables or behind the couch. Dark patches shrink how far people can see. Closed doors block sight.
- Cookies (kitchen) and milk (Mia's room) are optional bonus points.

## Code layout

```
index.html        Markup: canvas, HUD, touch buttons, start/end screens
css/style.css     Styles
src/
  main.js         Entry point: fixed-timestep loop (60 Hz update, interpolated render)
  config.js       Resolution (320×200), timestep, tuning numbers
  level.js        The house: floors, rooms, stairs, hiding spots, shadows, pickups
  state.js        Game state (S) and newGame()
  game.js         Santa: movement, stairs, hiding, interactions, per-step update
  npcs.js         Doors, sleepers waking, family patrols, getting spotted
  render.js       Draws the house into a low-res buffer, scaled to the screen
  sprites.js      Pixel sprites drawn from character maps
  audio.js        Sound effects synthesised with the Web Audio API
  input.js        Keyboard, touch, drag stick and gamepad
  ui.js           HUD, prompts, toasts, start/end screens, pause, fullscreen
  debug.js        Debug overlay (Debug button or the ` key)
  dom.js          Shared DOM handles
```

`S` in `state.js` is a single shared object that `newGame()` resets in place, so every module can import it once and always see the current run.

To add a room or hiding spot, edit `level.js` and add its drawing to `drawFurniture()` in `render.js`.
