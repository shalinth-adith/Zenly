//
//  SpotifyController.swift
//  Zenly
//
//  Wraps Spotify's App Remote SDK (controls the installed Spotify app; requires
//  Spotify Premium). Reports playback state out via `onState` so the @Observable
//  MusicController can stay free of the Objective-C SDK.
//

import Foundation
import SpotifyiOS

final class SpotifyController: NSObject {
    /// (isPlaying, trackName) — delivered on the main queue.
    var onState: ((Bool, String) -> Void)?

    private lazy var configuration = SPTConfiguration(
        clientID: SpotifyConfig.clientID,
        redirectURL: SpotifyConfig.redirectURL
    )

    private lazy var appRemote: SPTAppRemote = {
        let remote = SPTAppRemote(configuration: configuration, logLevel: .error)
        remote.delegate = self
        return remote
    }()

    private var accessToken: String?

    /// Opens Spotify to authorize, then connects (callback arrives via handleURL).
    func authorizeAndConnect() {
        guard SpotifyConfig.isConfigured else { return }
        appRemote.authorizeAndPlayURI("")
    }

    /// Handle the `zenly://spotify-callback` redirect.
    func handleURL(_ url: URL) {
        guard let params = appRemote.authorizationParameters(from: url) else { return }
        if let token = params[SPTAppRemoteAccessTokenKey] {
            accessToken = token
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        } else if let error = params[SPTAppRemoteErrorDescriptionKey] {
            print("[Zenly] Spotify auth error: \(error)")
        }
    }

    /// Re-establish the connection on foreground without re-authorizing. The
    /// App Remote disconnects whenever Zenly is backgrounded (e.g. during the
    /// auth round-trip), so we must reconnect when we come back.
    func reconnect() {
        guard accessToken != nil, !appRemote.isConnected else { return }
        appRemote.connect()
    }

    func playPause(isPlaying: Bool) {
        guard appRemote.isConnected else {
            // Reconnect with the existing token if we have one; only re-authorize
            // as a last resort (re-authorizing re-opens the Spotify app).
            if accessToken != nil { appRemote.connect() } else { authorizeAndConnect() }
            return
        }
        if isPlaying {
            appRemote.playerAPI?.pause(nil)
        } else {
            appRemote.playerAPI?.resume(nil)
        }
    }

    func next() { appRemote.playerAPI?.skip(toNext: nil) }
    func previous() { appRemote.playerAPI?.skip(toPrevious: nil) }

    private func emit(on queue: DispatchQueue = .main, _ work: @escaping () -> Void) {
        queue.async(execute: work)
    }
}

extension SpotifyController: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: nil)
        // Pull the current state immediately so the UI isn't blank until the
        // first change event.
        appRemote.playerAPI?.getPlayerState { [weak self] result, _ in
            guard let state = result as? SPTAppRemotePlayerState else { return }
            self?.emit { self?.onState?(!state.isPaused, state.track.name) }
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        emit { self.onState?(false, "") }
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        emit { self.onState?(false, "") }
    }
}

extension SpotifyController: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        let playing = !playerState.isPaused
        let track = playerState.track.name
        emit { self.onState?(playing, track) }
    }
}
