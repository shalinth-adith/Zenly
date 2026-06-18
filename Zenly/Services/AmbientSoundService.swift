//
//  AmbientSoundService.swift
//  Zenly
//
//  Plays ambient focus sounds. White/pink/brown noise are synthesized in real
//  time with AVAudioEngine (no audio assets). Rain / lo-fi are reserved for
//  bundled assets added later.
//

import AVFoundation
import Observation

enum AmbientSound: String, CaseIterable, Identifiable {
    case none
    case white
    case pink
    case brown
    case rain
    case lofi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .white: return "White noise"
        case .pink: return "Pink noise"
        case .brown: return "Brown noise"
        case .rain: return "Rain"
        case .lofi: return "Lo-fi"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "speaker.slash.fill"
        case .white: return "waveform"
        case .pink: return "waveform.path"
        case .brown: return "waveform.path.ecg"
        case .rain: return "cloud.rain.fill"
        case .lofi: return "music.note"
        }
    }

    /// File-backed sounds return a resource name; synthesized ones return nil.
    var fileName: String? { self == .lofi ? "lofi" : nil }

    /// File-backed sounds are only available when their audio is bundled.
    var isAvailable: Bool {
        guard let fileName else { return true }
        return Bundle.main.url(forResource: fileName, withExtension: "m4a") != nil
            || Bundle.main.url(forResource: fileName, withExtension: "mp3") != nil
    }

    /// Sounds to show in the picker (hides file sounds with no bundled audio).
    static var available: [AmbientSound] { allCases.filter(\.isAvailable) }
}

/// Real-time noise generator. Lives off the main actor; touched only from the
/// audio render thread once installed.
final class NoiseGenerator {
    enum Color { case white, pink, brown, rain }
    var color: Color = .white

    private var pinkState: Float = 0
    private var brownState: Float = 0

    func sample() -> Float {
        let white = Float.random(in: -1...1)
        switch color {
        case .white:
            return white * 0.18
        case .pink:
            pinkState = 0.98 * pinkState + 0.02 * white
            return pinkState * 3.0 * 0.18
        case .brown:
            brownState = max(-1, min(1, brownState + 0.02 * white))
            return brownState * 0.18
        case .rain:
            // Low rumble (brown) + a touch of hiss (white) ≈ rainfall.
            brownState = max(-1, min(1, brownState + 0.02 * white))
            return brownState * 0.12 + white * 0.06
        }
    }
}

@Observable
@MainActor
final class AmbientSoundService {
    private(set) var current: AmbientSound = .none

    private let engine = AVAudioEngine()
    private let generator = NoiseGenerator()
    private var sourceNode: AVAudioSourceNode?
    private var player: AVAudioPlayer?

    func toggle(_ sound: AmbientSound) {
        if current == sound { stop() } else { play(sound) }
    }

    func play(_ sound: AmbientSound) {
        guard sound != .none else { stop(); return }

        if let file = sound.fileName {
            playFile(named: file)
            current = sound
            return
        }

        // Synthesized noise.
        stopPlayer()
        switch sound {
        case .white: generator.color = .white
        case .pink: generator.color = .pink
        case .brown: generator.color = .brown
        case .rain: generator.color = .rain
        default: break
        }

        if sourceNode == nil { installSourceNode() }
        configureSession(active: true)
        if !engine.isRunning { try? engine.start() }
        current = sound
    }

    func stop() {
        engine.stop()
        stopPlayer()
        configureSession(active: false)
        current = .none
    }

    // MARK: - Private

    private func playFile(named name: String) {
        engine.stop() // stop any synthesized noise
        let url = Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
        guard let url else { return }
        configureSession(active: true)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1 // loop forever
            player.play()
            self.player = player
        } catch {
            print("[Zenly] Ambient file playback failed: \(error)")
        }
    }

    private func stopPlayer() {
        player?.stop()
        player = nil
    }

    private func installSourceNode() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let gen = generator
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let value = gen.sample()
                for buffer in buffers {
                    let pointer = buffer.mData?.assumingMemoryBound(to: Float.self)
                    pointer?[frame] = value
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
    }

    private func configureSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if active {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            try session.setActive(active, options: active ? [] : [.notifyOthersOnDeactivation])
        } catch {
            print("[Zenly] AVAudioSession config failed: \(error)")
        }
    }
}
