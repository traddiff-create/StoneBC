//
//  BCDesignSystem.swift
//  StoneBC
//
//  Strict RIDR cockpit design tokens and SwiftUI primitives.
//

import SwiftUI
import UIKit

// MARK: - Colors

enum BCColors {
    private static var configuredBrandBlue = Color(hex: "#2563eb", fallback: signalPrimary)
    private static var configuredBrandGreen = Color(hex: "#059669", fallback: signalOK)
    private static var configuredBrandAmber = Color(hex: "#f59e0b", fallback: signalWarn)

    static func configure(with colors: AppConfig.BrandColors) {
        configuredBrandBlue = Color(hex: colors.brandBlue, fallback: configuredBrandBlue)
        configuredBrandGreen = Color(hex: colors.brandGreen, fallback: configuredBrandGreen)
        configuredBrandAmber = Color(hex: colors.brandAmber, fallback: configuredBrandAmber)
    }

    // Coalition identity colors remain available for forks and document/export contexts.
    static var coalitionBlue: Color { configuredBrandBlue }
    static var coalitionGreen: Color { configuredBrandGreen }
    static var coalitionAmber: Color { configuredBrandAmber }

    // RIDR material case
    static let caseInk = Color(hex: 0x0B0B0C)
    static let caseDial = Color(hex: 0x131316)
    static let caseSub = Color(hex: 0x1C1C20)
    static let caseGunmetal = Color(hex: 0x3A3A3A)
    static let caseShadow = Color(hex: 0x6E6E6C)
    static let caseSteelMid = Color(hex: 0xA4A4A1)
    static let caseBrushed = Color(hex: 0xD6D6D3)
    static let caseFrame = Color(hex: 0x2A2A2E)

    // RIDR signal instruments
    static let signalPrimary = Color(hex: 0x2D4F3A)
    static let signalDeep = Color(hex: 0x1A3324)
    static let signalLume = Color(hex: 0xA8C49A)
    static let signalMoss = Color(hex: 0x6B8F5E)
    static let signalAlert = Color(hex: 0xA33B2B)
    static let signalWarn = Color(hex: 0xC8954A)
    static let signalOK = Color(hex: 0x7AA886)

    // Document surfaces
    static let docBone = Color(hex: 0xE9E4D8)
    static let docPaper = Color(hex: 0xEFECE3)

    // Compatibility aliases used throughout the existing app.
    static var brandBlue: Color { signalPrimary }
    static var brandGreen: Color { signalOK }
    static var brandAmber: Color { signalWarn }

    static let cockpitBlack = caseInk
    static let cockpitGraphite = caseDial
    static let cockpitSteel = caseSteelMid
    static let cockpitLume = signalLume

    static let navPanel = caseInk
    static let navTileHighlight = Color.white.opacity(0.05)
    static var navAlertAmber: Color { signalWarn }
    static let navAlertRed = signalAlert

    static let background = caseInk
    static let cardBackground = caseDial
    static let tertiaryBackground = caseSub
    static let instrumentPanel = caseDial
    static let instrumentInset = caseSub
    static let instrumentRaised = caseSub

    static let primaryText = caseBrushed
    static let secondaryText = caseSteelMid
    static let tertiaryText = caseShadow
    static let cockpitMutedText = caseSteelMid

    static var accent: Color { signalPrimary }
    static let accentForeground = caseInk
    static let danger = signalAlert

    static let divider = caseShadow
    static let hairline = caseShadow
    static let fill = caseGunmetal
    static let secondaryFill = caseSub
    static let instrumentFill = caseSub

    static let overlayLight = Color.white.opacity(0.05)
    static let overlayMedium = Color.white.opacity(0.10)
    static let overlayStrong = Color.white.opacity(0.15)

    static func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return signalOK
        case "moderate": return signalMoss
        case "hard": return signalWarn
        case "expert": return signalAlert
        default: return caseSteelMid
        }
    }

    static func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "road": return signalPrimary
        case "gravel": return signalWarn
        case "fatbike": return signalLume
        case "trail": return signalMoss
        case "brewery": return signalWarn
        case "touring": return signalPrimary
        default: return caseSteelMid
        }
    }
}

extension Color {
    init(hex value: UInt64) {
        self = Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }

    init(hex: String, fallback: Color) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var value: UInt64 = 0

        guard cleaned.count == 6,
              Scanner(string: cleaned).scanHexInt64(&value) else {
            self = fallback
            return
        }

