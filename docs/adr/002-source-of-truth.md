# ADR 002 — GitHub development source of truth

Date: 16 October 2026. Status: accepted by explicit owner instruction.

The owner instructed: “use Github for saving the code etc.” This supersedes the earlier plan to maintain source archives or an active Xcode checkout in Google Drive.

GitHub stores the code, Xcode project, development requirements snapshots, architecture, decisions, test contracts, evidence summaries and handover. The active checkout remains a local Git repository at `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab` so Xcode can build and test normally. Build products and user-specific Xcode state stay outside Git.

Google Drive retains the user-facing App Specifications and Word documents. Existing source/evidence archives there are historical backups; they are not the current development baseline and will not be automatically deleted or updated.

The instruction authorizes committing and pushing the existing foundation to its feature branch and opening a draft pull request for review. It does not authorize merging, releasing, changing repository visibility or removing historical Drive files. No merge-readiness conclusion follows from saving the source.

The existing repository is public. The publication scope contains source, reference documents and evidence summaries; credentials, private keys, raw personal recordings, user-specific Xcode state and sensitive raw logs are excluded. Future private player data must not enter this repository.

Independent committed-code review, clean CI and relevant physical-device evidence remain separate gates before an owner-approved merge.
