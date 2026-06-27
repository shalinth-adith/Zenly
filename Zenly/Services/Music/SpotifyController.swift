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

    private static let tokenKey = "spotifyAccessToken"

    /// The App Remote access token, persisted so a connection established once
    /// survives relaunches — the user authorizes only when there's no token (or
    /// the stored one has expired and reconnect fails).
    private var accessToken: String? {
        didSet { AppGroup.defaults.set(accessToken, forKey: Self.tokenKey) }
    }

    override init() {
        super.init()
        accessToken = AppGroup.defaults.string(forKey: Self.tokenKey)
    }

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
            connectWithToken()
        } else if let error = params[SPTAppRemoteErrorDescriptionKey] {
            print("[Zenly] Spotify auth error: \(error)")
        }
    }

    /// Re-establish the connection on foreground without re-authorizing. The
    /// App Remote disconnects whenever Zenly is backgrounded (e.g. during the
    /// auth round-trip), so we must reconnect when we come back. Uses the stored
    /// token, so it never re-opens the Spotify app.
    func reconnect() {
        guard accessToken != nil, !appRemote.isConnected else { return }
        connectWithToken()
    }

    /// Connect using the persisted token. The token must be re-applied to the
    /// connection parameters on a cold launch — handleURL only set it for the
    /// session that authorized. Falls back to authorization only if absent.
    private func connectWithToken() {
        guard let token = accessToken else { authorizeAndConnect(); return }
        appRemote.connectionParameters.accessToken = token
        appRemote.connect()
    }

    func playPause(isPlaying: Bool) {
        guard appRemote.isConnected else {
            // Reconnect with the existing token if we have one; only re-authorize
            // as a last resort (re-authorizing re-opens the Spotify app).
            if accessToken != nil { connectWithToken() } else { authorizeAndConnect() }
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