        self = Color(hex: value)
    }
}

// MARK: - Layout Tokens

enum BCSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum BCRadius {
    static let control: CGFloat = 0
    static let card: CGFloat = 0
    static let tile: CGFloat = 0
    static let pill: CGFloat = 0
    static let screw: CGFloat = 2
}

// MARK: - Typography

extension Font {
    static let ridrDisplayXL = Font.custom("StardosStencil-Bold", size: 88, relativeTo: .largeTitle)
    static let ridrDisplayLG = Font.custom("StardosStencil-Bold", size: 56, relativeTo: .largeTitle)
    static let ridrDisplayMD = Font.custom("StardosStencil-Bold", size: 32, relativeTo: .title)
    static let ridrDisplaySM = Font.custom("StardosStencil-Bold", size: 22, relativeTo: .title3)
    static let ridrDataLG = Font.custom("JetBrainsMonoRoman-Bold", size: 32, relativeTo: .title)
    static let ridrDataMD = Font.custom("JetBrainsMonoRoman-Bold", size: 17, relativeTo: .body)
    static let ridrHeading = Font.custom("ArchivoNarrow-Bold", size: 14, relativeTo: .headline)
    static let ridrBody = Font.custom("ArchivoRoman-Regular", size: 15, relativeTo: .body)
    static let ridrBodySmall = Font.custom("ArchivoRoman-Regular", size: 13, relativeTo: .caption)
    static let ridrMicro = Font.custom("JetBrainsMonoRoman-Medium", size: 11, relativeTo: .caption2)

    static let bcHero = ridrDisplayMD
    static let bcSectionTitle = ridrHeading
    static let bcPrimaryText = ridrBody
    static let bcSecondaryText = ridrBodySmall
    static let bcCaption = ridrDataMD
    static let bcMicro = ridrMicro
    static let bcLabel = ridrMicro
    static let bcInstrumentValue = ridrDisplaySM
    static let bcInstrumentLabel = ridrMicro
}

// MARK: - RIDR Primitives

