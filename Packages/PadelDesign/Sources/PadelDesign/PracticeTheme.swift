import SwiftUI

/// Presentation only. Practice metadata stays independent of SwiftUI in PadelCore.
public enum PracticeTheme {
    public static let navy = Color(red: 0.035, green: 0.09, blue: 0.21)
    public static let royal = Color(red: 0.08, green: 0.24, blue: 0.67)
    public static let yellow = Color(red: 1, green: 0.84, blue: 0.25)
    public static let watchSurface = Color(red: 0.065, green: 0.14, blue: 0.29)
    public static let hero = LinearGradient(
        colors: [Color(red: 0.055, green: 0.19, blue: 0.51), royal],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    public static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? navy : Color(red: 0.94, green: 0.96, blue: 0.99)
    }

    public static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? watchSurface : .white
    }

    public static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : navy
    }

    public static func secondaryInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.74, green: 0.81, blue: 0.92)
            : Color(red: 0.30, green: 0.37, blue: 0.48)
    }

    public static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.61, green: 0.76, blue: 1) : royal
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

    func body(content: Content) -> some View {
        content
            .padding(PracticeTheme.Space.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PracticeTheme.surface(scheme), in: .rect(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(PracticeTheme.ink(scheme).opacity(0.07), lineWidth: 1)
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
                .tint(PracticeTheme.yellow)
                .foregroundStyle(PracticeTheme.navy)
        } else {
            Button(configuration)
                .buttonStyle(.glassProminent)
                .tint(PracticeTheme.yellow)
                .foregroundStyle(PracticeTheme.navy)
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
                    .fill(PracticeTheme.yellow)
                    .frame(width: 13, height: 13)
                    .position(x: width * 0.72, y: height * 0.31)
            }
        }
        .accessibilityHidden(true)
    }
}
