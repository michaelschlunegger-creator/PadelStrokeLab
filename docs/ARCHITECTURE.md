Practice deadline validation and expiry use the same canonical absolute monotonic endpoint (`anchor + 1800`). This preserves the30-minute policy while avoiding subtraction-rounding rejection of the endpoint; finite/lower bounds and strict rejection beyond the endpoint remain. Schema/calculation versions and native resource-drain gates are unchanged. See [correction and regression evidence](testing/261023_Practice_Deadline_Correction_v1.0.md).

# Architecture index

## Components

- **PadelCore**: validated owner/practice/set identities, immutable provenance, raw recording codecs, durable stores, archive/readback, transport receipts, telemetry and deletion contracts. See [source](../Packages/PadelCore/Sources/PadelCore) and its test suite.
- **iPhone app**: phone-led owner setup, consent/preferences, recording import/library, charts and coverage, explicit manual labels, export preview and local/whole-practice deletion. See [phone source](../PadelStrokeLab).
- **Watch app**: owner capture admission and generation fences, practice/workout/optional heart-rate lifecycle, Core Motion adapter, local recording, recovery and retained transfer. See [Watch source](../PadelStrokeLab%20Watch%20App).
- **PadelDesign**: shared black/turquoise/white tokens and accessible native SwiftUI presentation. See [design source](../Packages/PadelDesign/Sources/PadelDesign).

The first build works locally with paired WatchConnectivity; recording does not depend on a phone connection after explicit local admission. There is no cloud backend or generative-model dependency in capture.

## Integrity and lifecycle boundaries

Owner identity, preparation generations and physical confirmation bind each immutable set context. Pending asynchronous work cannot silently acquire a new owner or practice. Raw/context/telemetry publication uses validated attribution and explicit durable boundaries; missing or interrupted records stay qualified. Transfer receipts do not manufacture sensor success. Deletion fences admission and ingress and reports remote work pending until acknowledged. Private health telemetry is optional and owner-only in this candidate.

The Core Motion layer uses public batched-sensor APIs with actual device capability/authorization checks. Timings retain native and arrival observations; stream availability and frequency are reported rather than assumed. Workout, motion shutdown, writer drain, callback fencing and retained recovery have distinct responsibilities. Simulator fixtures are isolated from default stores and real sensors; generated test runners receive fixture arguments before hosted app launch.

## Governing design and verification

[Engineering governance](../ENGINEERING_GOVERNANCE.md), [product authority](PRODUCT_AUTHORITY.md), the [first-build contract](testing/261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md), [architecture decisions](adr), [detailed plans](architecture), [testing](TESTING.md) and [Gate Card](../GATE_CARD.md) are the implementation record. Historical alternatives remain historical; current owner amendments take precedence.

The [final input manifest](testing/261022_Owner_First_Final_Code_State.sha256) identifies portable runtime/test/configuration/asset inputs. Xcode user state and generated products remain outside Git. Build products and private evidence live outside the repository. A manifest match is source identity, not proof of physical correctness.
# Privacy correction boundary — 22 October 2026

Initial Watch practice envelopes use the same checked `.owner-readback-UUID/bundle` staging contract as phone readback before receipt publication. Complete unpublished payloads are attributable to their practice; unknown or partial debris keeps cleanup incomplete. The Watch retained-row action verifies owner context against retained evidence and routes owner records through the existing whole-practice deletion service. Collection consent is separate from identity and deletion authority.

Phone analysis admission combines durable consent, unresolved local/remote restrictions and the existing fence token. Computation and result publication check that admission; synchronous invalidation removes displayed owner statistics and export links/previews. Metadata-only owner detail preserves deletion. Invalidation of selection generations is limited to an existing owner detail, preserving legacy initial-load and concurrent-selection behavior. Core storage/measurement algorithms and immutable recorded identities are unchanged.
