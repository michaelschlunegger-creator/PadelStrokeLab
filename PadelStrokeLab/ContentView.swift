import SwiftUI
import PadelCore
import PadelDesign

struct ContentView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
                    brand
                    hero
                    sessionsLink
                    preparationNote
                    contactGuide
                    watchReminder
                }
                .padding(.horizontal, PracticeTheme.Space.large)
                .padding(.top, PracticeTheme.Space.small)
                .padding(.bottom, PracticeTheme.Space.section)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("homeScreen")
            .background(PracticeTheme.canvas(scheme))
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(PracticeTheme.accent(scheme))
        .foregroundStyle(PracticeTheme.ink(scheme))
    }

    private var brand: some View {
        HStack(spacing: 9) {
            Image(systemName: "figure.racquetball")
                .foregroundStyle(PracticeTheme.accent(scheme))
            Text("PADEL STROKE LAB")
                .tracking(2)
        }
        .font(.caption.weight(.bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PadelStrokeLab")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    PracticeEyebrow("Your first drill")
                        .foregroundStyle(PracticeTheme.yellow)
                    Image(systemName: "figure.racquetball")
                        .font(.system(size: 38, weight: .regular))
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 12)
                PracticeCourt()
                    .frame(width: 88, height: 112)
                    .rotationEffect(.degrees(12))
                    .padding(.trailing, 8)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Start with\nyour forehand.")
                    .font(.largeTitle.weight(.bold))
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One familiar stroke. A clear place to begin.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
                PracticeGuideView()
            } label: {
                HStack {
                    Text("Explore the drill")
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline)
                .padding(.vertical, 7)
            }
            .buttonStyle(PracticeActionStyle())
            .controlSize(.large)
            .accessibilityIdentifier("practiceGuideLink")
            .accessibilityHint("Opens the forehand practice guide.")
        }
        .foregroundStyle(.white)
        .padding(PracticeTheme.Space.large)
        .background(PracticeTheme.hero, in: .rect(cornerRadius: 30))
    }

    private var contactGuide: some View {
        NavigationLink {
            ContactGuideView()
        } label: {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundStyle(PracticeTheme.accent(scheme))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Get a feel for contact")
                        .font(.title3.weight(.bold))
                    Text("Know the five reference labels before you play.")
                        .font(.subheadline)
                        .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
            }
            .practiceCard()
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("contactGuideLink")
        .accessibilityHint("Opens the contact reference guide.")
    }

    private var watchReminder: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundStyle(PracticeTheme.accent(scheme))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Watch on your playing arm")
                    .font(.headline)
                Text("Confirm your racket arm in the Watch app.")
                    .font(.subheadline)
                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
            }
        }
        .padding(.horizontal, 4)
    }

    private var sessionsLink: some View {
        NavigationLink {
            RecordingLibraryView()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "waveform.path").font(.title2)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Sessions").font(.title3.bold())
                    Text("Review recordings. Label your attempts.").font(.subheadline)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
            }
            .practiceCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recordingLibraryLink")
    }

    private var preparationNote: some View {
        Label {
            Text("Record on your Watch. Review and label your attempts in Sessions.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(PracticeTheme.secondaryInk(scheme))
        .padding(.horizontal, 4)
        .accessibilityIdentifier("preparationNotice")
    }
}

private struct PracticeGuideView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
                GuideHeading(eyebrow: "The first drill", title: PracticeDrill.forehandGroundstroke.title,
                             subtitle: "Begin with a stroke you know.", symbol: "figure.racquetball")
                VStack(alignment: .leading, spacing: 25) {
                    guideStep("01", title: "Set up your Watch",
                              detail: "Wear it on the arm you use to hold your racket. Select that arm and confirm the placement in the Watch app.")
                    Divider()
                    guideStep("02", title: "Keep the drill familiar",
                              detail: "Start with controlled forehand groundstrokes during normal practice. Other strokes can wait.")
                    Divider()
                    guideStep("03", title: "Notice the contact",
                              detail: "Use your experience and contact feel. Where the ball lands is a separate observation.")
                }
                .practiceCard()
                VStack(alignment: .leading, spacing: 10) {
                    Label("No need to guess", systemImage: "questionmark.circle")
                        .font(.headline)
                    Text("Uncertain is a valid reference. A self assessment is a personal judgement, not an independent measurement.")
                        .font(.body)
                        .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
                .practiceCard()
                Text("For your first test, record one intended shot per set on your Watch. After stopping, label that attempt in Sessions and add a time interval when known. Ordered labels without a time match remain unmatched. No automatic contact score is produced.")
                    .font(.footnote)
                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                    .padding(.horizontal, 4)
            }
            .padding(PracticeTheme.Space.large)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("practiceGuideScreen")
        .background(PracticeTheme.canvas(scheme))
        .navigationTitle("Practice guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideStep(_ number: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(number)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(PracticeTheme.accent(scheme))
            Text(title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.body)
                .foregroundStyle(PracticeTheme.secondaryInk(scheme))
        }
    }
}

private struct ContactGuideView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
                GuideHeading(eyebrow: "Your reference", title: "How did\nthe contact feel?",
                             subtitle: "Five labels. Room for uncertainty.", symbol: "scope")
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(ContactCategory.allCases) { category in
                        if category != ContactCategory.allCases.first { Divider() }
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: symbol(for: category))
                                .font(.title3.weight(.medium))
                                .foregroundStyle(PracticeTheme.accent(scheme))
                                .frame(width: 28)
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(category.title)
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)
                                Text(explanation(for: category))
                                    .font(.subheadline)
                                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                            }
                        }
                    }
                }
                .practiceCard()
                VStack(alignment: .leading, spacing: 10) {
                    Label("Contact isn't the outcome", systemImage: "arrow.triangle.branch")
                        .font(.headline)
                    Text("A clean contact and a ball landing in are different observations. Choose Uncertain whenever you cannot tell.")
                        .font(.body)
                }
                .foregroundStyle(PracticeTheme.navy)
                .padding(PracticeTheme.Space.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PracticeTheme.yellow, in: .rect(cornerRadius: 26))
                Text("After a set, open Sessions to save your own attempt labels. Use Uncertain whenever the evidence is unclear.")
                    .font(.footnote)
                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                    .padding(.horizontal, 4)
            }
            .padding(PracticeTheme.Space.large)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("contactGuideScreen")
        .background(PracticeTheme.canvas(scheme))
        .navigationTitle("Contact reference")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func symbol(for category: ContactCategory) -> String {
        switch category {
        case .cleanContact: "scope"
        case .mishit: "circle.slash"
        case .uncertain: "questionmark.circle"
        case .airSwing: "wind"
        case .nonStroke: "figure.walk"
        }
    }

    private func explanation(for category: ContactCategory) -> String {
        switch category {
        case .cleanContact: "A contact you judge to feel clean, based on your own experience."
        case .mishit: "A contact you judge to be a mishit. Keep the judgement separate from where the ball lands."
        case .uncertain: "You cannot confidently judge the contact. Leave room for that uncertainty."
        case .airSwing: "A swing without contact with the ball."
        case .nonStroke: "Walking, collecting balls, racket taps or other movement that is not a stroke."
        }
    }
}

private struct GuideHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top) {
                PracticeEyebrow(eyebrow)
                    .foregroundStyle(PracticeTheme.yellow)
                Spacer(minLength: 12)
                Image(systemName: symbol)
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .padding(PracticeTheme.Space.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PracticeTheme.hero, in: .rect(cornerRadius: 30))
    }
}

#Preview {
    ContentView()
        .environment(RecordingLibraryModel(activateConnectivity: false))
}
