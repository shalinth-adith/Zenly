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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .white: return "White noise"
        case .pink: return "Pink noise"
        case .brown: return "Brown noise"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "speaker.slash.fill"
        case .white: return "waveform"
        case .pink: return "waveform.path"
        case .brown: return "waveform.path.ecg"
        }
    }
}

/// Real-time noise generator. Lives off the main actor; touched only from the
/// audio render thread once installed.
final class NoiseGenerator {
    enum Color { case white, pink, brown }
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

    func toggle(_ sound: AmbientSound) {
        if current == sound { stop() } else { play(sound) }
    }

    func play(_ sound: AmbientSound) {
        guard sound != .none else { stop(); return }

        switch sound {
        case .white: generator.color = .white
        case .pink: generator.color = .pink
        case .brown: generator.color = .brown
        case .none: break
        }

        if sourceNode == nil { installSourceNode() }
        configureSession(active: true)

        if !engine.isRunning {
            try? engine.start()
        }
        current = sound
    }

    func stop() {
        engine.stop()
        configureSession(active: false)
        current = .none
    }

    // MARK: - Private

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
