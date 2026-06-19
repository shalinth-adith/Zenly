//
//  ResearchBrowserView.swift
//  Zenly
//
//  A distraction-free, AI-gatekept research browser. Because Zenly owns this
//  WKWebView, every top-level navigation is intercepted: the destination is
//  classified (cache → on-device heuristic → Claude Haiku) and either opened
//  within ~2s or replaced with a calm "that looks like entertainment" screen.
//
//  This is the in-app counterpart to system Safari's research mode — the
//  Screen Time API can't run a live per-URL check on Safari, but here we can.
//

import SwiftUI
import WebKit

enum BrowserStatus: Equatable {
    case home
    case checking(String)   // domain being classified
    case browsing
    case blocked(String)    // domain that was blocked
}

struct ResearchBrowserView: View {
    /// Active profile name, shown in the title for context.
    var profileName: String = "Focus"

    @Environment(\.dismiss) private var dismiss
    @State private var model = ResearchBrowserModel()
    @State private var address = ""
    @FocusState private var addressFocused: Bool

    private let suggestions = ["wikipedia.org", "stackoverflow.com", "claude.ai", "arxiv.org"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addressBar
                Divider()
                content
            }
            .navigationTitle("Research")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.goBack()
                    } label: { Image(systemName: "chevron.backward") }
                        .disabled(!model.canGoBack)
                        .accessibilityLabel("Back")
                }
            }
        }
    }

    // MARK: - Pieces

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Search a topic or enter a site", text: $address)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit { submit() }
            if !address.isEmpty {
                Button {
                    address = ""
                } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            // The web view is always mounted so it keeps its back/forward history.
            WebViewContainer(webView: model.webView)
                .opacity(model.status == .browsing ? 1 : 0)

            switch model.status {
            case .home:
                homeScreen
            case .checking(let domain):
                checkingScreen(domain)
            case .blocked(let domain):
                blockedScreen(domain)
            case .browsing:
                EmptyView()
            }
        }
    }

    private var homeScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
            Text("Focused research")
                .font(.title3.bold())
            Text("Knowledge and reference sites open here. Entertainment is held back automatically while you focus.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { site in
                    Button {
                        address = site
                        submit()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text(site)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(site)")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func checkingScreen(_ domain: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Checking \(domain)…")
                .font(.headline)
            Text("Making sure this is research, not a rabbit hole.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func blockedScreen(_ domain: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color(hex: "5C6BFA"))
            Text("Held back")
                .font(.title2.bold())
            Text("\(domain) looks like entertainment. Stay in your focus — try a knowledge or reference site instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                model.status = model.canGoBack ? .browsing : .home
                if model.canGoBack { model.goBack() }
                address = ""
                addressFocused = true
            } label: {
                Label("Search something else", systemImage: "magnifyingglass")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "5C6BFA"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func submit() {
        addressFocused = false
        model.go(address)
    }
}

/// Thin UIViewRepresentable that hosts the model's stable WKWebView instance.
private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Owns the WKWebView, classifier, and navigation gate.
@MainActor
@Observable
final class ResearchBrowserModel: NSObject, WKNavigationDelegate {
    let webView = WKWebView()
    var status: BrowserStatus = .home
    var canGoBack = false

    private let classifier = WebClassifier()

    override init() {
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    /// Normalise an address-bar entry: a bare domain becomes https://, anything
    /// that isn't a URL becomes a web search.
    func go(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url: URL
        if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)")
                ?? Self.searchURL(trimmed)
        } else {
            url = Self.searchURL(trimmed)
        }
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        if webView.canGoBack {
            status = .browsing
            webView.goBack()
        }
    }

    private static func searchURL(_ query: String) -> URL {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://duckduckgo.com/?q=\(q)")!
    }

    private static func baseDomain(from host: String) -> String {
        host.lowercased().hasPrefix("www.") ? String(host.dropFirst(4)) : host.lowercased()
    }

    // MARK: - Navigation gate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard
            let url = navigationAction.request.url,
            navigationAction.targetFrame?.isMainFrame ?? true,
            let scheme = url.scheme, scheme == "http" || scheme == "https",
            let host = url.host
        else {
            decisionHandler(.allow)
            return
        }

        let domain = Self.baseDomain(from: host)

        // Search engines are always allowed — they're the research entry point.
        if domain.contains("duckduckgo.com") {
            decisionHandler(.allow)
            return
        }

        if let verdict = classifier.cachedVerdict(for: domain) {
            if verdict == .entertainment {
                status = .blocked(domain)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
            return
        }

        // Unknown: cancel, classify, then re-navigate if it's knowledge.
        decisionHandler(.cancel)
        status = .checking(domain)
        Task {
            let verdict = await classifier.classify(domain: domain, url: url.absoluteString)
            if verdict == .entertainment {
                status = .blocked(domain)
            } else {
                status = .browsing
                webView.load(URLRequest(url: url)) // now cached → allowed
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        status = .browsing
        canGoBack = webView.canGoBack
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        canGoBack = webView.canGoBack
        // Leave our own transient states alone; otherwise settle on the page.
        if case .checking = status { return }
        if case .blocked = status { return }
        status = .browsing
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        canGoBack = webView.canGoBack
        // A cancelled navigation (our gate) reports here — don't treat it as an error state.
        if case .checking = status { return }
        if case .blocked = status { return }
        status = webView.url == nil ? .home : .browsing
    }
}
