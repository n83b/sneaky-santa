import AVFoundation

// Sound effects synthesised live with AVAudioEngine (no audio files).
// A port of the web version's Web Audio code: each effect is a few short "voices",
// either an oscillator or filtered noise, with an exponential pitch glide and envelope.

final class Synth: SoundEffects {
    private let core = SynthCore()
    private let engine = AVAudioEngine()
    private var configured = false
    private var stepFlip = false
    var muted = false

    // MARK: - Engine

    private func ensureRunning() {
        if !configured {
            configured = true
            let session = AVAudioSession.sharedInstance()
            // Ambient: plays alongside other audio and respects the silent switch.
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)

            let hardware = engine.outputNode.inputFormat(forBus: 0)
            let sampleRate = hardware.sampleRate > 0 ? hardware.sampleRate : 44100
            core.sampleRate = sampleRate
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
            let node = SynthCore.makeNode(core, format: format)
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        if !engine.isRunning {
            try? engine.start()
        }
    }

    private func play(_ v: SynthCore.Voice) {
        guard !muted else { return }
        ensureRunning()
        core.add(v)
    }

    private func tone(_ wave: SynthCore.Wave, _ f0: Double, _ f1: Double? = nil,
                      dur: Double = 0.1, vol: Double = 0.2, at: Double = 0, attack: Double = 0.005) {
        play(SynthCore.Voice(source: .wave(wave), at: at, dur: dur, attack: attack, f0: f0, f1: f1 ?? f0, vol: vol))
    }

    private func noise(dur: Double = 0.1, vol: Double = 0.2, f0: Double = 1000, f1: Double? = nil,
                       q: Double = 1, filter: SynthCore.Filter = .bandpass, at: Double = 0, attack: Double = 0.004) {
        play(SynthCore.Voice(source: .noise(filter, q), at: at, dur: dur, attack: attack, f0: f0, f1: f1 ?? f0, vol: vol))
    }

    /// MIDI note number → Hz
    private func note(_ n: Double) -> Double {
        440 * pow(2, (n - 69) / 12)
    }

    private func bell(_ n: Double, at: Double, vol: Double = 0.12, dur: Double = 0.5) {
        tone(.sine, note(n), dur: dur, vol: vol, at: at)
        tone(.sine, note(n) * 2.01, dur: dur * 0.5, vol: vol * 0.3, at: at)
    }

    // MARK: - Effects

    func step(roof: Bool) {
        stepFlip.toggle()
        let p: Double = stepFlip ? 1 : 0.85
        if roof {
            noise(dur: 0.05, vol: 0.10, f0: 2400 * p, q: 2)                // tiles: clicky
        } else {
            noise(dur: 0.06, vol: 0.13, f0: 420 * p, f1: 260 * p, q: 1.2)  // carpet and boards: soft
        }
        tone(.triangle, 95 * p, 60, dur: 0.05, vol: 0.06)
    }

    func jump() {
        tone(.triangle, 300, 620, dur: 0.13, vol: 0.10)
        noise(dur: 0.08, vol: 0.05, f0: 1500, q: 0.8)
    }

    func land() {
        noise(dur: 0.08, vol: 0.16, f0: 500, f1: 200, filter: .lowpass)
        tone(.sine, 130, 55, dur: 0.09, vol: 0.14)
    }

    func hide() {
        noise(dur: 0.28, vol: 0.12, f0: 2200, f1: 600, q: 0.9, attack: 0.03)   // rustle in
        tone(.square, 220, dur: 0.03, vol: 0.04, at: 0.22)                     // little click shut
    }

    func unhide() {
        noise(dur: 0.22, vol: 0.11, f0: 600, f1: 2200, q: 0.9, attack: 0.02)
    }

    func creak() {
        tone(.saw, 190, 150, dur: 0.18, vol: 0.025, attack: 0.04)
    }

    func door(soft: Bool) {
        let v: Double = soft ? 0.5 : 1
        tone(.square, 900, 600, dur: 0.03, vol: 0.05 * v)                          // latch
        tone(.saw, 150, 260, dur: 0.42, vol: 0.03 * v, at: 0.04, attack: 0.08)     // creak open
        tone(.saw, 230, 200, dur: 0.18, vol: 0.02 * v, at: 0.4, attack: 0.03)
    }

