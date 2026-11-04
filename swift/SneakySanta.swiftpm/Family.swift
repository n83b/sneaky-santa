import Foundation

// Doors, sleepers waking up, family patrols and spotting Santa.

final class Door {
    let floor: Int
    let x: Double
    var open = false
    /// 0…1 while the door swings open.
    var anim: Double = 0
    /// Which way it swung: +1 into the room on the right, -1 to the left.
    var side: Double = 1

    init(floor: Int, x: Double) {
        self.floor = floor
        self.x = x
    }
}

enum NPCState {
    case asleep, stir, walk, wait
}

enum StirPhase {
    case zz, up
}

/// Seconds of each wake-up phase: still snoozing (Z's), then sitting up with "!?!?".
enum StirTiming {
    static let zz: Double = 1.1
    static let up: Double = 1.3
}

final class NPC {
    let id: String
    let name: String
    let floor: Int
    var x: Double
    var dir: Double
    let lo: Double
    let hi: Double
    let speed: Double
    let pause: Double
    var state: NPCState
    /// Room they sleep in (opening its door wakes them).
    let room: String?
    /// Where they climb out of bed.
    let wakeX: Double?
    let frames: [Sprite]
    let height: Double
    var waitT: Double = 0
    var sus: Double = 0
    var anim: Double = 0
    var stirT: Double = 0
    var stirPhase: StirPhase = .zz

    init(id: String, name: String, floor: Int, x: Double, dir: Double, lo: Double, hi: Double,
         speed: Double, pause: Double, state: NPCState, room: String?, wakeX: Double?,
         frames: [Sprite], height: Double) {
        self.id = id
        self.name = name
        self.floor = floor
        self.x = x
        self.dir = dir
        self.lo = lo
        self.hi = hi
        self.speed = speed
        self.pause = pause
        self.state = state
        self.room = room
        self.wakeX = wakeX
        self.frames = frames
        self.height = height
    }

    static func family() -> [NPC] {
        [
            NPC(id: "mia", name: "Mia", floor: 1, x: 41, dir: 1, lo: 40, hi: 170, speed: 17, pause: 2.4,
                state: .asleep, room: "kids", wakeX: 46, frames: Sprites.mia, height: 9),
            NPC(id: "leo", name: "Leo", floor: 2, x: 250, dir: -1, lo: 30, hi: 292, speed: 21, pause: 2.6,
                state: .walk, room: nil, wakeX: nil, frames: Sprites.leo, height: 9),
            NPC(id: "dad", name: "Dad", floor: 3, x: 70, dir: 1, lo: 40, hi: 262, speed: 18, pause: 3.2,
                state: .walk, room: nil, wakeX: nil, frames: Sprites.dad, height: 14),
        ]
    }
}

extension Game {
    /// Is there a closed door between a and b on this floor?
    func doorBetween(_ floor: Int, _ a: Double, _ b: Double) -> Bool {
        let lo = min(a, b)
        let hi = max(a, b)
        return doors.contains { !$0.open && $0.floor == floor && $0.x > lo && $0.x < hi }
    }

    func wakeNPC(_ n: NPC, _ msg: String? = nil) {
        guard n.state == .asleep else { return }
        n.state = .stir
        n.stirPhase = .zz
        n.stirT = StirTiming.zz + StirTiming.up
        n.sus = 0
        toast(msg ?? "\(n.name) is waking up!", 2.2)
    }

    /// Opens a door. `by` is the family member walking through it, or nil for Santa.
    func openDoor(_ d: Door, by npc: NPC?) {
        d.open = true
        d.anim = 0
        if let n = npc {
            d.side = n.dir
            if n.floor == santa.floor { sfx.door(soft: true) }
            return
        }
        d.side = santa.x < d.x ? 1 : -1
        sfx.door(soft: false)
        if let room = Level.roomAt(d.floor, d.x + d.side * 4) {
            revealed.insert(room.id)
            for n in npcs where n.state == .asleep && n.room == room.id {
                wakeNPC(n, "The door creaked… \(n.name) is waking up!")
            }
        }
    }

    func updateNPCs(_ dt: Double, detect: Bool) {
        for d in doors where d.open && d.anim < 1 {
            d.anim = min(1, d.anim + dt / 0.35)
        }

        for n in npcs {
            switch n.state {
            case .asleep:
                continue
            case .stir:
                n.stirT -= dt
                if n.stirPhase == .zz && n.stirT <= StirTiming.up {
                    n.stirPhase = .up
                    sfx.wake()
                }
                if n.stirT <= 0 {
                    n.state = .walk
                    n.x = n.wakeX ?? n.x
                    n.dir = 1
                }
                continue
            case .walk:
                let nx = n.x + n.dir * n.speed * dt
                for d in doors where !d.open && d.floor == n.floor && (d.x - n.x) * (d.x - nx) <= 0 {
                    openDoor(d, by: n)
                }
                n.x = nx
                n.anim += dt * 5
                if (n.dir > 0 && n.x >= n.hi) || (n.dir < 0 && n.x <= n.lo) {
                    n.x = min(n.hi, max(n.lo, n.x))
                    n.state = .wait
                    n.waitT = n.pause
                }
            case .wait:
                n.waitT -= dt
                if n.waitT <= 0 {
                    n.dir *= -1
                    n.state = .walk
                }
            }

            if !detect { continue }

            // Vision: a cone in front, plus anyone standing right on top of Santa.
            var sees = false
            let s = santa
            if n.floor == s.floor && s.mode == .walk && s.inv == 0 && s.grace == 0 {
                let dx = s.x - n.x
                let range = Level.inShadow(s.floor, s.x) ? Cfg.shadowSight : Cfg.sightRange
                let inCone = dx * n.dir > 0 && abs(dx) < range
                if (inCone || abs(dx) < 5) && !doorBetween(n.floor, n.x, s.x) { sees = true }
            }
            let wasSus = n.sus
            n.sus = sees ? n.sus + Cfg.susRise * dt : max(0, n.sus - Cfg.susFall * dt)
            if wasSus == 0 && n.sus > 0 { sfx.notice() }
            if n.sus >= 1 {
                caught(n)
                return
            }
        }
    }

    func caught(_ n: NPC) {
        phase = .caught
        caughtT = 1.8
        caughtBy = n
        n.state = .wait
        n.waitT = 2
        sfx.caught()
        toast("\(n.name) spotted Santa! Back to the roof…", 1.8)
    }
}
