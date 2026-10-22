import SwiftUI
import PadelCore
import PadelDesign

struct ContentView: View {
    @Environment(RecordingLibraryModel.self) private var recordings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
                    brand
                    hero
                    sessionsLink
                    preparationNote
                    NavigationLink("Practice guide") { PracticeGuideView() }
                        .font(.headline).accessibilityIdentifier("practiceGuideLink")
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
            Text("PADEL MASTER")
                .tracking(1.6)
        }
        .font(.caption.weight(.bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Padel Master")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    PracticeEyebrow("Your training")
                        .foregroundStyle(PracticeTheme.accentColor)
                    Image(systemName: "figure.racquetball")
                        .font(.system(size: 38, weight: .regular))
                        .accessibilityHidden(true)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 12)
                    PracticeCourt()
                        .frame(width: 88, height: 112)
                        .rotationEffect(.degrees(12))
                        .padding(.trailing, 8)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose your shot.\nBuild your practice.")
                    .font(.largeTitle.weight(.bold))
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One intended shot type. One short set at a time.")
                    .font(.body)
                    .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
                if let model = recordings.practiceSetup { PracticeSetupView(model: model) }
                else { ContentUnavailableView("Setup unavailable", systemImage: "exclamationmark.triangle",
                    description: Text(recordings.error ?? "Recording storage is unavailable.")) }
            } label: {
                HStack {
                    Text("Let’s Play")
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline)
                .padding(.vertical, 7)
            }
            .buttonStyle(PracticeActionStyle())
            .controlSize(.large)
            .accessibilityIdentifier("practiceSetupLink")
            .accessibilityHint("Review owner consent and prepare your practice on iPhone.")
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
                GuideHeading(eyebrow: "Practice with intent", title: "Your training set",
                             subtitle: "Choose a shot you want to practise.", symbol: "figure.racquetball")
                VStack(alignment: .leading, spacing: 25) {
                    Text("Set up on iPhone once per practice. Review your choices for each next set, then complete the brief physical check and Start on Watch. A phone connection is not required during local capture.")
                        .accessibilityIdentifier("watchSetupGuidance")
                    guideStep("01", title: "Review owner consent on iPhone",
                              detail: "Confirm that you own the Watch and agree to this motion study. Heart rate is optional. Review saved choices explicitly whenever you reopen the app.")
                    Divider()
                    guideStep("02", title: "Choose forehand or backhand",
                              detail: "Record one intended shot type per short set, up to 120 active seconds. Choose the racket arm and usual hand on iPhone. Changes during recording apply to the next set.",
                              identifier: "trainingSetGuidance")
                    Divider()
                    guideStep("03", title: "Wear Watch on your racket arm",
                              detail: "Move it if needed, or confirm it is already on that arm. Physical placement is your confirmation.")
                    Divider()
                    guideStep("04", title: "Check wrist, crown and fit",
                              detail: "Compare the actual watchOS wrist and crown settings with how you wear it. Fasten the strap securely and comfortably. Confirm placement and fit freshly on Watch for every set.")
                    Divider()
                    guideStep("05", title: "Review and start on Watch",
                              detail: "Check the summary and freshly confirm placement and fit. End other workouts, then tap Start recording on Watch and allow workout and motion access if requested. No workout summary is saved by this app; system activity metrics may still change. Pause and resume stay within the same set.")
                }
                .practiceCard()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Supported intended shot types").font(.title3.bold())
                    ForEach([RecordingDrill.forehandGroundstroke, .backhandGroundstroke]) { drill in
                        Text(drill.title).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("This owner study uses manual forehand and backhand choices. Earlier recordings retain their original intended type. Contact labels such as Uncertain or Air swing remain separate; your choice does not detect or classify shots.")
                        .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
                .practiceCard()
                VStack(alignment: .leading, spacing: 10) {
                    Label("No need to guess", systemImage: "questionmark.circle")
                        .font(.headline)
                    Text("Uncertain is a valid reference. A self assessment is a personal judgement, not an independent measurement.")
                        .accessibilityIdentifier("trainingUncertaintyGuidance")
                        .font(.body)
                        .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
                .practiceCard()
                Text("For your first test, record one attempt per set on your Watch so you can match it reliably. Start explicitly, pause and resume when needed, then stop and wait for the Watch to confirm saved data. Keep Watch originals until the iPhone receipt is verified. Review the intended type and coverage in Sessions, add or revise your label and a time interval when known, then export for read-back. Interrupted sets need review; retry transfer when needed. Delete local copies only through their confirmation. Ordered labels without a time match remain unmatched. No automatic contact score is produced.")
                    .accessibilityIdentifier("firstAttemptGuidance")
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

    private func guideStep(_ number: String, title: String, detail: String, identifier: String = "") -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(number)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(PracticeTheme.accent(scheme))
            Text(title)
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .accessibilityIdentifier(identifier)
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
                .foregroundStyle(PracticeTheme.onAccent)
                .padding(PracticeTheme.Space.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PracticeTheme.accentColor, in: .rect(cornerRadius: 26))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let eyebrow: String
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top) {
                PracticeEyebrow(eyebrow)
                    .foregroundStyle(PracticeTheme.accentColor)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 12)
                    Image(systemName: symbol)
                        .font(.title2)
                        .accessibilityHidden(true)
                }
            }
            Text(title)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(PracticeTheme.secondaryInk(.dark))
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
