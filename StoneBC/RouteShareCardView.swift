//
//  RouteShareCardView.swift
//  StoneBC
//
//  Shareable route card image for social media — rendered via ImageRenderer
//

import SwiftUI
import MapKit

struct RouteShareCardView: View {
    let route: Route

    var body: some View {
        VStack(spacing: 0) {
            // Map section
            Map {
                MapPolyline(coordinates: route.clTrackpoints)
                    .stroke(BCColors.brandBlue, lineWidth: 3)
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 280)
            .allowsHitTesting(false)

            // Info section
            VStack(spacing: 16) {
                // Route name + badges
                VStack(spacing: 8) {
                    Text(route.name)
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        DifficultyBadge(difficulty: route.difficulty)
                        CategoryBadge(category: route.category)
                    }
                }

                // Stats row
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(BCColors.brandBlue)
                        Text(route.formattedDistance)
                            .font(.system(size: 15, weight: .semibold))
                        Text("DISTANCE")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14))
                            .foregroundColor(BCColors.brandGreen)
                        Text(route.formattedElevation)
                            .font(.system(size: 15, weight: .semibold))
                        Text("ELEVATION")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        Image(systemName: "mountain.2")
                            .font(.system(size: 14))
                            .foregroundColor(BCColors.brandAmber)
                        Text(route.elevationRange)
                            .font(.system(size: 15, weight: .semibold))
                        Text("RANGE")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.secondary)
                    }
                }

                // Branding
                HStack(spacing: 6) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 10))
                    Text("Stone Bicycle Coalition")
                        .font(.system(size: 10, weight: .medium))
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(route.region)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(BCColors.cardBackground)
        }
        .frame(width: 400)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 4)
    }

    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

#Preview {
    RouteShareCardView(route: .preview)
        .padding()
        .background(Color.gray.opacity(0.2))
}
