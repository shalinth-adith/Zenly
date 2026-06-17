//
//  SpotifyConfig.swift
//  Zenly
//
//  Spotify App Remote credentials. The Client ID comes from your app at
//  developer.spotify.com/dashboard; the redirect URI must be registered there
//  EXACTLY as below and is declared as a URL scheme in Info.plist.
//

import Foundation

enum SpotifyConfig {
    /// Paste your Spotify app Client ID here.
    static let clientID = "f61575ac4b414d5eb8b683836cf23f96"

    /// Must match a Redirect URI registered in the Spotify dashboard.
    static let redirectURL = URL(string: "zenly://spotify-callback")!

    static var isConfigured: Bool { !clientID.isEmpty }
}
