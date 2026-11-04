import Foundation

/// A colour as 0…1 sRGB components plus alpha.
/// Write one as a hex string literal ("#d8433b"), or with alpha: RGBA("#000000", 0.25) / RGBA(4, 6, 14, 0.35).
struct RGBA: Equatable, ExpressibleByStringLiteral {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// 0–255 channels plus alpha, like CSS rgba().
    init(_ red: Int, _ green: Int, _ blue: Int, _ alpha: Double = 1) {
        self.init(r: Double(red) / 255.0, g: Double(green) / 255.0, b: Double(blue) / 255.0, a: alpha)
    }

    /// "#rrggbb" plus optional alpha.
    init(_ hex: String, _ alpha: Double = 1) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0xff00ff
        let red = Int((v >> 16) & 0xff)
        let green = Int((v >> 8) & 0xff)
        let blue = Int(v & 0xff)
        self.init(red, green, blue, alpha)
    }

    init(stringLiteral value: String) {
        self.init(value, 1)
    }
}
