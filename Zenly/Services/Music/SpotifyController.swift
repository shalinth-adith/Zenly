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

    /// Opens Spotify to authorize, then connects (callback arrives via handleURL).
    func authorizeAndConnect() {
        guard SpotifyConfig.isConfigured else { return }
        appRemote.authorizeAndPlayURI("")
    }

    /// Handle the `zenly://spotify-callback` redirect.
    func handleURL(_ url: URL) {
        guard let params = appRemote.authorizationParameters(from: url) else { return }
        if let token = params[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        }
    }

    func playPause(isPlaying: Bool) {
        guard appRemote.isConnected else { authorizeAndConnect(); return }
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
