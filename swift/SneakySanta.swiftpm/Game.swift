import Foundation

// Santa: game state, movement, stairs, hiding, interactions and the per-step update.
// Plain Swift with no UI code, so the rules can be read and tuned in one place.

enum GamePhase {
    case title, play, paused, caught, won
}

enum SantaMode {
    case walk, tween, hidden
}

/// A scripted move (chimney, stairs) from one point to another over `dur` seconds.
struct Tween {
    var x0: Double
    var y0: Double
    var x1: Double
    var y1: Double
    var t: Double = 0
    var dur: Double
    var done: (() -> Void)?
}

struct SantaState {
    var floor = 0
    var x: Double = 60
    var y: Double = 34
    var px: Double = 60
    var py: Double = 34
    var vx: Double = 0
    var vy: Double = 0
    var face: Double = 1
    var onGround = true
    var mode: SantaMode = .walk
    var anim: Double = 0
    var hide: HideSpot? = nil
    var tween: Tween? = nil
    /// Flashing invulnerability (unused after restarts, kept for tuning).
    var inv: Double = 0
    /// Short moment after arriving on a floor when nobody can spot Santa.
    var grace: Double = 0
    var stepAcc: Double = 0
}

/// Button presses waiting to be handled. Edge flags are cleared once used.
struct Controls {
    var axisX: Double = 0
    var jump = false
    var action = false
    var up = false
    var down = false

    mutating func consume() {
        jump = false
        action = false
        up = false
        down = false
    }
}

enum InteractionKind {
    case unhide, hide, chimneyDown, deliver, escape, stairsUp, stairsDown
}

/// Which extra key (besides ACTION) triggers an interaction.
enum Trigger {
    case any, up, down, action
}

struct Interaction {
    let kind: InteractionKind
    let label: String
    let trigger: Trigger
    var stair: Stair? = nil
    var hide: HideSpot? = nil
}

struct ScoreRow: Equatable {
    let label: String
    let points: Int
}

struct EndResult: Equatable {
    let title: String
    let text: String
    let rows: [ScoreRow]
    let total: Int
    /// Previous best to show, or 0 for a first win.
    let best: Int
}

/// Every sound the game asks for. `Synth` plays them; `NoSound` keeps quiet.
protocol SoundEffects: AnyObject {
    func step(roof: Bool)
    func jump()
    func land()
    func hide()
    func unhide()
    func creak()
    func door(soft: Bool)
    func chimney()
    func escape()
    func deliver()
    func cookie()
    func milk()
    func notice()
    func caught()
    func wake()
    func win()
}

final class NoSound: SoundEffects {
    func step(roof: Bool) {}
    func jump() {}
    func land() {}
    func hide() {}
    func unhide() {}
    func creak() {}
    func door(soft: Bool) {}
    func chimney() {}
    func escape() {}
    func deliver() {}
    func cookie() {}
    func milk() {}
    func notice() {}
    func caught() {}
    func wake() {}
    func win() {}
}

final class Game {
    let sfx: SoundEffects

    // Survives restarts
    var attempt = 1
    var best = 0

    // One run (reset by resetRun())
    var phase: GamePhase = .title
    var time: Double = 0
    var playTime: Double = 0
    var score = 0
    var delivered = false
    var cookies = false
    var milk = false
    var revealed = Set<String>()
    var roomId: String? = nil
    var toastText: String? = nil
    var toastT: Double = 0
    var santa = SantaState()
    var doors: [Door] = []
    var npcs: [NPC] = []
    var caughtT: Double = 0
    var caughtBy: NPC? = nil
    var miaWakeIn: Double? = nil
    var interaction: Interaction? = nil
    var input = Controls()
    var end: EndResult? = nil

    init(sound: SoundEffects) {
        sfx = sound
        resetRun()
    }

    // MARK: - Runs

    func resetRun() {
        phase = .title
        time = 0
        playTime = 0
        score = 0
        delivered = false
        cookies = false
        milk = false
        revealed = []
        roomId = nil
        toastText = nil
        toastT = 0
        santa = SantaState()
        santa.y = Level.floorY[0]
        santa.py = santa.y
        // A door sits in every doorway between two rooms on the same floor.
        doors = Level.rooms.filter { $0.x1 < Level.houseX1 }.map { Door(floor: $0.floor, x: $0.x1) }
        npcs = NPC.family()
        caughtT = 0
        caughtBy = nil
        miaWakeIn = nil
        interaction = nil
        input = Controls()
        end = nil
    }

