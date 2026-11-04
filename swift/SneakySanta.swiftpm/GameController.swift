import SwiftUI
import QuartzCore
import GameController

// Runs the fixed-timestep loop, gathers touch, keyboard and gamepad input,
// draws the game into the SwiftUI Canvas and publishes what the HUD shows.

/// Everything the SwiftUI overlay shows. Published only when it changes.
struct HUDState: Equatable {
    var score = 0
    var objective = ""
    var attempt = 1
    var prompt: String? = nil
    var promptKey = ""
    var actionLabel = "ACTION"
    var toast: String? = nil
    var phase: GamePhase = .title
    var end: EndResult? = nil
    var muted = false
    var debug: String? = nil
}

enum TapButton {
    case jump, action
}

/// How the 320×200 game is scaled and placed on screen: whole-number scaling where there is room.
struct ScreenFit {
    let scale: Double
    let ox: Double
    let oy: Double

    init(_ size: CGSize) {
        let w = Double(size.width)
        let h = Double(size.height)
        let fit = min(w / Cfg.W, (h - 40) / Cfg.H)
        scale = fit >= 2 ? floor(fit) : max(fit, 0.25)
        ox = ((w - Cfg.W * scale) / 2).rounded()
        oy = max(40, (h - Cfg.H * scale) / 2).rounded()
    }
}

final class GameController: ObservableObject {
    @Published private(set) var hud = HUDState()

    let game: Game
    private let synth: Synth
    private var link: DisplayLinkProxy?
    private var last: CFTimeInterval = 0
    private var acc: Double = 0
    private var alpha: Double = 1

    // Input
    private var touchLeft = false
    private var touchRight = false
    private var hardwareAxis: Double = 0
    private var edges = Controls()
    private var previous = HardwareButtons()

    // Debug overlay
    private var showDebug = false
    private var debugText = ""
    private var fpsFrames = 0
    private var fpsTime: Double = 0

    private enum Keys {
        static let best = "sns-best"
        static let muted = "sns-muted"
    }

    init() {
        let s = Synth()
        synth = s
        game = Game(sound: s)
        s.muted = UserDefaults.standard.bool(forKey: Keys.muted)
        game.best = UserDefaults.standard.integer(forKey: Keys.best)
        hud = makeHUD()
    }

    // MARK: - Lifecycle

    func start() {
        guard link == nil else { return }
        link = DisplayLinkProxy { [weak self] timestamp in
            self?.frame(timestamp)
        }
    }

    func startGame() {
        game.start()
        publish()
    }

    func togglePause() {
        if game.phase == .play {
            game.setPaused(true)
        } else if game.phase == .paused {
            game.setPaused(false)
        }
        publish()
    }

    /// Called when the app goes to the background.
    func pause() {
        if game.phase == .play { game.setPaused(true) }
        publish()
    }

    func toggleSound() {
        synth.muted.toggle()
        UserDefaults.standard.set(synth.muted, forKey: Keys.muted)
        publish()
    }

    func toggleDebug() {
        showDebug.toggle()
        publish()
    }

    // MARK: - Touch controls

    func hold(left: Bool, pressed: Bool) {
        if left {
            touchLeft = pressed
        } else {
            touchRight = pressed
        }
    }

    func tap(_ button: TapButton) {
        switch button {
        case .jump: edges.jump = true
        case .action: edges.action = true
        }
    }

    // MARK: - Loop

    private func frame(_ timestamp: CFTimeInterval) {
        let dt = last == 0 ? Cfg.step : min(max(timestamp - last, 0), 0.25)
        last = timestamp
        pollHardware()

        let axis = hardwareAxis + (touchRight ? 1 : 0) - (touchLeft ? 1 : 0)
        game.input.axisX = max(-1, min(1, axis))

        if game.phase != .paused {
            acc += dt
            var steps = 0
            while acc >= Cfg.step && steps < 20 {
                mergeEdges()
                game.update(Cfg.step)
                acc -= Cfg.step
                steps += 1
            }
        }
        if game.phase != .play {
            // Presses made outside play shouldn't fire later.
            game.input.consume()
            edges.consume()
        }
        alpha = game.phase == .play ? acc / Cfg.step : 1

        if game.best > UserDefaults.standard.integer(forKey: Keys.best) {
            UserDefaults.standard.set(game.best, forKey: Keys.best)
        }
        updateDebug(dt)
        publish()
    }

    private func mergeEdges() {
        if edges.jump { game.input.jump = true }
        if edges.action { game.input.action = true }
        if edges.up { game.input.up = true }
        if edges.down { game.input.down = true }
        edges.consume()
    }

    private func publish() {
        let h = makeHUD()
        if h != hud { hud = h }
    }

    private func makeHUD() -> HUDState {
        var h = HUDState()
        h.score = game.score
        h.objective = game.objective
        h.attempt = game.attempt
        if game.phase == .play, let it = game.interaction {
            h.prompt = it.label
            switch it.trigger {
            case .up: h.promptKey = "↑ / E"
            case .down: h.promptKey = "↓ / E"
            default: h.promptKey = "E"
            }
            if let word = it.label.split(separator: " ").first {
                h.actionLabel = String(word).uppercased()
            }
        }
        h.toast = game.toastText
        h.phase = game.phase
        h.end = game.end
        h.muted = synth.muted
        h.debug = showDebug ? debugText : nil
        return h
    }

    // MARK: - Keyboard and gamepad (GameController framework)

    private struct HardwareButtons {
        var jump = false
        var action = false
        var up = false
        var down = false
        var pause = false
    }

