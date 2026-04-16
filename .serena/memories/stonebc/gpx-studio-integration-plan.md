# gpx.studio WKWebView Integration Plan for StoneBC

**Date:** 2026-04-10
**Status:** Implementation ready
**Scope:** Add interactive route visualization via gpx.studio embeds

## Integration Architecture

### 1. Data Model Changes Required

#### TourGuide.swift additions:
```swift
// Add optional gpxURL fields to TourGuide
struct TourGuide: Codable, Identifiable {
    // ... existing fields ...
    var gpxStudioURL: String?  // e.g., "https://gpx.studio/?url=..."
}

// Add optional gpxURL to TourDay
struct TourDay: Codable {
    // ... existing fields ...
    var gpxStudioURL: String?  // Allows per-day map view
}
```

#### Route.swift additions:
```swift
struct Route: Codable, Identifiable {
    // ... existing fields ...
    var gpxStudioURL: String?  // Full route map URL
}
```

#### Updated guides.json structure:
```json
{
  "id": "8-over-7",
  "name": "8 Over 7",
  "gpxStudioURL": "https://gpx.studio/?url=...",
  "days": [
    {
      "dayNumber": 1,
      "name": "Spearfish Loop",
      "routeFile": "8over7_day1",
      "gpxStudioURL": "https://gpx.studio/?url=...",
      "trackpoints": [[...]]
    }
  ]
}
```

### 2. WKWebView UIViewRepresentable Wrapper

**New file:** `StoneBC/WebView/GPXStudioWebView.swift`

```swift
import SwiftUI
import WebKit

struct GPXStudioWebView: UIViewRepresentable {
    let gpxURL: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor(Color(.windowBackgroundColor))
        
        if let url = URL(string: gpxURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // URL updates handled via state change triggering new view
    }
}

// Container view with loading state
struct GPXStudioContainer: View {
    let gpxURL: String?
    @State private var isLoading = false
    
    var body: some View {
        if let gpxURL = gpxURL {
            GPXStudioWebView(gpxURL: gpxURL)
                .frame(minHeight: 400)
        } else {
            ContentUnavailableView(
                "Map Not Available",
                systemImage: "map",
                description: Text("No gpx.studio map available for this route")
            )
        }
    }
}
```

### 3. Integration Points

#### TourGuideDetailView.swift
**Location:** After dayOverview section, before stopsTimeline

```swift
// Add new state property
@State private var showDayMap = false

// Add map preview card in dayOverview section
DisclosureGroup("Map View", isExpanded: $showDayMap) {
    GPXStudioContainer(gpxURL: currentDay.gpxStudioURL)
        .cornerRadius(12)
        .padding(.vertical, 8)
}

// Or use fullScreenCover for expanded view
.fullScreenCover(isPresented: $showMapFull) {
    ZStack {
        GPXStudioContainer(gpxURL: currentDay.gpxStudioURL)
        VStack {
            HStack {
                Button(action: { showMapFull = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            Spacer()
        }
    }
}
```

#### RouteDetailView.swift
**Location:** Replace mapPreview section (~line 180-220)

```swift
// Current code:
// var mapPreview: some View {
//     Map(position: .constant(.region(routeRegion))) {
//         MapPolyline(coordinates: route.coordinates)
//             .stroke(.blue, lineWidth: 3)
//     }
// }

// NEW CODE:
var mapPreview: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Interactive Map")
            .font(.headline)
            .padding(.horizontal)
        
        GPXStudioContainer(gpxURL: route.gpxStudioURL)
            .frame(height: 400)
            .cornerRadius(12)
            .padding()
        
        if route.gpxStudioURL == nil {
            // Fallback to MapKit for offline routes
            fallbackMapPreview
        }
    }
}

var fallbackMapPreview: some View {
    Map(position: .constant(.region(routeRegion))) {
        MapPolyline(coordinates: route.coordinates)
            .stroke(.blue, lineWidth: 3)
    }
    .frame(height: 300)
    .cornerRadius(12)
    .padding()
}
```

#### New Optional Feature: Dedicated Web View Tab
**Could add 6th NavigationStack or Modal:**
- Browse all routes with full gpx.studio embeds
- Compare multiple route maps side-by-side
- Filter by difficulty/region with live map preview

### 4. URL Construction for gpx.studio

```swift
// Helper method to add to GPXService or Route model
func generateGPXStudioURL(gpxData: String, title: String) -> String {
    let encodedData = gpxData.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    return "https://gpx.studio/?gpx=\(encodedData)&title=\(title)"
}

// Or use hosted GPX files:
func generateGPXStudioURL(from gpxFileURL: String) -> String {
    return "https://gpx.studio/?url=\(gpxFileURL)"
}
```

### 5. Implementation Sequence

1. **Phase 1 (Minimal):** Add gpxURL field to Route model, integrate into RouteDetailView.swift
   - Change required: 1 file (Route.swift) + 1 file (RouteDetailView.swift)
   - Data source: Hardcode URLs initially for testing, add to routes.json later
   - Testing: Manual with RouteDetailView, verify WebView loads gpx.studio

2. **Phase 2 (Tour Guides):** Add gpxURL to TourGuide/TourDay, integrate into TourGuideDetailView.swift
   - Change required: 3 files (TourGuide.swift, TourGuideDetailView.swift, guides.json)
   - Testing: Manual with TourGuideDetailView day picker

3. **Phase 3 (Production):** Generate URLs from actual GPX files, update JSON data sources
   - Process_routes.py enhancement: calculate gpx.studio URLs during route processing
   - Hosting: Use CDN for GPX files (Netlify, Cloudflare, or AWS S3)
   - Testing: Full QA suite with 25 Blitz tests per session conventions

### 6. Performance Considerations

- WKWebView loads remotely (requires network)
- Cache strategy: WKWebViewConfiguration can cache pages
- Fallback: Keep MapKit views as offline-capable backup
- Memory: WKWebView instances are relatively lightweight, but avoid loading multiple simultaneously
- Battery: Web view may consume more power than native MapKit

### 7. Security & Compliance

- gpx.studio is open-source, third-party service (verify SSL/TLS)
- No sensitive user data transmitted to gpx.studio (public routes only)
- Consider adding privacy policy note: "Interactive maps powered by gpx.studio"
- Verify compliance with app privacy requirements before shipping

### 8. Testing Checklist

- [ ] WKWebView loads and renders gpx.studio successfully
- [ ] URL encoding/construction produces valid URLs
- [ ] Offline fallback (MapKit) appears when gpxURL is nil
- [ ] Loading states handled gracefully
- [ ] Memory management: WebView properly deallocated on dismiss
- [ ] Network errors handled (show error state vs. blank screen)
- [ ] Data model changes serialize/deserialize correctly
- [ ] Existing routes without gpxURL don't break (nil coalescing)
- [ ] Tab navigation doesn't create duplicate WebView instances

### 9. Future Enhancements

- gpx.studio URL parameters for initial zoom/center point
- Share map view (Screenshot of gpx.studio + route link)
- Download GPX from gpx.studio integration
- Multi-route comparison view
- Route difficulty overlay on map
- Weather overlay integration