    func start() {
        attempt = 1
        resetRun()
        phase = .play
        toast("Walk to the chimney, then tap ACTION", 2.6)
    }

    /// Getting caught restarts the whole run: back on the roof, rooms dark again,
    /// presents back in the sack and the snacks back where they were.
    func respawn() {
        attempt += 1
        resetRun()
        phase = .play
        toast("Attempt \(attempt) · Walk to the chimney, then tap ACTION", 2.4)
    }

    func setPaused(_ paused: Bool) {
        guard phase == .play || phase == .paused else { return }
        phase = paused ? .paused : .play
        if paused {
            toast("Paused", 999)
        } else {
            toastText = nil
            toastT = 0
        }
    }

    func toast(_ msg: String, _ secs: Double = 2.2) {
        toastText = msg
        toastT = secs
    }

    var objective: String {
        var o = "Slide down the chimney"
        if santa.floor > 0 || !revealed.isEmpty {
            o = delivered ? "Get back up the chimney" : "Find the Christmas tree"
        }
        return o + (cookies && milk ? " · snack found" : "")
    }

    // MARK: - Moves

    private func landed() {
        santa.mode = .walk
        santa.onGround = true
        santa.grace = 0.8
    }

    private func tweenSanta(_ x1: Double, _ y1: Double, _ dur: Double, _ done: @escaping () -> Void) {
        santa.tween = Tween(x0: santa.x, y0: santa.y, x1: x1, y1: y1, dur: dur, done: done)
        santa.mode = .tween
        santa.vx = 0
        santa.vy = 0
    }

    /// Walk Santa along the floor to x, then run `then` (used to reach the end of a staircase).
    private func walkTo(_ x: Double, _ y: Double, then: @escaping () -> Void) {
        let d = abs(x - santa.x)
        if d < 1.5 {
            santa.x = x
            santa.y = y
            then()
            return
        }
        santa.face = x > santa.x ? 1 : -1
        santa.y = y
        tweenSanta(x, y, d / 70, then)
    }

    // MARK: - Interactions

    func currentInteraction() -> Interaction? {
        let s = santa
        if s.mode == .hidden {
            return Interaction(kind: .unhide, label: "Come out", trigger: .any)
        }
        if s.mode != .walk || !s.onGround { return nil }

        if s.floor == 0 && s.x >= Level.chimneyRoofX0 && s.x <= Level.chimneyRoofX1 {
            return Interaction(kind: .chimneyDown, label: "Slide down chimney", trigger: .down)
        }
        if s.floor == Level.treeFloor && s.x >= Level.treeX0 && !delivered {
            return Interaction(kind: .deliver, label: "Deliver presents", trigger: .action)
        }
        if s.floor == 1 && delivered && s.x >= 236 && s.x <= 262 {
            return Interaction(kind: .escape, label: "Escape up chimney", trigger: .up)
        }

        let pad = Level.stairPad
        for st in Level.stairs {
            // Anywhere along the flight (downstairs) or over the stairwell opening (upstairs) counts.
            let fx0 = min(st.bottom, st.top) - pad
            let fx1 = max(st.bottom, st.top) + pad
            if s.floor == st.lower && s.x >= fx0 && s.x <= fx1 {
                return Interaction(kind: .stairsUp, label: "Go upstairs", trigger: .up, stair: st)
            }
            let w = Level.wellRange(st)
            let wx0 = min(w.0, w.1) - pad
            let wx1 = max(w.0, w.1) + pad
            if s.floor == st.lower - 1 && s.x >= wx0 && s.x <= wx1 {
                return Interaction(kind: .stairsDown, label: "Go downstairs", trigger: .down, stair: st)
            }
        }

        if let h = Level.hides.first(where: { $0.floor == s.floor && s.x >= $0.x0 && s.x <= $0.x1 }) {
            return Interaction(kind: .hide, label: h.label, trigger: .down, hide: h)
        }
        return nil
    }