    func chimney() {
        noise(dur: 0.85, vol: 0.16, f0: 1600, f1: 180, q: 0.7, attack: 0.05)
        tone(.triangle, 700, 140, dur: 0.75, vol: 0.06)
        noise(dur: 0.12, vol: 0.18, f0: 300, f1: 120, filter: .lowpass, at: 0.82)  // soot-puff landing
    }

    func escape() {
        noise(dur: 0.8, vol: 0.15, f0: 180, f1: 1800, q: 0.7, attack: 0.05)
        tone(.triangle, 160, 820, dur: 0.75, vol: 0.06)
    }

    func deliver() {
        let notes: [Double] = [84, 88, 91, 96]
        for (i, n) in notes.enumerated() {
            bell(n, at: Double(i) * 0.09, vol: 0.11, dur: 0.6)
        }
        for i in 0..<4 {
            // Sleigh-bell shimmer
            noise(dur: 0.06, vol: 0.05, f0: 7000, filter: .highpass, at: 0.05 + Double(i) * 0.1)
        }
    }

    func cookie() {
        for i in 0..<3 {
            noise(dur: 0.05, vol: 0.14, f0: 2600 - Double(i) * 300, q: 1.5, at: Double(i) * 0.09)
        }
    }

    func milk() {
        tone(.sine, 320, 190, dur: 0.12, vol: 0.12)
        tone(.sine, 320, 190, dur: 0.12, vol: 0.12, at: 0.16)
    }

    func notice() {
        tone(.sine, 720, 960, dur: 0.09, vol: 0.06)
    }

    func caught() {
        tone(.triangle, note(72), dur: 0.16, vol: 0.14)
        tone(.triangle, note(67), dur: 0.3, vol: 0.14, at: 0.18)
    }

    func wake() {
        tone(.sine, 260, 420, dur: 0.35, vol: 0.06, attack: 0.08)
        tone(.sine, 420, 240, dur: 0.4, vol: 0.05, at: 0.35)
    }

    func win() {
        // Jingle Bells opening phrase (public domain)
        let tune: [(Double, Double)] = [
            (76, 1), (76, 1), (76, 2), (76, 1), (76, 1), (76, 2),
            (76, 1), (79, 1), (72, 1.5), (74, 0.5), (76, 4),
        ]
        var t = 0.1
        for (n, len) in tune {
            bell(n, at: t, vol: 0.12, dur: min(0.6, len * 0.22))
            t += len * 0.16
        }
    }
}

/// The real-time part: a list of voices mixed on the audio thread.
final class SynthCore: @unchecked Sendable {
    enum Wave {
        case sine, triangle, square, saw
    }

    enum Filter {
        case bandpass, lowpass, highpass
    }

    enum Source {
        case wave(Wave)
        case noise(Filter, Double)
    }

    struct Voice {
        var source: Source
        var start: Int64 = 0
        var at: Double
        var dur: Double
        var attack: Double
        var f0: Double
        var f1: Double
        var vol: Double
        var phase: Double = 0
        var done = false
        // Biquad filter state
        var b0: Double = 0
        var b1: Double = 0
        var b2: Double = 0
        var a1: Double = 0
        var a2: Double = 0
        var x1: Double = 0
        var x2: Double = 0
        var y1: Double = 0
        var y2: Double = 0
        var coefCountdown = 0
    }

    var sampleRate: Double = 44100
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var now: Int64 = 0
    private var seed: UInt32 = 0x9E37_79B9

    init() {
        voices.reserveCapacity(64)
    }

    func add(_ voice: Voice) {
        lock.lock()
        var v = voice
        v.start = now + Int64(v.at * sampleRate)
        if voices.count < 48 { voices.append(v) }
        lock.unlock()
    }

