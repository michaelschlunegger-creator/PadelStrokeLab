import SwiftUI
import PadelCore
import PadelDesign

struct PracticeSetupView: View {
    @Environment(\.colorScheme) private var scheme
    @Bindable var model: PracticeSetupModel
    // Self-reports guide this screen only. They never acknowledge the Watch's physical checks.
    @State private var racketHand: PlayingArm?
    @State private var wornWrist: PlayingArm?
    @State private var retainedUsualHand: PlayingArm?
    @State private var suggestionsLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PracticeTheme.Space.large) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prepare your Watch")
                        .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Text("Manually choose one shot type for each short set. Watch must be on your playing arm.")
                        .foregroundStyle(PracticeTheme.secondaryInk(scheme))
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--owner-setup-fixture=offline") {
                    Text("SYNTHETIC UI REVIEW · Offline Watch")
                        .font(.caption.bold()).accessibilityIdentifier("ownerSetupFixture")
                }
                #endif
                consent
                preferences
                progress
                actions
                Text("Start on Watch after a fresh wrist, crown and fit check for every set. The iPhone cannot start a recording.")
                    .font(.footnote).accessibilityIdentifier("localWatchStartNotice")
                Text("Your stroke choice and contact labels are personal references. They do not detect shots or measure contact quality.")
                    .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            }
            .padding(PracticeTheme.Space.large)
            .frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("practiceSetupScreen")
        .background(PracticeTheme.canvas(scheme))
        .foregroundStyle(PracticeTheme.ink(scheme))
        .tint(PracticeTheme.accent(scheme))
        .navigationTitle("Set up practice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            resetAnswers()
            loadSuggestionsIfAvailable()
        }
        .onDisappear { resetAnswers() }
        .task {
            await model.load()
            if !Task.isCancelled { loadSuggestionsIfAvailable() }
        }
        .onChange(of: model.stored) { _, _ in loadSuggestionsIfAvailable() }
        .onChange(of: model.choices.currentRacketArm) { _, arm in
            if let racketHand, racketHand != arm {
                self.racketHand = nil; wornWrist = nil
            }
        }
    }

    private var consent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Owner and consent").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            Text("Review these choices each time you reopen the app. Saved preferences never turn consent on.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            Toggle("I am the owner of this Watch and its account", isOn: Binding(
                get: { model.ownerConfirmed },
                set: { model.setConsent(ownerConfirmed: $0, motion: model.motionConsent, heartRate: model.heartRateConsent) }))
                .accessibilityIdentifier("ownerAttestation")
            Toggle(model.channel?.authority?.isCollectionAllowed == false
                ? "I agree to resume this motion study after my earlier withdrawal"
                : "I agree to record my motion for this personal study", isOn: Binding(
                    get: { model.motionConsent },
                    set: { model.setConsent(ownerConfirmed: model.ownerConfirmed, motion: $0, heartRate: model.heartRateConsent) }))
                .accessibilityIdentifier("motionStudyConsent")
            Toggle("Include heart rate for this practice (optional)", isOn: Binding(
                get: { model.heartRateConsent },
                set: { model.setConsent(ownerConfirmed: model.ownerConfirmed, motion: model.motionConsent, heartRate: $0) }))
                .accessibilityIdentifier("optionalHeartRateConsent")
            Text("Heart rate may be unavailable. This choice does not request Health access on iPhone or provide a medical readiness assessment.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
        }
        .practiceCard()
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your next set").font(.title3.bold()).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 8) {
                Text("Which hand holds your racket?").font(.headline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setupRacketArmLabel")
                Picker("Which hand holds your racket?", selection: Binding(
                    get: { racketHand }, set: { selectRacketHand($0) })) {
                        Text("Choose").tag(PlayingArm?.none)
                        Text("Left").tag(PlayingArm?.some(.left))
                        Text("Right").tag(PlayingArm?.some(.right))
                    }.pickerStyle(.menu)
                    .accessibilityIdentifier("setupRacketArm")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Which wrist is your Watch on now?").font(.headline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setupCurrentWristLabel")
                Picker("Which wrist is your Watch on now?", selection: $wornWrist) {
                        Text("Choose").tag(PlayingArm?.none)
                        Text("Left").tag(PlayingArm?.some(.left))
                        Text("Right").tag(PlayingArm?.some(.right))
                    }.pickerStyle(.menu)
                    .disabled(racketHand == nil)
                    .accessibilityIdentifier("setupCurrentWrist")
                Text("Tell us where you are wearing it, even if its Watch settings say something different.")
                    .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
            }
            if let racketHand, let wornWrist {
                watchGuidance(arm: racketHand, wrist: wornWrist)
            }
            if model.choices.usualHand != model.choices.currentRacketArm {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved usual playing hand").font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text("Your saved usual hand differs from this set's racket hand. Keep it if that is intentional, or correct it here. Changing the racket hand does not overwrite this saved detail.")
                        .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
                    Picker("Saved usual playing hand", selection: Binding(
                        get: { model.choices.usualHand },
                        set: { retainedUsualHand = $0; update(hand: $0) })) {
                            Text("Left").tag(PlayingArm.left); Text("Right").tag(PlayingArm.right)
                        }.pickerStyle(.menu)
                        .accessibilityIdentifier("setupSavedUsualHand")
                }
            }
            ForEach([RecordingDrill.forehandGroundstroke, .backhandGroundstroke]) { drill in
                Button { update(drill: drill) } label: {
                    HStack(alignment: .top) {
                        Image(systemName: model.choices.intendedDrill == drill ? "checkmark.circle.fill" : "circle")
                        Text(drill.title).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(drill == .forehandGroundstroke ? "setupForehand" : "setupBackhand")
                .accessibilityValue(model.choices.intendedDrill == drill ? "Selected" : "Not selected")
            }
            Text("Changing these choices during recording applies to the next set. A running set keeps its original selection.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
        }
        .practiceCard()
        .disabled(!suggestionsLoaded)
    }

    private func watchGuidance(arm: PlayingArm, wrist: PlayingArm) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(arm == wrist
                 ? "Your Watch is already on your \(arm.rawValue) racket arm."
                 : "Move your Watch to your \(arm.rawValue) wrist.")
                .font(.headline).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("watchPlacementGuidance")
            Text("On iPhone, open the Watch app → My Watch → General → Watch Orientation. Choose \(arm.rawValue.capitalized) Wrist and the Digital Crown side that matches how you are wearing your Watch. These settings describe its configuration; they do not confirm where it is physically worn.")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phoneWatchOrientationGuidance")
            Text("Adjust the band for a snug, comfortable fit so the Watch stays in place on your racket arm.")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phoneWatchFitGuidance")
            Text("For every set, confirm placement, wrist and crown settings, and fit on your Watch. Then choose Start set there.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
        }
        .accessibilityElement(children: .contain)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.statusText).font(.headline).accessibilityIdentifier("setupStatus")
            if let current = model.acceptedCurrent {
                Text("Current set: \(current.draft.preferences.intendedDrill.title)")
                    .accessibilityIdentifier("currentSetSelection")
            }
            if let next = model.acceptedNext {
                Text("Next set: \(next.draft.preferences.intendedDrill.title)")
                    .accessibilityIdentifier("nextSetSelection")
            }
            if let error = model.lastError { Text(error).font(.footnote).accessibilityIdentifier("setupError") }
        }
        .practiceCard()
        .accessibilityElement(children: .contain)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                guard answersComplete else { return }
                Task { await model.reviewAndPrepare() }
            } label: {
                Text(model.busy ? "Preparing…" : "Review choices and prepare").frame(maxWidth: .infinity)
            }
            .buttonStyle(PracticeActionStyle()).disabled(!model.canPrepare || !answersComplete)
            .accessibilityIdentifier("reviewAndPrepare")
            Button("Check Watch / retry pending request") { Task { await model.retryPending() } }
                .accessibilityIdentifier("retryPracticeSetup")
            if model.needsResolution {
                Text("An earlier owner decision needs resolution. Resolving keeps any stronger privacy restriction and any pending End.")
                    .font(.footnote)
                Button("Resolve the earlier decision") { Task { await model.resolveObsoleteIntent() } }
                    .accessibilityIdentifier("resolveOwnerDecision")
            }
            Button("End this practice", role: .destructive) { model.endPractice() }
                .disabled(!model.canEnd).accessibilityIdentifier("endPractice")
            if model.channel?.authority != nil || model.channel?.pending != nil {
                Button("Withdraw motion-study consent", role: .destructive) { model.withdrawMotionConsent() }
                    .accessibilityIdentifier("withdrawMotionConsent")
            }
            Text("End finishes this practice. Withdrawal also blocks collection. A disconnected Watch may continue until it receives the request; use its local stop control when needed.")
                .font(.footnote).foregroundStyle(PracticeTheme.secondaryInk(scheme))
        }
    }

    private var answersComplete: Bool {
        suggestionsLoaded && racketHand != nil && wornWrist != nil
            && racketHand == model.choices.currentRacketArm
    }

    private func resetAnswers() {
        racketHand = nil; wornWrist = nil
        retainedUsualHand = nil; suggestionsLoaded = false
    }

    private func loadSuggestionsIfAvailable() {
        guard !suggestionsLoaded, let saved = model.stored else { return }
        // The loaded choices also include explicit edits whose async save may still be finishing.
        // Do not restore an older persisted hand over those edits when the screen reopens.
        retainedUsualHand = saved.preferences != nil || saved.latestDraft != nil ? model.choices.usualHand : nil
        suggestionsLoaded = true
    }

    private func selectRacketHand(_ arm: PlayingArm?) {
        guard suggestionsLoaded else { return }
        if racketHand != arm { wornWrist = nil }
        racketHand = arm
        guard let arm else { return }
        // Only a genuinely unsaved first choice initializes both metadata values.
        // Existing preferences or draft handedness remain distinct until explicitly corrected.
        let usual = retainedUsualHand ?? arm
        retainedUsualHand = usual
        update(arm: arm, hand: usual)
    }

    private func update(arm: PlayingArm? = nil, hand: PlayingArm? = nil, drill: RecordingDrill? = nil) {
        model.updateChoices(.init(currentRacketArm: arm ?? model.choices.currentRacketArm,
            usualHand: hand ?? model.choices.usualHand, intendedDrill: drill ?? model.choices.intendedDrill))
    }
}