    private func doInteraction(_ it: Interaction) {
        switch it.kind {
        case .unhide:
            santa.mode = .walk
            santa.hide = nil
            sfx.unhide()

        case .hide:
            guard let h = it.hide else { break }
            sfx.hide()
            santa.mode = .hidden
            santa.hide = h
            santa.vx = 0
            santa.x = (h.x0 + h.x1) / 2

        case .chimneyDown:
            sfx.chimney()
            tweenSanta(Level.chimneyX, 14, 0.35) { [unowned self] in
                self.santa.floor = 1
                self.santa.x = Level.chimneyX
                self.santa.y = Level.floorY[1] - 30
                self.santa.px = self.santa.x
                self.santa.py = self.santa.y
                self.tweenSanta(Level.chimneyX, Level.floorY[1], 0.5) { [unowned self] in
                    self.landed()
                }
            }

        case .escape:
            sfx.escape()
            tweenSanta(Level.chimneyX, Level.floorY[1] - 30, 0.5) { [unowned self] in
                self.santa.floor = 0
                self.santa.x = Level.chimneyX
                self.santa.y = 14
                self.santa.px = self.santa.x
                self.santa.py = self.santa.y
                self.tweenSanta(Level.chimneyX, Level.floorY[0], 0.35) { [unowned self] in
                    self.santa.mode = .walk
                    self.win()
                }
            }

        case .stairsUp:
            guard let st = it.stair else { break }
            sfx.creak()
            walkTo(st.bottom, Level.floorY[st.lower]) { [unowned self] in
                self.santa.face = st.top > st.bottom ? 1 : -1
                self.tweenSanta(st.top, Level.floorY[st.lower - 1], 0.7) { [unowned self] in
                    self.santa.floor = st.lower - 1
                    self.landed()
                }
            }

        case .stairsDown:
            guard let st = it.stair else { break }
            sfx.creak()
            walkTo(st.top, Level.floorY[st.lower - 1]) { [unowned self] in
                // Switch floor now so the climb down renders inside the lower room.
                self.santa.floor = st.lower
                self.santa.face = st.bottom > st.top ? 1 : -1
                self.tweenSanta(st.bottom, Level.floorY[st.lower], 0.7) { [unowned self] in
                    self.landed()
                }
            }

        case .deliver:
            delivered = true
            score += 1000
            sfx.deliver()
            toast("Presents delivered! Now sneak back up to the chimney")
            if let mia = npcs.first(where: { $0.id == "mia" }), mia.state == .asleep {
                miaWakeIn = 2.6
            }
        }
    }

    // MARK: - Update (fixed 60 Hz step)

    func update(_ dt: Double) {
        time += dt
        if toastT > 0 {
            toastT -= dt
            if toastT <= 0 { toastText = nil }
        }
        if phase == .caught {
            caughtT -= dt
            if caughtT <= 0 {
                respawn()
                return
            }
            updateNPCs(dt, detect: false)
            return
        }
        guard phase == .play else { return }
        playTime += dt

        if let t = miaWakeIn {
            let left = t - dt
            if left <= 0 {
                miaWakeIn = nil
                if let mia = npcs.first(where: { $0.id == "mia" }) {
                    wakeNPC(mia, "Uh oh… someone is awake upstairs!")
                }
            } else {
                miaWakeIn = left
            }
        }

        santa.px = santa.x
        santa.py = santa.y
        santa.inv = max(0, santa.inv - dt)
        santa.grace = max(0, santa.grace - dt)

        let ax = input.axisX
        if let it = currentInteraction() {
            let wantsMove = abs(ax) > 0.3
            var fire = input.action
            if it.trigger == .up && input.up { fire = true }
            if it.trigger == .down && input.down { fire = true }
            if it.kind == .unhide && (input.jump || input.up || wantsMove) { fire = true }
            if fire {
                doInteraction(it)
                input.consume()
            }
        }

        switch santa.mode {
        case .tween:
            stepTween(dt)
        case .walk:
            stepWalk(dt, ax)
        case .hidden:
            break
        }
        input.consume()

        // Entering a room reveals it.
        if let room = Level.roomAt(santa.floor, santa.x) {
            if room.id != roomId {
                roomId = room.id
                revealed.insert(room.id)
            }
        } else {
            roomId = nil
        }

        updateNPCs(dt, detect: true)
        interaction = currentInteraction()
    }

