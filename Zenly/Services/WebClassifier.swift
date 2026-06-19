//
//  WebClassifier.swift
//  Zenly
//
//  Decides whether a website is KNOWLEDGE (educational/reference/productivity)
//  or ENTERTAINMENT (social/video/games/shopping) for the Research Browser.
//
//  Three tiers, in order:
//    1. In-memory cache — each domain is classified once, then instant.
//    2. On-device heuristic — built-in domain lists; instant, private, no key.
//    3. Claude Haiku (raw HTTPS to the Anthropic Messages API) — only for
//       domains the heuristic doesn't recognise, returns in ~1–2s.
//
//  Swift has no official Anthropic SDK, so this calls the API over URLSession.
//

import Foundation

enum WebVerdict: String {
    case knowledge
    case entertainment
    case unknown
}

final class WebClassifier {

    // Per-browser cache of decided domains.
    private var cache: [String: WebVerdict] = [:]

    /// Synchronous cache lookup — used by the navigation gate to decide instantly
    /// for already-seen domains (no flash, no re-check).
    func cachedVerdict(for domain: String) -> WebVerdict? { cache[domain.lowercased()] }

    /// Classify a domain. Known domains resolve instantly via the heuristic;
    /// genuinely unknown ones ask Claude (if a key is configured). Falls back to
    /// "knowledge" (permissive) when there's no signal, so the browser stays usable.
    func classify(domain: String, url: String) async -> WebVerdict {
        let key = domain.lowercased()
        if let cached = cache[key] { return cached }

        // Tier 2 — instant local decision for recognised domains.
        let local = heuristic(for: key)
        if local != .unknown {
            cache[key] = local
            return local
        }

        // Tier 3 — ask Claude only for the genuinely unknown.
        if AIConfig.isConfigured, let ai = await classifyWithClaude(domain: key, url: url) {
            cache[key] = ai
            return ai
        }

        // No signal: allow, so an unrecognised site without a key isn't dead-ended.
        cache[key] = .knowledge
        return .knowledge
    }

    // MARK: - Tier 2: on-device heuristic

    /// Bare second-level domains that are clearly entertainment/distraction.
    private let entertainmentDomains: Set<String> = [
        "youtube.com", "youtu.be", "netflix.com", "twitch.tv", "tiktok.com",
        "instagram.com", "facebook.com", "twitter.com", "x.com", "reddit.com",
        "snapchat.com", "pinterest.com", "tumblr.com", "9gag.com", "imgur.com",
        "hulu.com", "disneyplus.com", "primevideo.com", "hotstar.com", "spotify.com",
        "soundcloud.com", "amazon.com", "ebay.com", "aliexpress.com", "flipkart.com",
        "buzzfeed.com", "tmz.com", "ign.com", "roblox.com", "steampowered.com",
        "epicgames.com", "discord.com", "whatsapp.com", "telegram.org", "onlyfans.com",
    ]

    /// Bare second-level domains that are clearly knowledge/productivity.
    private let knowledgeDomains: Set<String> = [
        "wikipedia.org", "stackoverflow.com", "stackexchange.com", "github.com",
        "gitlab.com", "developer.apple.com", "developer.mozilla.org", "arxiv.org",
        "paperswithcode.com", "scholar.google.com", "docs.google.com", "drive.google.com",
        "notion.so", "claude.ai", "anthropic.com", "chatgpt.com", "openai.com",
        "wolframalpha.com", "khanacademy.org", "coursera.org", "edx.org", "udemy.com",
        "medium.com", "dev.to", "readthedocs.io", "w3schools.com", "geeksforgeeks.org",
        "nature.com", "sciencedirect.com", "jstor.org", "pubmed.ncbi.nlm.nih.gov",
        "overleaf.com", "kaggle.com", "huggingface.co", "leetcode.com", "wikimedia.org",
    ]

    private func heuristic(for domain: String) -> WebVerdict {
        // Educational / government TLDs are reference by default.
        if domain.hasSuffix(".edu") || domain.hasSuffix(".gov") || domain.hasSuffix(".ac.uk") {
            return .knowledge
        }
        if entertainmentDomains.contains(domain) { return .entertainment }
        if knowledgeDomains.contains(domain) { return .knowledge }
        // Match a base domain when the host is a subdomain (e.g. m.youtube.com).
        if let base = entertainmentDomains.first(where: { domain.hasSuffix("." + $0) }) {
            _ = base; return .entertainment
        }
        if knowledgeDomains.contains(where: { domain.hasSuffix("." + $0) }) {
            return .knowledge
        }
        return .unknown
    }

    // MARK: - Tier 3: Claude Haiku (raw HTTPS)

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private let systemPrompt = """
    You classify a website for a focus/study app. KNOWLEDGE = educational, reference, \
    documentation, research, news/articles for learning, developer tools, productivity, \
    or AI assistants. ENTERTAINMENT = social media, video streaming, games, shopping, \
    memes, or gossip. Reply with exactly one word: KNOWLEDGE or ENTERTAINMENT.
    """

    private func classifyWithClaude(domain: String, url: String) async -> WebVerdict? {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 4 // keep the gate snappy
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AIConfig.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": AIConfig.classifierModel,
            "max_tokens": 8,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Domain: \(domain)\nURL: \(url)"]
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard
                let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                let content = json["content"] as? [[String: Any]],
                let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
            else { return nil }

            let upper = text.uppercased()
            if upper.contains("ENTERTAINMENT") { return .entertainment }
            if upper.contains("KNOWLEDGE") { return .knowledge }
            return nil
        } catch {
            return nil // network/timeout → caller falls back
        }
    }
}
