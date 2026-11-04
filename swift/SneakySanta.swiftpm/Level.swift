import Foundation

// The house: floors, rooms, stairs, hiding spots, shadows and pickups.
// All positions are in the game's 320×200 logical pixels.

enum Cfg {
    static let W: Double = 320
    static let H: Double = 200
    static let step: Double = 1.0 / 60.0

    static let walk: Double = 52
    static let friction: Double = 12
    static let gravity: Double = 520
    static let jump: Double = 150
    static let sightRange: Double = 64
    static let shadowSight: Double = 14
    static let susRise: Double = 1.9
    static let susFall: Double = 0.7
}

struct Room {
    let id: String
    let name: String
    let floor: Int
    let x0: Double
    let x1: Double
    let wall: RGBA
}

/// A flight of stairs: `bottom` is on the lower floor, `top` on the floor above.
struct Stair {
    let lower: Int
    let bottom: Double
    let top: Double
}

enum HideKind {
    case wardrobe, boxes, curtain, cupboard, desk, pantry, table, couch
}

struct HideSpot {
    let floor: Int
    let x0: Double
    let x1: Double
    let kind: HideKind
    let label: String
}

/// A dark patch where the family can only see Santa up close.
struct Zone {
    let floor: Int
    let x0: Double
    let x1: Double
}

/// One-way platform Santa can jump onto (beds, the kitchen bench).
struct Ledge {
    let floor: Int
    let x0: Double
    let x1: Double
    let top: Double
}

enum Level {
    /// y of the walking surface on each floor: 0 = roof, 1 = top floor, 2 = middle, 3 = ground.
    static let floorY: [Double] = [34, 82, 130, 178]

    static func ceiling(_ f: Int) -> Double {
        f == 0 ? -99 : floorY[f - 1] + 4
    }

    static let houseX0: Double = 16
    static let houseX1: Double = 304

    static let rooms: [Room] = [
        Room(id: "kids", name: "Mia's room", floor: 1, x0: 16, x1: 120, wall: "#2e2a4a"),
        Room(id: "hall3", name: "Upstairs hall", floor: 1, x0: 120, x1: 210, wall: "#283350"),
        Room(id: "attic", name: "Attic", floor: 1, x0: 210, x1: 304, wall: "#33293a"),
        Room(id: "bath", name: "Bathroom", floor: 2, x0: 16, x1: 96, wall: "#24404a"),
        Room(id: "landing", name: "Landing", floor: 2, x0: 96, x1: 206, wall: "#283350"),
        Room(id: "leo", name: "Leo's room", floor: 2, x0: 206, x1: 304, wall: "#253a35"),
        Room(id: "kitchen", name: "Kitchen", floor: 3, x0: 16, x1: 124, wall: "#3a3528"),
        Room(id: "hall1", name: "Front hall", floor: 3, x0: 124, x1: 196, wall: "#283350"),
        Room(id: "lounge", name: "Lounge room", floor: 3, x0: 196, x1: 304, wall: "#3a2a2e"),
    ]

    static let stairs: [Stair] = [
        Stair(lower: 2, bottom: 160, top: 204),   // landing → upstairs hall (rises right)
        Stair(lower: 3, bottom: 176, top: 132),   // front hall → landing (rises left)
    ]
    static let stairSteps = 8
    /// Width of the stairwell opening cut into the floor above.
    static let well: Double = 18
    /// Extra reach either side of a staircase.
    static let stairPad: Double = 6

    static let chimneyX: Double = 248
    static let chimneyRoofX0: Double = 238
    static let chimneyRoofX1: Double = 260

    static let hides: [HideSpot] = [
        HideSpot(floor: 1, x0: 94, x1: 112, kind: .wardrobe, label: "Hide in wardrobe"),
        HideSpot(floor: 1, x0: 268, x1: 292, kind: .boxes, label: "Hide behind boxes"),
        HideSpot(floor: 2, x0: 22, x1: 42, kind: .curtain, label: "Hide behind curtain"),
        HideSpot(floor: 2, x0: 100, x1: 118, kind: .cupboard, label: "Hide in cupboard"),
        HideSpot(floor: 2, x0: 214, x1: 238, kind: .desk, label: "Hide under desk"),
        HideSpot(floor: 3, x0: 20, x1: 36, kind: .pantry, label: "Hide in pantry"),
        HideSpot(floor: 3, x0: 58, x1: 90, kind: .table, label: "Hide under table"),
        HideSpot(floor: 3, x0: 216, x1: 250, kind: .couch, label: "Hide behind couch"),
    ]

    static let shadows: [Zone] = [
        Zone(floor: 1, x0: 188, x1: 210),
        Zone(floor: 2, x0: 162, x1: 180),
        Zone(floor: 3, x0: 180, x1: 196),
    ]

    static let ledges: [Ledge] = [
        Ledge(floor: 1, x0: 24, x1: 58, top: 82 - 9),     // Mia's bed
        Ledge(floor: 2, x0: 262, x1: 298, top: 130 - 9),  // Leo's bed
        Ledge(floor: 3, x0: 96, x1: 122, top: 178 - 14),  // kitchen bench
    ]

    static let treeFloor = 3
    static let treeX: Double = 286
    static let treeX0: Double = 266

    /// Cookies sit on the kitchen bench; the milk is on Mia's bedside table.
    static let cookieFloor = 3
    static let cookieX: Double = 102
    static let milkFloor = 1
    static let milkX: Double = 67

    static func roomAt(_ floor: Int, _ x: Double) -> Room? {
        rooms.first { $0.floor == floor && x >= $0.x0 && x < $0.x1 }
    }

    static func inShadow(_ floor: Int, _ x: Double) -> Bool {
        shadows.contains { $0.floor == floor && x >= $0.x0 && x <= $0.x1 }
    }

    /// The opening in the upper floor slab where a flight arrives, as (start, end).
    static func wellRange(_ st: Stair) -> (Double, Double) {
        if st.top > st.bottom {
            return (st.top - well, st.top)
        }
        return (st.top, st.top + well)
    }
}
