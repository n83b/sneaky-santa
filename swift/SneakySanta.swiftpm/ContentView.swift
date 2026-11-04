import SwiftUI

// The screen: game canvas, HUD, touch controls and the start and end cards.

enum Theme {
    static let night = Color(red: 11.0 / 255, green: 15.0 / 255, blue: 28.0 / 255)
    static let panel = Color(red: 21.0 / 255, green: 27.0 / 255, blue: 46.0 / 255)
    static let ink = Color(red: 238.0 / 255, green: 240.0 / 255, blue: 246.0 / 255)
    static let muted = Color(red: 141.0 / 255, green: 150.0 / 255, blue: 179.0 / 255)
    static let santa = Color(red: 216.0 / 255, green: 67.0 / 255, blue: 59.0 / 255)
    static let gold = Color(red: 243.0 / 255, green: 195.0 / 255, blue: 90.0 / 255)
    static let line = Color(red: 44.0 / 255, green: 54.0 / 255, blue: 86.0 / 255)
    static let key = Color(red: 58.0 / 255, green: 70.0 / 255, blue: 112.0 / 255)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct ContentView: View {
    @StateObject private var game = GameController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let hud = game.hud
        ZStack {
            Theme.night.ignoresSafeArea()

            GameCanvas(controller: game)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HUDBar(
                    hud: hud,
                    onSound: { game.toggleSound() },
                    onPause: { game.togglePause() },
                    onDebug: { game.toggleDebug() }
                )
                if let text = hud.debug {
                    Text(text)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.ink)
                        .padding(8)
                        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }
                Spacer(minLength: 0)
                TouchControls(controller: game, actionLabel: hud.actionLabel)
            }
            .padding(16)

            if let prompt = hud.prompt {
                VStack {
                    Spacer()
                    PromptPill(text: prompt, key: hud.promptKey)
                        .padding(.bottom, 30)
                }
                .allowsHitTesting(false)
            }

            if let toast = hud.toast {
                GeometryReader { geo in
                    ToastView(text: toast)
                        .frame(maxWidth: min(geo.size.width - 32, 520))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.22)
                }
                .allowsHitTesting(false)
            }

            if hud.phase == .title {
                StartCard(onStart: { game.startGame() })
            } else if hud.phase == .won, let end = hud.end {
                EndCard(result: end, onAgain: { game.startGame() })
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { game.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pause() }
        }
    }
}

/// Redraws the game every display frame.
struct GameCanvas: View {
    let controller: GameController

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas(opaque: true) { context, size in
                _ = timeline.date
                controller.draw(context, size)
            }
        }
    }
}

// MARK: - HUD

struct HUDBar: View {
    let hud: HUDState
    let onSound: () -> Void
    let onPause: () -> Void
    let onDebug: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hud.score.formatted())
                    .font(Theme.display(24))
                    .monospacedDigit()
                Text(hud.objective)
                    .font(Theme.display(14, .semibold))
                    .foregroundStyle(Theme.gold)
                Text("ATTEMPT \(hud.attempt)")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.muted)
            }
            .allowsHitTesting(false)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                HUDButton(title: hud.muted ? "Muted" : "Sound", lit: !hud.muted, action: onSound)
                HUDButton(title: hud.phase == .paused ? "Resume" : "Pause", lit: hud.phase == .paused, action: onPause)
                HUDButton(title: "Debug", lit: hud.debug != nil, action: onDebug)
            }
        }
        .foregroundStyle(Theme.ink)
    }
}

struct HUDButton: View {
    let title: String
    let lit: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Theme.mono(12, .semibold))
                .foregroundStyle(lit ? Theme.gold : Theme.ink)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(Theme.panel.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(lit ? Theme.gold : Theme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PromptPill: View {
    let text: String
    let key: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(Theme.display(16, .semibold))
                .foregroundStyle(Theme.ink)
            Text(key)
                .font(Theme.mono(11, .semibold))
                .foregroundStyle(Theme.gold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.night.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line, lineWidth: 1))
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.display(18, .semibold))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.night.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.gold, lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Touch controls

/// A button that reports press and release, for hold-to-walk and instant taps.
/// Each one tracks its own finger, so you can hold an arrow and tap JUMP at the same time.
struct HoldButton<Label: View>: View {
    let onPress: () -> Void
    let onRelease: () -> Void
    let label: (Bool) -> Label
    @State private var pressed = false

    init(onPress: @escaping () -> Void,
         onRelease: @escaping () -> Void = {},
         @ViewBuilder label: @escaping (Bool) -> Label) {
        self.onPress = onPress
        self.onRelease = onRelease
        self.label = label
    }

    var body: some View {
        label(pressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        onRelease()
                    }
            )
    }
}