struct RIDRScrew: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BCRadius.screw, style: .continuous)
                .fill(BCColors.caseGunmetal)
                .overlay {
                    RoundedRectangle(cornerRadius: BCRadius.screw, style: .continuous)
                        .stroke(BCColors.caseShadow, lineWidth: 1)
                }

            Rectangle()
                .fill(BCColors.caseInk)
                .frame(width: size * 0.64, height: 1)
                .rotationEffect(.degrees(-35))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct RIDRTickRow: View {
    var count = 21
    var majorEvery = 5
    var color: Color = BCColors.caseShadow
    var activeCount = 0
    var activeColor: Color = BCColors.signalPrimary

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Rectangle()
                    .fill(index < activeCount ? activeColor : color)
                    .frame(width: 1, height: index % majorEvery == 0 ? 12 : 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct RIDRCaseFrame: View {
    var showScrews = false

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(BCColors.caseFrame, lineWidth: 1)

            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
                Spacer(minLength: 0)
            }

            if showScrews {
                VStack {
                    HStack {
                        RIDRScrew()
                        Spacer()
                        RIDRScrew()
                    }
                    Spacer()
                    HStack {
                        RIDRScrew()
                        Spacer()
                        RIDRScrew()
                    }
                }
                .padding(10)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct RIDRStatusHeader: View {
    let left: String
    var right: String?
    var isLive = false

    var body: some View {
        HStack(spacing: 8) {
            if isLive {
                Rectangle()
                    .fill(BCColors.signalAlert)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }

            Text(left.uppercased())
                .font(.ridrMicro)
                .tracking(2.4)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 12)

            if let right {
                Text(right.uppercased())
                    .font(.ridrMicro)
                    .tracking(2.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .foregroundColor(BCColors.caseSteelMid)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { BCHairline() }
        .overlay(alignment: .bottom) { BCHairline() }
        .accessibilityElement(children: .combine)
    }
}

enum RIDRMetricRole: Equatable {
    case primary
    case power
    case heart
    case warning
    case ok
    case neutral

    var color: Color {
        switch self {
        case .primary: BCColors.signalLume
        case .power: BCColors.signalPrimary
        case .heart: BCColors.signalAlert
        case .warning: BCColors.signalWarn
        case .ok: BCColors.signalOK
        case .neutral: BCColors.caseBrushed
        }
    }
}

struct RIDRMetricTile: View {
    let label: String
    let value: String
    var unit: String?
    var role: RIDRMetricRole = .neutral
    var isPrimary = false
    var activeTicks = 0

    var body: some View {
        VStack(alignment: .leading, spacing: isPrimary ? 16 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.ridrMicro)
                    .tracking(2.4)
                    .foregroundColor(BCColors.caseShadow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 8)

                if let unit {
                    Text(unit.uppercased())
                        .font(.ridrMicro)
                        .tracking(2.4)
                        .foregroundColor(BCColors.caseShadow)
                        .lineLimit(1)
                }
            }

            Text(value)
                .font(isPrimary ? .ridrDisplayLG : .ridrDisplaySM)
                .foregroundColor(role.color)
                .lineLimit(1)
                .minimumScaleFactor(0.44)

            RIDRTickRow(activeCount: activeTicks, activeColor: role == .primary ? BCColors.signalPrimary : role.color)
        }
        .padding(.init(top: 18, leading: 18, bottom: 14, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BCColors.caseSub)
        .overlay { RIDRCaseFrame() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)\(unit.map { " \($0)" } ?? "")")
    }
}

struct RIDRBadge: View {
    let text: String
    var icon: String?
    var color: Color = BCColors.caseSteelMid
    var isLive = false

    var body: some View {
        HStack(spacing: 5) {
            if isLive {
                Rectangle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }

            Text(text.uppercased())
                .font(.ridrMicro)
                .tracking(1.8)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .overlay {
            Rectangle()
                .stroke(color, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RIDRButton: View {
    let title: String
    var systemImage: String?
    var subtitle: String?
    var role: RIDRMetricRole = .power
    var foreground: Color?

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 32, height: 32)
                    .overlay { Rectangle().stroke(BCColors.caseShadow, lineWidth: 1) }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.ridrMicro)
                    .tracking(1.8)

                if let subtitle {
                    Text(subtitle)
                        .font(.ridrBodySmall)
                        .foregroundColor((foreground ?? BCColors.caseInk).opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            Spacer()

            Text("›")
                .font(.ridrDataMD)
        }
        .foregroundColor(foreground ?? BCColors.caseInk)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .background(role.color)
        .overlay { Rectangle().stroke(BCColors.caseShadow, lineWidth: 1) }
    }
}

struct RIDRIconTile: View {
    let icon: String
    var color: Color = BCColors.signalPrimary
    var size: CGFloat = 40
    var filled = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.43, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundColor(filled ? BCColors.caseInk : color)
            .frame(width: size, height: size)
            .background(filled ? color : BCColors.caseSub)
            .overlay {
                Rectangle()
                    .stroke(filled ? color : BCColors.caseShadow, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct RIDRAvatarTile: View {
    let initials: String
    var isActive = false

    var body: some View {
        Text(initials.uppercased())
            .font(.ridrDisplaySM)
            .foregroundColor(isActive ? BCColors.signalAlert : BCColors.caseBrushed)
            .frame(width: 36, height: 36)
            .background(isActive ? BCColors.signalAlert.opacity(0.12) : BCColors.caseSub)
            .overlay {
                Rectangle()
                    .stroke(isActive ? BCColors.signalAlert : BCColors.caseShadow, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct RIDRActivityCard: View {
    let initials: String
    let rider: String
    let meta: String
    let title: String
    var badge: RIDRBadge?
    var stats: [(label: String, value: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RIDRAvatarTile(initials: initials)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rider.uppercased())
                        .font(.ridrHeading)
                        .tracking(0.6)
                        .foregroundColor(BCColors.caseBrushed)
                    Text(meta.uppercased())
                        .font(.ridrMicro)
                        .tracking(1.8)
                        .foregroundColor(BCColors.caseShadow)
                }

                Spacer()

                badge
            }

            Text(title.uppercased())
                .font(.ridrDisplaySM)
                .foregroundColor(BCColors.caseBrushed)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            RIDRTickRow(count: 17, majorEvery: 4, color: BCColors.signalPrimary.opacity(0.9))

            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    if index > 0 {
                        Rectangle()
                            .fill(BCColors.caseShadow)
                            .frame(width: 1, height: 22)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.label.uppercased())
                            .font(.ridrMicro)
                            .tracking(1.8)
                            .foregroundColor(BCColors.caseShadow)
                        Text(stat.value.uppercased())
                            .font(.ridrDataMD)
                            .foregroundColor(index == 1 ? BCColors.signalPrimary : BCColors.caseBrushed)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, index == 0 ? 0 : 10)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(BCColors.caseDial)
        .overlay(alignment: .bottom) { BCHairline() }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Compatibility Components

struct BCSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title.uppercased())
                .font(.bcSectionTitle)
                .tracking(1.6)

            Rectangle()
                .fill(BCColors.hairline)
                .frame(height: 1)
                .padding(.leading, 2)
        }
        .foregroundColor(BCColors.caseSteelMid)
        .accessibilityElement(children: .combine)
    }
}

struct BCHairline: View {
    var body: some View {
        Rectangle()
            .fill(BCColors.hairline)
            .frame(height: 1)
    }
}

struct BCIconTile: View {
    let icon: String
    var color: Color = BCColors.brandBlue
    var size: CGFloat = 40
    var filled = false

    var body: some View {
        RIDRIconTile(icon: icon, color: color, size: size, filled: filled)
    }
}

struct BCStatusPill: View {
    let text: String
    var icon: String?
    var color: Color = BCColors.brandBlue

    var body: some View {
        RIDRBadge(text: text, icon: icon, color: color)
    }
}

struct BCMetric: Identifiable {
    let value: String
    let label: String
    let icon: String?

    var id: String { "\(label)-\(value)-\(icon ?? "")" }

    init(value: String, label: String, icon: String? = nil) {
        self.value = value
        self.label = label
        self.icon = icon
    }
}

struct BCMetricStrip: View {
    let metrics: [BCMetric]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                if index > 0 {
                    Rectangle()
                        .fill(BCColors.hairline)
                        .frame(width: 1, height: 52)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(metric.label.uppercased())
                            .font(.bcInstrumentLabel)
                            .tracking(1.8)
                            .foregroundColor(BCColors.caseShadow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Spacer(minLength: 2)
                    }

                    Text(metric.value.uppercased())
                        .font(.bcInstrumentValue)
                        .foregroundColor(index == 0 ? BCColors.signalLume : BCColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BCSpacing.sm)
                .padding(.vertical, BCSpacing.sm)
            }
        }
        .overlay(alignment: .bottom) {
            RIDRTickRow(count: 21, activeCount: min(metrics.count * 2, 21))
                .padding(.horizontal, BCSpacing.sm)
                .padding(.bottom, 6)
        }
        .bcInstrumentCard(padding: BCSpacing.sm)
    }
}

struct BCPrimaryAction: View {
    let title: String
    let subtitle: String?
    let icon: String
    var color: Color = BCColors.brandBlue
    var foreground: Color = BCColors.caseInk

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        color: Color = BCColors.brandBlue,
        foreground: Color = BCColors.caseInk
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.foreground = foreground
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .frame(width: 44, height: 44)
                .overlay { Rectangle().stroke(foreground.opacity(0.35), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.ridrMicro)
                    .tracking(2.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let subtitle {
                    Text(subtitle)
                        .font(.ridrBodySmall)
                        .foregroundStyle(foreground.opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer()

            Text("›")
                .font(.ridrDataMD)
                .foregroundStyle(foreground.opacity(0.78))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, BCSpacing.md)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .background(color)
        .overlay { Rectangle().stroke(BCColors.caseShadow, lineWidth: 1) }
    }
}

struct BCDisclosureRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var accent: Color = BCColors.brandBlue
    var trailing: String?

    var body: some View {
        HStack(spacing: 12) {
            BCIconTile(icon: icon, color: accent, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.ridrHeading)
                    .tracking(0.6)
                    .foregroundColor(BCColors.primaryText)
                    .lineLimit(1)

                Text(subtitle.uppercased())
                    .font(.ridrMicro)
                    .tracking(1.5)
                    .foregroundColor(BCColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }

            Spacer()

            if let trailing {
                Text(trailing.uppercased())
                    .font(.bcCaption)
                    .foregroundColor(BCColors.cockpitMutedText)
                    .lineLimit(1)
            }

            Text("›")
                .font(.ridrDataMD)
                .foregroundColor(BCColors.signalPrimary)
        }
        .padding(BCSpacing.md)
        .contentShape(Rectangle())
    }
}

private struct BCInstrumentCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BCColors.instrumentPanel)
            .overlay { RIDRCaseFrame() }
    }
}

extension View {
    func bcInstrumentCard(padding: CGFloat = BCSpacing.md) -> some View {
        modifier(BCInstrumentCardModifier(padding: padding))
    }

    func bcPanelList() -> some View {
        background(BCColors.instrumentPanel)
            .overlay { RIDRCaseFrame() }
    }
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
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(.ridrMicro)
                    .tracking(1.8)

                if let count, isSelected {
                    Text("\(count)")
                        .font(.ridrMicro)
                        .foregroundColor(BCColors.accentForeground.opacity(0.78))
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .background(isSelected ? BCColors.accent : BCColors.instrumentInset)
            .foregroundColor(isSelected ? BCColors.accentForeground : BCColors.primaryText)
            .overlay {
                Rectangle()
                    .stroke(isSelected ? BCColors.accent : BCColors.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filterChip_\(title)")
        .accessibilityLabel("\(title)\(count != nil ? ", \(count!) items" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to filter by \(title)")
    }
}

// MARK: - Badges

struct DifficultyBadge: View {
    let difficulty: String

    var body: some View {
        BCStatusPill(text: difficulty, color: BCColors.difficultyColor(difficulty))
            .accessibilityLabel("Difficulty: \(difficulty)")
    }
}

struct CategoryBadge: View {
    let category: String

    private var icon: String {
        switch category.lowercased() {
        case "road": return "road.lanes"
        case "gravel": return "mountain.2"
        case "fatbike": return "snowflake"
        case "trail": return "leaf"
        case "brewery": return "mug"
        case "touring": return "map"
        default: return "bicycle"
        }
    }

    var body: some View {
        BCStatusPill(text: category.capitalized, icon: icon, color: BCColors.categoryColor(category))
            .accessibilityLabel("Category: \(category)")
    }
}

struct TrailConditionBadge: View {
    let condition: TrailCondition

    private var color: Color {
        switch condition.badgeColor {
        case "green": BCColors.brandGreen
        case "red": BCColors.danger
        case "orange": BCColors.brandAmber
        default: BCColors.cockpitSteel
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: condition.icon)
                .font(.system(size: 8, weight: .bold))
            Text(condition.displayLabel.uppercased())
                .font(.ridrMicro)
                .tracking(1.5)
            if condition.reportCount > 1 {
                Text("(\(condition.reportCount))")
                    .font(.ridrMicro)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .overlay { Rectangle().stroke(color, lineWidth: 1) }
        .accessibilityLabel("Trail condition: \(condition.displayLabel)")
    }
}

// MARK: - Metadata Rows

struct RouteStatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(BCColors.cockpitMutedText)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.bcInstrumentLabel)
                    .tracking(1.6)
                    .foregroundColor(BCColors.cockpitMutedText)
                Text(value.uppercased())
                    .font(.bcCaption)
                    .foregroundColor(BCColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()
        }
    }
}

struct MetadataItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        RouteStatRow(icon: icon, label: label, value: value)
    }
}

// MARK: - Nav Tile Modifier

extension View {
    func bcNavTile(height: CGFloat) -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(BCColors.navPanel)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(BCColors.navTileHighlight)
                    .frame(height: 1)
            }
            .overlay { RIDRCaseFrame() }
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.linear(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("RIDR Components") {
    VStack(spacing: 16) {
        RIDRStatusHeader(left: "RIDE · REF 0247", right: "GPS LOCK", isLive: true)
        BCSectionHeader("Available Bikes", icon: "bicycle")
        BCMetricStrip(metrics: [
            BCMetric(value: "18", label: "Rides", icon: "figure.outdoor.cycle"),
            BCMetric(value: "348", label: "Miles", icon: "road.lanes"),
            BCMetric(value: "22K", label: "Elev", icon: "arrow.up")
        ])
        RIDRMetricTile(label: "Speed", value: "42.6", unit: "KM/H", role: .primary, isPrimary: true, activeTicks: 12)
        BCPrimaryAction(title: "Start Recording", subtitle: "Capture a new ride", icon: "record.circle.fill", color: BCColors.danger, foreground: BCColors.docBone)
        HStack {
            FilterChip(title: "All", count: 15, isSelected: true) {}
            DifficultyBadge(difficulty: "hard")
            CategoryBadge(category: "gravel")
        }
    }
    .padding()
    .background(BCColors.background)
}
