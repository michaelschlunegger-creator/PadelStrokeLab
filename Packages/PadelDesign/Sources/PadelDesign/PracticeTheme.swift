import SwiftUI

/// Presentation only. Practice metadata stays independent of SwiftUI in PadelCore.
public enum PracticeTheme {
    private static let canvasColor = color(0x050809)
    private static let surfaceColor = color(0x131B1D)
    public static let elevatedSurface = color(0x1B272A)
    public static let accentColor = color(0x10D7CE)
    public static let onAccent = color(0x041313)
    /// Native Watch navigation keeps white glyphs, so its fill is darker.
    public static let navigationFill = color(0x006F6A)
    public static let controlOutline = color(0x68858A)
    public static let separator = color(0x2C3A3D)
    public static let hero = LinearGradient(
        colors: [surfaceColor, elevatedSurface],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Keep the semantic interface for callers; the app always presents dark.
    public static func canvas(_ scheme: ColorScheme) -> Color {
        canvasColor
    }

    public static func surface(_ scheme: ColorScheme) -> Color {
        surfaceColor
    }

    public static func ink(_ scheme: ColorScheme) -> Color {
        color(0xF5FAFA)
    }

    public static func secondaryInk(_ scheme: ColorScheme) -> Color {
        color(0xAEBFC3)
    }

    public static func accent(_ scheme: ColorScheme) -> Color {
        accentColor
    }

    private static func color(_ rgb: UInt32) -> Color {
        Color(.sRGB, red: Double((rgb >> 16) & 0xff) / 255,
              green: Double((rgb >> 8) & 0xff) / 255,
              blue: Double(rgb & 0xff) / 255, opacity: 1)
    }

    public enum Space {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let section: CGFloat = 32
    }
}

private struct PracticeCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(PracticeTheme.Space.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PracticeTheme.surface(scheme), in: .rect(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(contrast == .increased
                                  ? PracticeTheme.controlOutline : PracticeTheme.separator, lineWidth: 1)
            }
    }
}

public extension View {
    func practiceCard() -> some View { modifier(PracticeCard()) }
}

public struct PracticeEyebrow: View {
    private let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Native Liquid Glass is reserved for an action above content. The solid
/// alternative honors Reduce Transparency without making content translucent.
public struct PracticeActionStyle: PrimitiveButtonStyle {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        if reduceTransparency {
            Button(configuration)
                .buttonStyle(.borderedProminent)
                .tint(PracticeTheme.accentColor)
                .foregroundStyle(PracticeTheme.onAccent)
        } else {
            Button(configuration)
                .buttonStyle(.glassProminent)
                .tint(PracticeTheme.accentColor)
                .foregroundStyle(PracticeTheme.onAccent)
        }
    }
}

/// A decorative court, not a measurement or a representation of captured data.
public struct PracticeCourt: View {
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.055))
                Path { path in
                    path.addRoundedRect(in: CGRect(x: 1, y: 1, width: width - 2, height: height - 2),
                                        cornerSize: CGSize(width: 12, height: 12))
                    for fraction in [0.25, 0.5, 0.75] {
                        path.move(to: CGPoint(x: 0, y: height * fraction))
                        path.addLine(to: CGPoint(x: width, y: height * fraction))
                    }
                    path.move(to: CGPoint(x: width / 2, y: height * 0.25))
                    path.addLine(to: CGPoint(x: width / 2, y: height * 0.75))
                }
                .stroke(.white.opacity(0.28), lineWidth: 1.25)
                Circle()
                    .fill(PracticeTheme.accentColor)
                    .frame(width: 13, height: 13)
                    .position(x: width * 0.72, y: height * 0.31)
            }
        }
        .accessibilityHidden(true)
    }
}
