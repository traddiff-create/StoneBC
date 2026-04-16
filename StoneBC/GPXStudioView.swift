//
//  GPXStudioView.swift
//  StoneBC
//
//  WKWebView wrapper for gpx.studio route embeds
//

import SwiftUI
import WebKit

struct GPXStudioView: UIViewRepresentable {
    let gpxURL: String
    var centerLat: Double = 44.05
    var centerLon: Double = -103.7
    var zoom: Int = 9

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = embedURL else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var embedURL: URL? {
        let options: [String: Any] = [
            "files": [gpxURL],
            "basemap": "openTopoMap",
            "elevation": ["show": true, "fill": "slope"],
            "distanceMarkers": true,
            "directionMarkers": true,
            "theme": "dark",
            "distanceUnits": "imperial"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: options),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "https://gpx.studio/embed?options=\(encoded)#\(zoom)/\(centerLat)/\(centerLon)"
        return URL(string: urlString)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow gpx.studio and tile server requests
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               !(url.host?.contains("gpx.studio") ?? false) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// Convenience wrapper with loading state
struct GPXStudioMapView: View {
    let gpxURL: String
    var centerLat: Double = 44.05
    var centerLon: Double = -103.7
    var zoom: Int = 9
    @State private var isLoading = true

    var body: some View {
        ZStack {
            GPXStudioView(gpxURL: gpxURL, centerLat: centerLat, centerLon: centerLon, zoom: zoom)

            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading route...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            // Dismiss loading after a reasonable delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { isLoading = false }
            }
        }
    }
}