    static func makeNode(_ core: SynthCore, format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)
            var first: UnsafeMutablePointer<Float>? = nil
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                if let src = first {
                    for i in 0..<frames { data[i] = src[i] }
                } else {
                    core.render(frames, data)
                    first = data
                }
            }
            return noErr
        }
    }

    /// Called on the audio thread. Never blocks: if the main thread holds the lock, it outputs silence.
    func render(_ frames: Int, _ out: UnsafeMutablePointer<Float>) {
        for i in 0..<frames { out[i] = 0 }
        guard lock.try() else { return }
        defer { lock.unlock() }
        let n0 = now
        now += Int64(frames)
        if voices.isEmpty { return }
        let sr = sampleRate
        for vi in voices.indices {
            var v = voices[vi]
            renderVoice(&v, n0, frames, sr, out)
            voices[vi] = v
        }
        voices.removeAll { $0.done }
        for i in 0..<frames {
            out[i] = max(-1, min(1, out[i] * 0.6))
        }
    }

    private func renderVoice(_ v: inout Voice, _ n0: Int64, _ frames: Int, _ sr: Double,
                             _ out: UnsafeMutablePointer<Float>) {
        let end = v.dur + 0.02
        for i in 0..<frames {
            let n = n0 + Int64(i)
            if n < v.start { continue }
            let t = Double(n - v.start) / sr
            if t > end {
                v.done = true
                return
            }
            let gain = SynthCore.envelope(v, t)
            let f = t >= v.dur ? v.f1 : v.f0 * pow(v.f1 / v.f0, t / v.dur)
            var s: Double = 0
            switch v.source {
            case .wave(let w):
                v.phase += f / sr
                if v.phase >= 1 { v.phase -= floor(v.phase) }
                s = SynthCore.wave(w, v.phase)
            case .noise(let filter, let q):
                if v.coefCountdown <= 0 {
                    SynthCore.setCoefficients(&v, filter, f, q, sr)
                    v.coefCountdown = 32
                }
                v.coefCountdown -= 1
                let x = nextNoise()
                let y = v.b0 * x + v.b1 * v.x1 + v.b2 * v.x2 - v.a1 * v.y1 - v.a2 * v.y2
                v.x2 = v.x1
                v.x1 = x
                v.y2 = v.y1
                v.y1 = y
                s = y
            }
            out[i] += Float(s * gain)
        }
    }

    /// Exponential rise from silence to `vol` over `attack`, then exponential fall to silence at `dur`
    /// (the same shape as Web Audio's exponentialRampToValueAtTime).
    private static func envelope(_ v: Voice, _ t: Double) -> Double {
        let silent = 0.0001
        if t < v.attack {
            return silent * pow(v.vol / silent, t / v.attack)
        }
        if t >= v.dur { return silent }
        let d = max(v.dur - v.attack, 0.0001)
        return v.vol * pow(silent / v.vol, (t - v.attack) / d)
    }

    private static func wave(_ w: Wave, _ p: Double) -> Double {
        switch w {
        case .sine: return sin(2 * Double.pi * p)
        case .square: return p < 0.5 ? 1 : -1
        case .saw: return 2 * p - 1
        case .triangle: return 1 - 4 * abs(p - 0.5)
        }
    }

    /// RBJ cookbook biquad coefficients.
    private static func setCoefficients(_ v: inout Voice, _ filter: Filter, _ f: Double, _ q: Double, _ sr: Double) {
        let fc = min(max(f, 20), sr * 0.45)
        let w0 = 2 * Double.pi * fc / sr
        let cw = cos(w0)
        let sw = sin(w0)
        let qq: Double = filter == .bandpass ? max(q, 0.1) : 0.8
        let alpha = sw / (2 * qq)
        let a0 = 1 + alpha
        let b0: Double
        let b1: Double
        let b2: Double
        switch filter {
        case .bandpass:
            b0 = alpha
            b1 = 0
            b2 = -alpha
        case .lowpass:
            b0 = (1 - cw) / 2
            b1 = 1 - cw
            b2 = (1 - cw) / 2
        case .highpass:
            b0 = (1 + cw) / 2
            b1 = -(1 + cw)
            b2 = (1 + cw) / 2
        }
        v.b0 = b0 / a0
        v.b1 = b1 / a0
        v.b2 = b2 / a0
        v.a1 = (-2 * cw) / a0
        v.a2 = (1 - alpha) / a0
    }

    private func nextNoise() -> Double {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Double(seed) / Double(UInt32.max) * 2 - 1
    }
}
