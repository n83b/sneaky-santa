import Foundation

// Pixel sprites drawn from character maps. Each map is baked once into horizontal runs
// of one colour (for both facings), so drawing a sprite is a handful of rectangles.

struct PixelRun {
    let x: Int
    let y: Int
    let len: Int
    let c: RGBA
}

struct Sprite {
    let w: Int
    let h: Int
    let right: [PixelRun]
    let left: [PixelRun]
}

enum Sprites {
    static let base: [Character: RGBA] = [
        "r": "#d8433b", "w": "#f4f1ea", "f": "#f0b48c", "e": "#1a1420",
        "k": "#1d1a24", "g": "#f3c35a", "s": "#7a4a2c",
    ]

    static func kidPalette(hair: RGBA, pyjamas: RGBA) -> [Character: RGBA] {
        var p = base
        p["h"] = hair
        p["p"] = pyjamas
        p["s"] = "#c9c3d6"
        return p
    }

    static func adultPalette(hair: RGBA, gown: RGBA) -> [Character: RGBA] {
        var p = base
        p["h"] = hair
        p["g"] = gown
        p["y"] = "#e8d9a8"
        p["s"] = "#5a3a2a"
        return p
    }

    static let santaMaps: [[String]] = [
        [
            "...rrr..",
            "..rrrrrw",
            ".wwwwww.",
            ".ffefef.",
            ".wwwwww.",
            "rrwwwwrr",
            "rrrrrrrr",
            "rkkgkkkr",
            ".rrrrrr.",
            ".kk..kk.",
            ".kk..kk.",
        ],
        [
            "...rrr..",
            "..rrrrrw",
            ".wwwwww.",
            ".ffefef.",
            ".wwwwww.",
            "rrwwwwrr",
            "rrrrrrrr",
            "rkkgkkkr",
            ".rrrrrr.",
            "..kkkk..",
            "..kkkk..",
        ],
    ]

    static let kidMaps: [[String]] = [
        [
            ".hhhh.",
            ".hfff.",
            ".ffef.",
            "pppppp",
            "pppppp",
            ".pppp.",
            ".pppp.",
            ".p..p.",
            ".s..s.",
        ],
        [
            ".hhhh.",
            ".hfff.",
            ".ffef.",
            "pppppp",
            "pppppp",
            ".pppp.",
            ".pppp.",
            "..pp..",
            "..ss..",
        ],
    ]

    static let adultMaps: [[String]] = [
        [
            "..hhh..",
            ".hhhhh.",
            ".fffef.",
            ".fffff.",
            "..fff..",
            ".ggggg.",
            "ggggggg",
            "gggyggg",
            ".ggggg.",
            ".ggggg.",
            ".ggggg.",
            "..f.f..",
            "..f.f..",
            ".ss.ss.",
        ],
        [
            "..hhh..",
            ".hhhhh.",
            ".fffef.",
            ".fffff.",
            "..fff..",
            ".ggggg.",
            "ggggggg",
            "gggyggg",
            ".ggggg.",
            ".ggggg.",
            ".ggggg.",
            "...f...",
            "..ff...",
            "..sss..",
        ],
    ]

    static let santa: [Sprite] = Sprites.santaMaps.map { Sprites.bake($0, Sprites.base) }
    static let mia: [Sprite] = Sprites.kidMaps.map { Sprites.bake($0, Sprites.kidPalette(hair: "#e8c25a", pyjamas: "#e58fb1")) }
    static let leo: [Sprite] = Sprites.kidMaps.map { Sprites.bake($0, Sprites.kidPalette(hair: "#6b4a2e", pyjamas: "#5b8fd9")) }
    static let dad: [Sprite] = Sprites.adultMaps.map { Sprites.bake($0, Sprites.adultPalette(hair: "#3a2a22", gown: "#4f7a5a")) }

    // Little glyphs drawn above characters and stairs.
    static let question = bake(["ooo", "..o", ".oo", "...", ".o."], ["o": "#f3c35a"])
    static let bang = bake(["o", "o", "o", ".", "o"], ["o": "#ff6a5c"])
    static let zed = bake(["ooo", ".o.", "ooo"], ["o": "#a9b8ff"])
    static let arrowUp = bake([".o.", "ooo", "o.o"], ["o": "#f3c35a"])
    static let arrowDown = bake(["o.o", "ooo", ".o."], ["o": "#f3c35a"])

    static func bake(_ map: [String], _ palette: [Character: RGBA]) -> Sprite {
        let rows: [[Character]] = map.map { Array($0) }
        let h = rows.count
        let w = rows.first?.count ?? 0

        func runs(flipped: Bool) -> [PixelRun] {
            var out: [PixelRun] = []
            for j in 0..<h {
                let row: [Character] = flipped ? Array(rows[j].reversed()) : rows[j]
                var i = 0
                while i < row.count {
                    let ch = row[i]
                    if ch == "." {
                        i += 1
                        continue
                    }
                    var k = i + 1
                    while k < row.count && row[k] == ch { k += 1 }
                    let colour = palette[ch] ?? RGBA("#ff00ff")
                    out.append(PixelRun(x: i, y: j, len: k - i, c: colour))
                    i = k
                }
            }
            return out
        }

        return Sprite(w: w, h: h, right: runs(flipped: false), left: runs(flipped: true))
    }
}