struct TouchControls: View {
    let controller: GameController
    let actionLabel: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HoldButton(
                onPress: { controller.hold(left: true, pressed: true) },
                onRelease: { controller.hold(left: true, pressed: false) }
            ) { pressed in
                ArrowKey(symbol: "arrowtriangle.left.fill", pressed: pressed)
            }
            HoldButton(
                onPress: { controller.hold(left: false, pressed: true) },
                onRelease: { controller.hold(left: false, pressed: false) }
            ) { pressed in
                ArrowKey(symbol: "arrowtriangle.right.fill", pressed: pressed)
            }
            Spacer(minLength: 0)
            HoldButton(onPress: { controller.tap(.jump) }) { pressed in
                RoundKey(label: "JUMP", size: 64, fill: Theme.line, pressed: pressed)
            }
            .padding(.bottom, 4)
            HoldButton(onPress: { controller.tap(.action) }) { pressed in
                RoundKey(label: actionLabel, size: 86, fill: Theme.santa, pressed: pressed)
            }
        }
    }
}

struct ArrowKey: View {
    let symbol: String
    let pressed: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(pressed ? Theme.night : Theme.ink)
            .frame(width: 76, height: 76)
            .background(pressed ? Theme.gold : Theme.line.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(pressed ? Theme.gold : Theme.key, lineWidth: 1))
            .scaleEffect(pressed ? 0.94 : 1)
    }
}

struct RoundKey: View {
    let label: String
    let size: CGFloat
    let fill: Color
    let pressed: Bool

    var body: some View {
        Text(label)
            .font(Theme.display(13, .bold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 6)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(fill.opacity(0.25), lineWidth: 6).padding(-6))
            .scaleEffect(pressed ? 0.92 : 1)
    }
}

// MARK: - Start and end cards

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(22)
            .frame(maxWidth: 460, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .padding(16)
        }
    }
}

struct StartCard: View {
    let onStart: () -> Void

    var body: some View {
        Card {
            (Text("Sneaky ") + Text("Santa").foregroundColor(Theme.santa))
                .font(Theme.display(34, .heavy))
                .foregroundStyle(Theme.ink)
            Text("Sneak through the house, leave the presents under the tree and get back up the chimney without waking the family.")
                .font(Theme.display(16, .regular))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Bullet("Rooms stay dark until you open their door. Careful: opening a door wakes anyone asleep inside.")
                Bullet("If someone looks your way, hide in a cupboard, under a table or in the shadows.")
                Bullet("The cookies and the milk are in different rooms. Find both for bonus points.")
            }
            Text("Touch: ◀ ▶ walk · JUMP · ACTION (hide, stairs, deliver)\nKeyboard: ← → walk · ↑ ↓ stairs · Space jump · E action · P pause")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            StartButton(title: "Start delivering", action: onStart)
        }
    }
}

struct Bullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(Theme.gold)
            Text(text)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.display(15, .regular))
    }
}

struct StartButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.display(17, .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Theme.santa, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct EndCard: View {
    let result: EndResult
    let onAgain: () -> Void

    var body: some View {
        Card {
            Text(result.title)
                .font(Theme.display(32, .heavy))
                .foregroundStyle(Theme.ink)
            Text(result.text)
                .font(Theme.display(16, .regular))
                .foregroundStyle(Theme.muted)
            VStack(spacing: 4) {
                ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                    ScoreLine(label: row.label, points: row.points, highlight: false)
                }
                Divider().overlay(Theme.line)
                ScoreLine(label: "Total", points: result.total, highlight: true)
                if result.best > 0 {
                    ScoreLine(label: "Best", points: result.best, highlight: false)
                }
            }
            StartButton(title: "Play again", action: onAgain)
        }
    }
}

struct ScoreLine: View {
    let label: String
    let points: Int
    let highlight: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(points.formatted())
                .monospacedDigit()
        }
        .font(Theme.display(16, highlight ? .bold : .regular))
        .foregroundStyle(highlight ? Theme.gold : Theme.ink)
    }
}
