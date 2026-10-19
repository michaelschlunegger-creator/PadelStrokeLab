# Manual training protocol and data dictionary — v1.0

19 October2026. Defines the owner-approved multi-type collection protocol; sensor/metadata/archive schemas are unchanged. Existing recordings retain their original bytes and meanings.

- New protocol identifier: `owner-manual-training-logger-1`, including newly collected forehands.
- Legacy forehand protocol: `owner-forehand-logger-1`; never migrate/rewrite old recordings automatically.
- Recording metadata `drill`: the exact manually selected intended shot type, snapshotted before asynchronous Start. It is not sensor classification, impact timing, shot outcome or quality evidence.
- Supported raw values: `forehandGroundstroke`, `backhandGroundstroke`, `forehandVolley`, `backhandVolley`, `serve`, `lob`, `bandeja`, `vibora`, `smash`, `otherUnclassified`.
- `otherUnclassified`: deliberately unspecified intended type; it is not a substitute for contact categories, a detected non-stroke or a mixed-match labeling protocol. Existing owner notes can describe the activity.
- Unknown historical/future drill strings remain valid bounded metadata and display their exact stored raw text as unrecognized values. The UI vocabulary does not restrict historical archive decoding.
- No saved choice or an unknown preference cannot start a new set. A valid saved choice may persist, but placement confirmation is always fresh.
- One intended type per short controlled set; start with one attempted movement/contact per recording to support reliable matching. The visible engineering cap remains120 active seconds, excluding pauses.
- Raw sensor timestamps, device/OS/build/clock/orientation/configuration, timeline and coverage semantics retain the existing recording contract. Live accepted counts differ from durable retained chunks/counts. A saved file is not proof of complete final sensor-buffer tail delivery.
- Owner annotation categories remain clean contact, mishit, uncertain, air swing and other movement, with original author/evidence/confidence/timing/revision fields. They are separate from intended type. Self labels are not independent ground truth; unmatched attempts remain unmatched/uncertain for analysis.
- Phone review/export retains exact recording ID, original metadata/chunks, stream counts/timeline and every owner label revision; a verified application receipt is separate from OS transfer completion.

For exact binary/archive layouts and validation use the existing core recording/store/archive contracts; this increment adds no binary field, schema migration, sensor transformation or classification model. Physical sampling, background, delivery, battery and per-type usability require actual device observations. No performance threshold or clean-hit claim is ratified by the expanded vocabulary.
