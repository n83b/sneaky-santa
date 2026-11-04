import Foundation

// Draws the house in 320×200 logical pixels through a Painter.
// The SwiftUI Canvas supplies the real painter (see GameView.swift) and scales it up.

protocol Painter: AnyObject {
    /// Multiplies the alpha of everything drawn while it is below 1.
    var alpha: Double { get set }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: RGBA)
    func polygon(_ points: [(Double, Double)], _ c: RGBA)
    func circle(_ cx: Double, _ cy: Double, _ r: Double, _ c: RGBA)
    func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: RGBA)
    func verticalGradient(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ top: RGBA, _ bottom: RGBA)
}

struct Star {
    let x: Double
    let y: Double
    let t: Double
}

struct Renderer {
    let g: Game
    let p: Painter

    static let stars: [Star] = (0..<40).map { i in
        Star(x: Double((i * 73) % 320), y: Double((i * 37) % 30), t: Double(i) * 0.7)
    }

    /// Height of each hiding spot's drawn object, measured up from the floor.
    static let hideHeight: [HideKind: Double] = [
        .wardrobe: 30, .cupboard: 30, .pantry: 31, .boxes: 17, .desk: 18, .table: 13, .couch: 15,
    ]

    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: RGBA) {
        p.rect(x, y, w, h, c)
    }

    private func top(_ f: Int) -> Double { Level.ceiling(f) }
    private func fy(_ f: Int) -> Double { Level.floorY[f] }

    private func blit(_ s: Sprite, _ x: Double, _ y: Double, flip: Bool = false) {
        let runs = flip ? s.left : s.right
        for r in runs {
            p.rect(x + Double(r.x), y + Double(r.y), Double(r.len), 1, r.c)
        }
    }

    // MARK: - Frame

    func draw(alpha: Double) {
        sky()
        houseShell()
        for r in Level.rooms { room(r) }
        stairs()
        shadows()
        slabsAndWalls()
        // Dim every revealed room except the one Santa is in.
        for r in Level.rooms where r.id != g.roomId && g.revealed.contains(r.id) {
            rect(r.x0, top(r.floor), r.x1 - r.x0, fy(r.floor) - top(r.floor), RGBA(4, 6, 14, 0.35))
        }
        if g.phase == .play, let it = g.interaction { highlight(it) }
        for n in g.npcs { npc(n) }
        santa(alpha)
    }

    // MARK: - Outside

    private func sky() {
        rect(0, 0, Cfg.W, Cfg.H, "#070a14")
        p.verticalGradient(0, 0, Cfg.W, 40, "#0b1230", "#1a2146")
        for s in Renderer.stars where sin(g.time * 1.5 + s.t) > -0.6 {
            rect(s.x, s.y, 1, 1, "#c9d2ff")
        }
        // Crescent moon
        p.circle(40, 14, 7, "#f2ecd0")
        p.circle(43, 12, 6, "#0d1434")
        // Garden
        rect(0, fy(3) + 4, Cfg.W, Cfg.H - fy(3), "#121a17")
        rect(0, fy(3) + 4, Cfg.W, 2, "#1f2d24")
    }

    private func houseShell() {
        let x0 = Level.houseX0
        let x1 = Level.houseX1
        // Roof slab and tile edge
        rect(x0 - 6, fy(0), x1 - x0 + 12, 4, "#7a3b2e")
        for x in stride(from: x0 - 6, to: x1 + 6, by: 6.0) {
            rect(x, fy(0) + 3, 3, 1, "#5a2a22")
        }
        // Chimney
        let cx = Level.chimneyX
        rect(cx - 9, 16, 18, fy(0) - 16, "#8a4a3a")
        rect(cx - 11, 14, 22, 3, "#a65a46")
        for y in stride(from: 20.0, to: fy(0), by: 5.0) {
            rect(cx - 9, y, 18, 1, "#6e3a2e")
        }
        // Outer walls
        rect(x0 - 4, fy(0) + 4, 4, fy(3) - fy(0), "#3b3f55")
        rect(x1, fy(0) + 4, 4, fy(3) - fy(0), "#3b3f55")
    }

    // MARK: - Rooms

    private func room(_ r: Room) {
        let t0 = top(r.floor)
        let bot = fy(r.floor)
        let w = r.x1 - r.x0
        let h = bot - t0
        if !g.revealed.contains(r.id) {
            rect(r.x0, t0, w, h, "#06080f")
            return
        }
        rect(r.x0, t0, w, h, r.wall)
        rect(r.x0, bot - 3, w, 3, RGBA(0, 0, 0, 0.25))   // skirting
        furniture(r)
    }

    private func furniture(_ r: Room) {
        let f = r.floor
        let y = fy(f)
        switch r.id {
        case "kids":
            windowFrame(70, f)
            // Bed
            rect(24, y - 9, 34, 6, "#c86a8a")
            rect(24, y - 12, 6, 9, "#6b4a6a")
            rect(24, y - 3, 2, 3, "#4a3448")
            rect(56, y - 3, 2, 3, "#4a3448")
            rect(30, y - 11, 8, 3, "#f4f1ea")   // pillow
            // Bedside table with a glass of milk for Santa
            rect(61, y - 8, 12, 2, "#8a6a44")
            rect(62, y - 6, 2, 6, "#6a5030")
            rect(70, y - 6, 2, 6, "#6a5030")
            if !g.milk {
                rect(65, y - 14, 4, 6, "#f4f1ea")
                rect(65, y - 14, 4, 1, "#cfd8e0")
            }
            wardrobe(94, f, "#6a4a3a")

        case "hall3":
            picture(150, f)

        case "attic":
            fireplace(Level.chimneyX, f, attic: true)
            // Boxes
            rect(268, y - 10, 12, 10, "#8a6a44")
            rect(278, y - 16, 14, 16, "#9c7a50")
            rect(282, y - 12, 6, 1, "#6a5030")

        case "bath":
            // Bath tub and shower curtain
            rect(46, y - 9, 40, 9, "#d8e2ea")
            rect(48, y - 8, 36, 2, "#9fc4d8")
            let t = top(f)
            rect(22, t + 4, 22, y - t - 4, "#7aa8c4")
            for x in stride(from: 24.0, to: 44.0, by: 4.0) {
                rect(x, t + 4, 1, y - t - 4, "#5d8aa6")
            }

        case "landing":
            wardrobe(100, f, "#5a4a6a")
            windowFrame(126, f)

        case "leo":
            // Desk with a glowing monitor
            rect(214, y - 12, 24, 2, "#7a5a3a")
            rect(215, y - 10, 2, 10, "#5a4028")
            rect(235, y - 10, 2, 10, "#5a4028")
            rect(222, y - 17, 8, 5, "#2a2f44")
            rect(223, y - 16, 6, 3, "#4fa3c8")
            // Bed
            rect(262, y - 9, 36, 6, "#4f7ab8")
            rect(292, y - 13, 6, 10, "#3a4a6a")
            rect(286, y - 11, 6, 3, "#f4f1ea")

        case "kitchen":
            // Pantry
            rect(20, y - 30, 16, 30, "#6a5a3a")
            rect(33, y - 18, 2, 3, "#c8b070")
            // Table
            rect(58, y - 12, 32, 3, "#8a6a44")
            rect(60, y - 9, 2, 9, "#6a5030")
            rect(86, y - 9, 2, 9, "#6a5030")
            // Bench with the cookies, cupboard above
            rect(96, y - 14, 26, 14, "#7a6a52")
            rect(96, y - 14, 26, 2, "#bfb39a")
            rect(108, y - 34, 14, 12, "#556070")
            if !g.cookies {
                rect(98, y - 16, 8, 1, "#e8e2d4")
                rect(99, y - 18, 2, 2, "#c08850")
                rect(102, y - 18, 2, 2, "#c08850")
                rect(100, y - 20, 2, 2, "#c08850")
            }

        case "hall1":
            // Coat rack
            rect(188, y - 22, 2, 22, "#5a4028")
            rect(184, y - 22, 10, 2, "#5a4028")
            rect(184, y - 20, 4, 8, "#6a3a3a")

        case "lounge":
            fireplace(206, f, attic: false)
            // Couch
            rect(216, y - 10, 34, 10, "#7a3a44")
            rect(216, y - 14, 34, 5, "#8c4652")
            rect(214, y - 12, 4, 12, "#6a2e38")
            rect(248, y - 12, 4, 12, "#6a2e38")
            tree(f)

        default:
            break
        }
    }

    private func windowFrame(_ x: Double, _ f: Int) {
        let t = top(f)
        rect(x, t + 8, 18, 16, "#1b2a52")
        rect(x + 2, t + 10, 14, 12, "#2c4a8a")
        rect(x + 8, t + 8, 2, 16, "#1b2a52")
        rect(x, t + 15, 18, 2, "#1b2a52")
        rect(x + 3, t + 11, 2, 2, "#f2ecd0")   // moon glint
    }

    private func picture(_ x: Double, _ f: Int) {
        let t = top(f)
        rect(x, t + 12, 14, 10, "#6a5030")
        rect(x + 2, t + 14, 10, 6, "#4f7a8a")
    }

    private func wardrobe(_ x: Double, _ f: Int, _ c: RGBA) {
        let y = fy(f)
        rect(x, y - 30, 18, 30, c)
        rect(x + 8, y - 30, 1, 30, RGBA(0, 0, 0, 0.35))
        rect(x + 6, y - 16, 1, 3, "#d8c890")
        rect(x + 10, y - 16, 1, 3, "#d8c890")
    }

    private func fireplace(_ x: Double, _ f: Int, attic: Bool) {
        let y = fy(f)
        let brick: RGBA = attic ? "#6e3a2e" : "#8a4a3a"
        rect(x - 12, y - 20, 24, 20, brick)
        rect(x - 14, y - 22, 28, 3, "#b0a090")
        rect(x - 7, y - 13, 14, 13, "#1a0e0c")
        if !attic {
            // Embers
            let ember: RGBA = sin(g.time * 6) > 0 ? "#e86a2a" : "#c84a1a"
            rect(x - 4, y - 3, 8, 3, ember)
            rect(x - 2, y - 5, 3, 2, "#f3c35a")
        }
    }

    private func tree(_ f: Int) {
        let y = fy(f)
        let x = Level.treeX
        rect(x - 2, y - 6, 4, 6, "#5a3a22")
        for i in 0..<3 {
            let ty = y - 8 - Double(i) * 8
            let half = 13 - Double(i) * 3
            p.polygon([(x - half, ty), (x + half, ty), (x, ty - 12)], "#2f7a4a")
        }
        let blink = Int(floor(g.time * 2)) % 2
        let lights: [(RGBA, Double, Double)] = [
            (RGBA("#f3c35a"), -6, -12),
            (RGBA("#d8433b"), 5, -15),
            (RGBA("#7ab8ff"), -3, -21),
            (RGBA("#f3c35a"), 3, -26),
            (RGBA("#d8433b"), -7, -10),
        ]
        for (i, light) in lights.enumerated() {
            let c: RGBA = (i + blink) % 2 == 1 ? light.0 : "#ffffff"
            rect(x + light.1, y + light.2, 1, 1, c)
        }
        rect(x - 1, y - 40, 3, 3, "#f3c35a")   // star
        if g.delivered {
            rect(x - 15, y - 6, 8, 6, "#d8433b")
            rect(x - 12, y - 6, 2, 6, "#f3c35a")
            rect(x + 6, y - 5, 7, 5, "#4fa3c8")
            rect(x + 9, y - 5, 1, 5, "#f4f1ea")
            rect(x - 6, y - 4, 5, 4, "#9b6ad8")
        }
    }

    private func shadows() {
        for z in Level.shadows {
            guard let r = Level.roomAt(z.floor, z.x0 + 1), g.revealed.contains(r.id) else { continue }
            rect(z.x0, top(z.floor), z.x1 - z.x0, fy(z.floor) - top(z.floor), RGBA(2, 4, 10, 0.55))
        }
    }

    // MARK: - Stairs, floors, doors

    private func isRevealed(_ floor: Int, _ x: Double) -> Bool {
        guard let r = Level.roomAt(floor, x) else { return false }
        return g.revealed.contains(r.id)
    }

    private func stairs() {
        let bob = sin(g.time * 4).rounded()
        for st in Level.stairs {
            let lowSeen = isRevealed(st.lower, st.bottom)
            let upSeen = isRevealed(st.lower - 1, st.top)
            let y0 = fy(st.lower)
            let y1 = fy(st.lower - 1)
            let n = Level.stairSteps
            let dx = (st.top - st.bottom) / Double(n)
            let dy = (y1 - y0) / Double(n)
            let w = Level.wellRange(st)

            if lowSeen {
                // Steps, filled down to the floor so the flight reads as solid.
                for i in 0..<n {
                    let x = st.bottom + dx * Double(i)
                    let y = y0 + dy * Double(i + 1)
                    let sx = min(x, x + dx)
                    let sw = ceil(abs(dx)) + 1
                    let c: RGBA = i % 2 == 1 ? "#5a4a3a" : "#66543f"
                    rect(sx, y, sw, y0 - y, c)
                    rect(sx, y, sw, 1, "#8a7258")   // tread edge
                }
                // Banister and posts
                p.line(st.bottom + 0.5, y0 - 10.5, st.top + 0.5, y1 - 10.5, "#a0845c")
                for i in stride(from: 0, through: n, by: 2) {
                    let x = (st.bottom + dx * Double(i)).rounded()
                    let y = y0 + dy * Double(i)
                    rect(x, y - 10, 1, 10, "#7a6448")
                }
                rect(st.bottom, y0 - 12, 2, 12, "#a0845c")   // newel post
                blit(Sprites.arrowUp, st.bottom - 1, y0 - 20 + bob)
            }

            if upSeen {
                // Dark gap if the room below is still unexplored.
                if !lowSeen { rect(w.0, y1, w.1 - w.0, 4, "#06080f") }
                // Railing around the stairwell on the upper floor.
                let rx0 = min(w.0, w.1)
                let rx1 = max(w.0, w.1)
                rect(rx0, y1 - 9, rx1 - rx0, 1, "#a0845c")
                for x in stride(from: rx0, through: rx1, by: 3.0) {
                    rect(x, y1 - 8, 1, 8, "#7a6448")
                }
                let risesRight = st.top > st.bottom
                let far = risesRight ? rx0 - 1 : rx1
                rect(far, y1 - 11, 2, 11, "#a0845c")
                blit(Sprites.arrowDown, st.top - 1, y1 - 20 + bob)
            }
        }
    }

    private func slabsAndWalls() {
        for f in 1...3 {
            // Cut the stairwell openings out of this floor's slab.
            let gaps = Level.stairs
                .filter { $0.lower - 1 == f }
                .map { Level.wellRange($0) }
                .sorted { $0.0 < $1.0 }
            var x = Level.houseX0 - 4
            for gap in gaps {
                rect(x, fy(f), gap.0 - x, 4, "#4a4f68")
                x = gap.1
            }
            rect(x, fy(f), Level.houseX1 + 4 - x, 4, "#4a4f68")
        }
        for r in Level.rooms where r.x1 < Level.houseX1 {
            let t = top(r.floor)
            rect(r.x1 - 1, t, 3, fy(r.floor) - t - 20, "#3b3f55")   // wall above the doorway
        }
        for d in g.doors { door(d) }
    }

    private func door(_ d: Door) {
        let y = fy(d.floor)
        let t = y - 20
        rect(d.x - 2, t - 1, 5, 1, "#2a2d40")   // lintel
        if !d.open {
            rect(d.x - 1, t, 3, 20, "#6e4c30")
            rect(d.x - 1, t + 2, 3, 1, "#4e3420")
            rect(d.x - 1, t + 11, 3, 1, "#4e3420")
            rect(d.x + (d.side > 0 ? 1 : -1), y - 10, 1, 1, "#f3c35a")   // knob
            return
        }
        // Swung open into the room it leads to, seen at an angle.
        let w = (2 + 6 * d.anim).rounded()
        let hinge = d.side > 0 ? d.x + 1 : d.x - 1
        let x0 = d.side > 0 ? hinge : hinge - w + 1
        rect(x0, t + 1, w, 19, "#7c5a3a")
        rect(d.side > 0 ? x0 + w - 1 : x0, t + 1, 1, 19, "#9a7650")   // lit edge
        rect(hinge, t, 1, 20, "#4e3420")
    }

    // MARK: - Action highlight

    private func bounds(_ it: Interaction) -> (x0: Double, y0: Double, x1: Double, y1: Double)? {
        let pad = Level.stairPad
        switch it.kind {
        case .hide, .unhide:
            guard let h = it.hide ?? g.santa.hide else { return nil }
            let y = fy(h.floor)
            let ht = Renderer.hideHeight[h.kind] ?? (y - top(h.floor) - 4)
            return (h.x0, y - ht, h.x1, y)
        case .stairsUp:
            guard let st = it.stair else { return nil }
            return (min(st.bottom, st.top) - pad, fy(st.lower - 1) - 2, max(st.bottom, st.top) + pad, fy(st.lower))
        case .stairsDown:
            guard let st = it.stair else { return nil }
            let w = Level.wellRange(st)
            let y = fy(st.lower - 1)
            return (min(w.0, w.1) - pad, y - 12, max(w.0, w.1) + pad, y + 4)
        case .chimneyDown:
            return (Level.chimneyX - 12, 13, Level.chimneyX + 12, fy(0))
        case .escape:
            return (Level.chimneyX - 15, fy(1) - 23, Level.chimneyX + 15, fy(1))
        case .deliver:
            let y = fy(Level.treeFloor)
            return (Level.treeX - 16, y - 42, Level.treeX + 16, y)
        }
    }

    private func highlight(_ it: Interaction) {
        guard let r = bounds(it) else { return }
        let resting = it.kind == .unhide
        let pulse = 0.55 + 0.35 * sin(g.time * 6)
        let x0 = r.x0.rounded() - 1
        let y0 = r.y0.rounded() - 1
        let x1 = r.x1.rounded() + 1
        let y1 = r.y1.rounded()
        let w = x1 - x0
        let h = y1 - y0
        let l = min(5, floor(w / 3), floor(h / 3))
        // Soft glow over the object
        rect(x0, y0, w, h, RGBA(243, 195, 90, resting ? 0.04 : 0.09 * pulse))
        // Pixel corner brackets
        p.alpha = resting ? 0.35 : pulse
        let c: RGBA = "#f3c35a"
        rect(x0, y0, l, 1, c)
        rect(x0, y0, 1, l, c)
        rect(x1 - l, y0, l, 1, c)
        rect(x1 - 1, y0, 1, l, c)
        rect(x0, y1 - 1, l, 1, c)
        rect(x0, y1 - l, 1, l, c)
        rect(x1 - l, y1 - 1, l, 1, c)
        rect(x1 - 1, y1 - l, 1, l, c)
        p.alpha = 1
    }

    // MARK: - Characters

    private func hiddenEyes(_ h: HideSpot) {
        // Two peeking eyes where Santa is hiding
        let cx = (h.x0 + h.x1) / 2
        let y = fy(h.floor)
        let blink = Int(floor(g.time * 1.3)) % 4 == 0
        if !blink {
            rect(cx - 2, y - 7, 1, 1, "#f4f1ea")
            rect(cx + 1, y - 7, 1, 1, "#f4f1ea")
        }
    }

    private func santa(_ alpha: Double) {
        let s = g.santa
        if s.mode == .hidden, let h = s.hide {
            hiddenEyes(h)
            return
        }
        if s.inv > 0 && Int(floor(g.time * 12)) % 2 == 1 { return }
        let x = s.px + (s.x - s.px) * alpha
        let y = s.py + (s.y - s.py) * alpha
        let moving = abs(s.vx) > 4 || s.mode == .tween
        let frame = moving ? Int(floor(s.anim)) % 2 : 0
        let img = Sprites.santa[frame]
        // Out of sight inside the chimney stack while sliding.
        if s.mode == .tween && s.floor == 0 && y < fy(0) - 8 { return }
        if !g.delivered {
            rect(x.rounded() - s.face * 5 - 2, y.rounded() - 9, 4, 6, "#8a5a32")   // sack
        }
        blit(img, (x - Double(img.w) / 2).rounded(), (y - Double(img.h)).rounded(), flip: s.face < 0)
    }

    /// "!?!?" above a startled character, centred on cx; each mark bobs on its own beat.
    private func alarm(_ cx: Double, _ topY: Double) {
        let marks = [Sprites.bang, Sprites.question, Sprites.bang, Sprites.question]
        let width = marks.reduce(-1) { $0 + $1.w + 1 }
        var x = (cx - Double(width) / 2).rounded()
        for (i, m) in marks.enumerated() {
            let bob = (sin(g.time * 14 + Double(i) * 1.3) * 1.2).rounded()
            blit(m, x, topY + bob)
            x += Double(m.w + 1)
        }
    }

    private func npcVisible(_ n: NPC) -> Bool {
        if isRevealed(n.floor, n.x) { return true }
        let s = g.santa
        return n.floor == s.floor && abs(n.x - s.x) < 80 && !g.doorBetween(n.floor, n.x, s.x)
    }

    private func npc(_ n: NPC) {
        guard npcVisible(n) else { return }
        let y = fy(n.floor)

        if n.state == .asleep || (n.state == .stir && n.stirPhase == .zz) {
            // Head on the pillow and rising Z's (two, quicker, once a door has disturbed her).
            rect(31, y - 13, 5, 4, "#e8c25a")
            rect(32, y - 12, 3, 2, "#f0b48c")
            let fast = n.state == .stir
            let speed: Double = fast ? 9 : 4
            let count = fast ? 2 : 1
            for i in 0..<count {
                let t = (g.time * speed + Double(i) * 4).truncatingRemainder(dividingBy: 8)
                p.alpha = 0.85 * (1 - t / 8)
                blit(Sprites.zed, 38 + (t / 3).rounded(), (y - 17 - t).rounded())
            }
            p.alpha = 1
            return
        }
        if n.state == .stir {
            // Sitting bolt upright in bed with "!?!?" bouncing above her head.
            rect(30, y - 18, 6, 4, "#e8c25a")
            rect(31, y - 16, 4, 3, "#f0b48c")
            rect(30, y - 13, 6, 4, "#e58fb1")
            rect(32, y - 15, 1, 1, "#1a1420")
            rect(34, y - 15, 1, 1, "#1a1420")
            alarm(33, y - 27)
            return
        }

        // Vision cone, cut short by a closed door.
        let eyeY = y - n.height + 3
        var range = Cfg.sightRange
        for d in g.doors where !d.open && d.floor == n.floor && (d.x - n.x) * n.dir > 0 {
            range = min(range, abs(d.x - n.x))
        }
        let edge = n.x + n.dir * range
        let coneTop = max(top(n.floor), eyeY - 12)
        p.polygon([(n.x, eyeY), (edge, coneTop), (edge, y)], RGBA(255, 226, 150, 0.10 + n.sus * 0.22))

        let frame = n.state == .walk ? Int(floor(n.anim)) % 2 : 0
        let img = n.frames[frame]
        blit(img, (n.x - Double(img.w) / 2).rounded(), y - Double(img.h), flip: n.dir < 0)
        if g.phase == .caught && g.caughtBy === n {
            blit(Sprites.bang, n.x.rounded(), y - n.height - 8)
        } else if n.sus > 0.05 {
            blit(Sprites.question, (n.x - 1).rounded(), y - n.height - 8)
        }
    }
}
