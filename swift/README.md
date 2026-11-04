# Sneaky Santa for Swift Playgrounds

A native Swift port of Sneaky Santa, packaged as a Swift Playgrounds app project (`SneakySanta.swiftpm`). It plays the same as the web version: same house, rules, scoring and sound effects.

## Open it on iPad

1. Copy `SneakySanta.swiftpm` (or the zip, then tap it to unzip) into iCloud Drive or On My iPad using the Files app.
2. Tap `SneakySanta.swiftpm`. It opens in Swift Playgrounds.
3. Tap ▶ Run. Use the app preview's full-screen button to play without the editor.

From Playgrounds you can also install it on the iPad's Home Screen (App Settings → Install on This iPad, or the ⋯ menu, depending on your Playgrounds version) and give it a custom icon in App Settings.

## Controls

| Action | Touch | Keyboard | Game controller |
| --- | --- | --- | --- |
| Walk | ◀ ▶ (hold) | ← → / A D | Left stick / D-pad |
| Jump | JUMP | Space / Z | A |
| Hide, stairs, deliver, chimney | ACTION (label changes with context) | E / Return / X, or ↑ ↓ | B / X, or D-pad up/down |
| Pause | Pause button | P / Esc | Menu |

Return, Space or A also starts a run from the title and end screens. Your best score and the mute setting are saved on the device.

## Code layout

```
Package.swift          App definition for Swift Playgrounds / Xcode
SneakySantaApp.swift   @main app entry
ContentView.swift      SwiftUI screen: canvas, HUD, touch controls, start and end cards
GameController.swift   60 Hz loop (CADisplayLink), touch/keyboard/gamepad input, HUD publishing, Canvas painter
Game.swift             State, Santa's movement, stairs, hiding, interactions, scoring
Family.swift           Doors, Mia waking up, family patrols, getting spotted
Level.swift            Tuning numbers and the house layout
Renderer.swift         Draws the house in 320×200 logical pixels through a Painter
Sprites.swift          Pixel sprites from character maps
Colour.swift           RGBA colours written as "#rrggbb"
Synth.swift            Sound effects synthesised with AVAudioEngine (no audio files)
```

The game logic (`Game`, `Family`, `Level`, `Renderer`, `Sprites`, `Colour`) uses only Foundation, so you can change rules or layout without touching the UI. To add a room or hiding spot, edit `Level.swift` and draw its furniture in `Renderer.furniture(_:)`.
