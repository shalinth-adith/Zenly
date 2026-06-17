//
//  MusicController.swift
//  Zenly
//
//  Controls the system Music player via MediaPlayer (MPMusicPlayerController).
//  This drives whatever is playing in Apple Music without needing the MusicKit
//  service capability. Spotify would require Spotify's own SDK (not integrated).
//

import MediaPlayer
import Observation

@Observable
@MainActor
final class MusicController {
    private(set) var isPlaying = false
    private(set) var nowPlaying = ""

    private let player = MPMusicPlayerController.systemMusicPlayer

    init() {
        updateState()
    }

    func playPause() {
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
        updateState()
    }

    func next() {
        player.skipToNextItem()
        updateState()
    }

    func previous() {
        player.skipToPreviousItem()
        updateState()
    }

    func updateState() {
        isPlaying = player.playbackState == .playing
        nowPlaying = player.nowPlayingItem?.title ?? ""
    }
}