    private func pollHardware() {
        var x: Double = 0
        var now = HardwareButtons()

        if let kb = GCKeyboard.coalesced?.keyboardInput {
            func key(_ code: GCKeyCode) -> Bool {
                kb.button(forKeyCode: code)?.isPressed ?? false
            }
            if key(.leftArrow) || key(.keyA) { x -= 1 }
            if key(.rightArrow) || key(.keyD) { x += 1 }
            now.jump = key(.spacebar) || key(.keyZ)
            now.action = key(.keyE) || key(.returnOrEnter) || key(.keyX)
            now.up = key(.upArrow) || key(.keyW)
            now.down = key(.downArrow) || key(.keyS)
            now.pause = key(.keyP) || key(.escape)
        }

        if let pad = GCController.current?.extendedGamepad {
            let ax = Double(pad.leftThumbstick.xAxis.value)
            let ay = Double(pad.leftThumbstick.yAxis.value)   // up is positive
            if abs(ax) >= 0.25 { x += ax }
            if pad.dpad.left.isPressed { x -= 1 }
            if pad.dpad.right.isPressed { x += 1 }
            if pad.buttonA.isPressed { now.jump = true }
            if pad.buttonB.isPressed || pad.buttonX.isPressed { now.action = true }
            if pad.dpad.up.isPressed || ay > 0.6 { now.up = true }
            if pad.dpad.down.isPressed || ay < -0.6 { now.down = true }
            if pad.buttonMenu.isPressed { now.pause = true }
        }

        hardwareAxis = max(-1, min(1, x))

        let pressedJump = now.jump && !previous.jump
        let pressedAction = now.action && !previous.action
        if pressedJump { edges.jump = true }
        if pressedAction { edges.action = true }
        if now.up && !previous.up { edges.up = true }
        if now.down && !previous.down { edges.down = true }
        if now.pause && !previous.pause { togglePause() }
        previous = now

        // Enter, Space or A on the start and end screens begins a run.
        if (game.phase == .title || game.phase == .won) && (pressedJump || pressedAction) {
            startGame()
            edges.consume()
        }
    }

    // MARK: - Drawing (called by the Canvas every display frame)

    func draw(_ context: GraphicsContext, _ size: CGSize) {
        let fit = ScreenFit(size)
        var ctx = context
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.night))
        ctx.translateBy(x: fit.ox, y: fit.oy)
        ctx.scaleBy(x: fit.scale, y: fit.scale)
        ctx.clip(to: Path(CGRect(x: 0, y: 0, width: Cfg.W, height: Cfg.H)))
        let painter = CanvasPainter(ctx)
        Renderer(g: game, p: painter).draw(alpha: alpha)
    }

    // MARK: - Debug

    private func updateDebug(_ dt: Double) {
        fpsFrames += 1
        fpsTime += dt
        guard fpsTime >= 0.5 else { return }
        let fps = Int((Double(fpsFrames) / fpsTime).rounded())
        fpsFrames = 0
        fpsTime = 0
        guard showDebug else { return }
        let s = game.santa
        var lines: [String] = [
            "fps     \(fps)",
            "phase   \(game.phase)",
            "santa   f\(s.floor) x\(Int(s.x)) y\(Int(s.y)) \(s.mode)",
            "room    \(game.roomId ?? "—")",
        ]
        for n in game.npcs {
            lines.append("\(n.id)  f\(n.floor) x\(Int(n.x)) \(n.state) sus \(String(format: "%.2f", n.sus))")
        }
        lines.append("gamepad \(GCController.current?.vendorName ?? "—")")
        debugText = lines.joined(separator: "\n")
    }
}

/// Calls back once per display refresh.
final class DisplayLinkProxy: NSObject {
    private var link: CADisplayLink?
    private let onFrame: (CFTimeInterval) -> Void

    init(_ onFrame: @escaping (CFTimeInterval) -> Void) {
        self.onFrame = onFrame
        super.init()
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func tick(_ l: CADisplayLink) {
        onFrame(l.timestamp)
    }

    func stop() {
        link?.invalidate()
        link = nil
    }
}

/// Draws into a SwiftUI GraphicsContext, which is already scaled to logical pixels.
final class CanvasPainter: Painter {
    private let ctx: GraphicsContext
    var alpha: Double = 1

    init(_ ctx: GraphicsContext) {
        self.ctx = ctx
    }

    private func colour(_ c: RGBA) -> Color {
        Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a * alpha)
    }

    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: RGBA) {
        let r = CGRect(x: x.rounded(), y: y.rounded(), width: w, height: h).standardized
        guard r.width > 0, r.height > 0 else { return }
        // Hard edges keep the pixel art crisp.
        ctx.fill(Path(r), with: .color(colour(c)), style: FillStyle(antialiased: false))
    }

    func polygon(_ points: [(Double, Double)], _ c: RGBA) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: CGPoint(x: first.0, y: first.1))
        for pt in points.dropFirst() {
            path.addLine(to: CGPoint(x: pt.0, y: pt.1))
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(colour(c)))
    }

    func circle(_ cx: Double, _ cy: Double, _ r: Double, _ c: RGBA) {
        let box = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: box), with: .color(colour(c)))
    }

    func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: RGBA) {
        var path = Path()
        path.move(to: CGPoint(x: x0, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y1))
        ctx.stroke(path, with: .color(colour(c)), lineWidth: 1)
    }

    func verticalGradient(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ top: RGBA, _ bottom: RGBA) {
        let gradient = Gradient(colors: [colour(top), colour(bottom)])
        let shading = GraphicsContext.Shading.linearGradient(
            gradient,
            startPoint: CGPoint(x: x, y: y),
            endPoint: CGPoint(x: x, y: y + h)
        )
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: shading)
    }
}
