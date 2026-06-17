//
//  MusicController.swift
//  Zenly
//
//  Façade over the active music source. Apple Music is driven via MediaPlayer's
//  system player; Spotify via the App Remote SDK (SpotifyController). The View
//  only talks to this.
//

import MediaPlayer
import Observation

enum MusicSource: String, CaseIterable, Identifiable {
    case appleMusic
    case spotify

    var id: String { rawValue }
    var title: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }
}

@Observable
@MainActor
final class MusicController {
    var source: MusicSource = .appleMusic {
        didSet { updateState() }
    }
    private(set) var isPlaying = false
    private(set) var nowPlaying = ""

    var spotifyConfigured: Bool { SpotifyConfig.isConfigured }

    private let appleMusicPlayer = MPMusicPlayerController.systemMusicPlayer
    private let spotify = SpotifyController()

    init() {
        spotify.onState = { [weak self] playing, track in
            Task { @MainActor [weak self] in
                guard let self, self.source == .spotify else { return }
                self.isPlaying = playing
                self.nowPlaying = track
            }
        }
        updateState()
    }

    func playPause() {
        switch source {
        case .appleMusic:
            if appleMusicPlayer.playbackState == .playing {
                appleMusicPlayer.pause()
            } else {
                appleMusicPlayer.play()
            }
            updateState()
        case .spotify:
            spotify.playPause(isPlaying: isPlaying)
        }
    }

    func next() {
        switch source {
        case .appleMusic: appleMusicPlayer.skipToNextItem()
        case .spotify: spotify.next()
        }
        updateState()
    }

    func previous() {
        switch source {
        case .appleMusic: appleMusicPlayer.skipToPreviousItem()
        case .spotify: spotify.previous()
        }
        updateState()
    }

    /// Begin the Spotify authorize → connect flow.
    func connectSpotify() {
        source = .spotify
        spotify.authorizeAndConnect()
    }

    /// Handle the Spotify OAuth redirect (from onOpenURL).
    func handleSpotifyCallback(_ url: URL) {
        spotify.handleURL(url)
    }

    /// Re-establish the Spotify connection on foreground (App Remote drops it
    /// when backgrounded).
    func reconnectSpotifyIfNeeded() {
        guard source == .spotify else { return }
        spotify.reconnect()
    }

    func updateState() {
        guard source == .appleMusic else { return } // Spotify state arrives via callback
        isPlaying = appleMusicPlayer.playbackState == .playing
        nowPlaying = appleMusicPlayer.nowPlayingItem?.title ?? ""
    }
}