    private func stepTween(_ dt: Double) {
        guard var tw = santa.tween else {
            santa.mode = .walk
            return
        }
        tw.t += dt
        let k = min(1, tw.t / tw.dur)
        santa.x = tw.x0 + (tw.x1 - tw.x0) * k
        santa.y = tw.y0 + (tw.y1 - tw.y0) * k
        santa.anim += dt * 8
        if santa.floor > 0 && abs(tw.x1 - tw.x0) > 4 {
            // Footsteps while walking to or along a staircase.
            santa.stepAcc += dt
            if santa.stepAcc > 0.1 {
                santa.stepAcc = 0
                sfx.step(roof: false)
            }
        }
        if k >= 1 {
            santa.tween = nil
            tw.done?()
        } else {
            santa.tween = tw
        }
    }

    private func stepWalk(_ dt: Double, _ ax: Double) {
        // Horizontal
        let target = ax * Cfg.walk
        santa.vx += (target - santa.vx) * min(1, Cfg.friction * dt)
        if abs(ax) > 0.1 { santa.face = ax > 0 ? 1 : -1 }
        santa.x += santa.vx * dt
        let minX: Double = santa.floor == 0 ? 40 : Level.houseX0 + 5
        let maxX: Double = santa.floor == 0 ? 280 : Level.houseX1 - 5
        santa.x = min(maxX, max(minX, santa.x))
        santa.anim += abs(santa.vx) * dt * 0.18

        // Vertical
        let wasGround = santa.onGround
        if (input.jump || input.up) && santa.onGround {
            santa.vy = -Cfg.jump
            santa.onGround = false
            sfx.jump()
        }
        let prevY = santa.y
        santa.vy += Cfg.gravity * dt
        santa.y += santa.vy * dt
        santa.onGround = false
        let vyBefore = santa.vy
        if santa.vy >= 0 {
            for p in Level.ledges where p.floor == santa.floor {
                if santa.x >= p.x0 && santa.x <= p.x1 && prevY <= p.top && santa.y >= p.top {
                    santa.y = p.top
                    santa.vy = 0
                    santa.onGround = true
                }
            }
        }
        let floorY = Level.floorY[santa.floor]
        if santa.y >= floorY {
            santa.y = floorY
            santa.vy = 0
            santa.onGround = true
        }
        let ceil = Level.ceiling(santa.floor)
        if santa.y - 11 < ceil {
            santa.y = ceil + 11
            santa.vy = max(0, santa.vy)
        }
        if !wasGround && santa.onGround && vyBefore > 60 { sfx.land() }
        if santa.onGround && abs(santa.vx) > 8 {
            santa.stepAcc += abs(santa.vx) * dt
            if santa.stepAcc > 11 {
                santa.stepAcc = 0
                sfx.step(roof: santa.floor == 0)
            }
        }

        // Doors swing open as Santa reaches them.
        for d in doors where !d.open && d.floor == santa.floor && abs(santa.x - d.x) < 7 {
            openDoor(d, by: nil)
        }

        // Pickups
        if santa.floor == Level.cookieFloor && !cookies && abs(santa.x - Level.cookieX) < 6
            && santa.y <= Level.floorY[3] - 13 {
            cookies = true
            score += 300
            toast("Cookies! +300", 1.6)
            sfx.cookie()
        }
        if santa.floor == Level.milkFloor && !milk && abs(santa.x - Level.milkX) < 6 {
            milk = true
            score += 200
            toast("Milk! +200", 1.6)
            sfx.milk()
        }
    }

    // MARK: - Winning

    func win() {
        phase = .won
        sfx.win()
        let timeBonus = max(0, Int((1500 - playTime * 8).rounded()))
        let rows: [ScoreRow] = [
            ScoreRow(label: "Presents delivered", points: 1000),
            ScoreRow(label: "Back up the chimney", points: 1000),
            ScoreRow(label: "Cookies", points: cookies ? 300 : 0),
            ScoreRow(label: "Milk", points: milk ? 200 : 0),
            ScoreRow(label: "Time bonus (\(Int(playTime.rounded()))s)", points: timeBonus),
            ScoreRow(label: attempt == 1 ? "First try bonus" : "Attempts: \(attempt)", points: attempt == 1 ? 750 : 0),
        ]
        let total = rows.reduce(0) { $0 + $1.points }
        score = total
        let previous = best
        let isNewBest = total > previous && previous > 0
        if total > best { best = total }
        end = EndResult(
            title: "Merry Christmas!",
            text: isNewBest ? "New best score!" : "Nobody saw a thing. Ho ho ho.",
            rows: rows,
            total: total,
            best: previous > 0 ? max(previous, total) : 0
        )
    }
}
