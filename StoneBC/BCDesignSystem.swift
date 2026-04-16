//
//  BCDesignSystem.swift
//  StoneBC
//
//  Centralized design tokens for Stone Bicycle Coalition brand
//

import SwiftUI
import UIKit

// MARK: - Colors (Dark Mode Adaptive)
enum BCColors {
    // Brand
    static let brandBlue = Color(red: 0.145, green: 0.388, blue: 0.922)     // #2563eb
    static let brandGreen = Color(red: 0.020, green: 0.588, blue: 0.412)    // #059669
    static let brandAmber = Color(red: 0.961, green: 0.620, blue: 0.043)    // #f59e0b

    // Backgrounds
    static let background = Color(UIColor.systemBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)

    // Foreground
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color(UIColor.tertiaryLabel)

    // Accent
    static let accent = brandBlue
    static let accentForeground = Color.white

    // UI Elements
    static let divider = Color(UIColor.separator)
    static let fill = Color(UIColor.systemFill)
    static let secondaryFill = Color(UIColor.secondarySystemFill)

    // Overlays
    static let overlayLight = Color.primary.opacity(0.05)
    static let overlayMedium = Color.primary.opacity(0.1)
    static let overlayStrong = Color.primary.opacity(0.15)

    // Difficulty
    static func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "moderate": return .yellow
        case "hard": return .orange
        case "expert": return .red
        default: return .gray
        }
    }

    // Category
    static func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "road": return brandBlue
        case "gravel": return brandAmber
        case "fatbike": return .cyan
        case "trail": return brandGreen
        default: return .gray
        }
    }
}

// MARK: - Spacing
enum BCSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Typography
extension Font {
    static let bcHero = Font.system(size: 28, weight: .light)
    static let bcSectionTitle = Font.system(size: 11, weight: .medium)
    static let bcPrimaryText = Font.system(size: 15, weight: .medium)
    static let bcSecondaryText = Font.system(size: 12, weight: .regular)
    static let bcCaption = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let bcMicro = Font.system(size: 9, weight: .medium)
    static let bcLabel = Font.system(size: 10, weight: .medium)
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    init(title: String, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .tracking(0.5)
                if let count = count, isSelected {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? BCColors.accent : BCColors.secondaryFill)
            .foregroundColor(isSelected ? BCColors.accentForeground : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filterChip_\(title)")
        .accessibilityLabel("\(title)\(count != nil ? ", \(count!) items" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to filter by \(title)")
    }
}

// MARK: - Difficulty Badge
struct DifficultyBadge: View {
    let difficulty: String

    var body: some View {
        Text(difficulty.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BCColors.difficultyColor(difficulty).opacity(0.2))
            .foregroundColor(BCColors.difficultyColor(difficulty))
            .clipShape(Capsule())
            .accessibilityLabel("Difficulty: \(difficulty)")
    }
}

// MARK: - Category Badge
struct CategoryBadge: View {
    let category: String

    private var icon: String {
        switch category.lowercased() {
        case "road": return "road.lanes"
        case "gravel": return "mountain.2"
        case "fatbike": return "snowflake"
        case "trail": return "leaf"
        default: return "bicycle"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(category.capitalized)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(BCColors.categoryColor(category).opacity(0.15))
        .foregroundColor(BCColors.categoryColor(category))
        .clipShape(Capsule())
        .accessibilityLabel("Category: \(category)")
    }
}

// MARK: - Trail Condition Badge
struct TrailConditionBadge: View {
    let condition: TrailCondition

    private var color: Color {
        switch condition.badgeColor {
        case "green": .green
        case "red": .red
        case "orange": .orange
        default: .gray
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: condition.icon)
                .font(.system(size: 8))
            Text(condition.displayLabel)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.3)
            if condition.reportCount > 1 {
                Text("(\(condition.reportCount))")
                    .font(.system(size: 7))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
        .accessibilityLabel("Trail condition: \(condition.displayLabel)")
    }
}

// MARK: - Route Stat Row
struct RouteStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(BCColors.tertiaryText)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(BCColors.secondaryText)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

// MARK: - Metadata Item
struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(BCColors.tertiaryText)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(BCColors.secondaryText)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Previews
#Preview("Filter Chips") {
    HStack(spacing: 8) {
        FilterChip(title: "All", count: 15, isSelected: true) {}
        FilterChip(title: "Gravel", count: 8, isSelected: false) {}
        FilterChip(title: "Road", count: 5, isSelected: false) {}
    }
    .padding()
}

#Preview("Difficulty Badges") {
    HStack(spacing: 8) {
        DifficultyBadge(difficulty: "easy")
        DifficultyBadge(difficulty: "moderate")
        DifficultyBadge(difficulty: "hard")
        DifficultyBadge(difficulty: "expert")
    }
    .padding()
}

#Preview("Category Badges") {
    HStack(spacing: 8) {
        CategoryBadge(category: "road")
        CategoryBadge(category: "gravel")
        CategoryBadge(category: "fatbike")
        CategoryBadge(category: "trail")
    }
    .padding()
}

#Preview("Route Stat Row") {
    VStack(spacing: 12) {
        RouteStatRow(icon: "arrow.left.arrow.right", label: "Distance", value: "42.5 miles")
        RouteStatRow(icon: "arrow.up.right", label: "Elevation", value: "3,200 ft")
        RouteStatRow(icon: "mappin", label: "Region", value: "Black Hills")
    }
    .padding()
}
