//
//  WebDomainList.swift
//  Zenly (shared: app + ZenlyMonitor)
//
//  Parses a free-text list of allowed websites (for "research mode") into
//  sanitized WebDomain values. Users type domains like "claude.ai, docs.google.com".
//

import Foundation
import ManagedSettings

enum WebDomainList {
    /// Split on commas / newlines / spaces, sanitize, drop empties.
    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { ",\n ".contains($0) })
            .map { sanitize(String($0)) }
            .filter { !$0.isEmpty }
    }

    /// Strip scheme, "www.", and any path — leaving a bare host like "claude.ai".
    static func sanitize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: "https://", with: "")
        s = s.replacingOccurrences(of: "http://", with: "")
        if s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        return s
    }

    static func domains(from text: String) -> Set<WebDomain> {
        Set(parse(text).map { WebDomain(domain: $0) })
    }
}
