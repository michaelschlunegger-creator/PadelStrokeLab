# Black, turquoise and white — icon assets Package B v1.0

20 October 2026, Asia/Dubai. Author: GPT-6 Astra, Extra High reasoning.

**Status: PLAN ONLY, pending director ratification and the accepted, frozen Package A source handoff.** This is a bounded Level 2 presentation package following the [eight-file theme contract](261020_Black_Turquoise_White_UI_Contract_v1.0.md). The owner has authorized the black/turquoise/white visual direction. No further preference decision is needed.

## Scope and invariants

Change exactly three files, with at most 60 changed source lines in the generator:

| Allowed file | Permitted change |
| --- | --- |
| `tools/generate_padel_master_icons.swift` | Replace old palette constants and their semantic names, preserving the existing CoreGraphics artwork and renderer. |
| `PadelStrokeLab/Assets.xcassets/AppIcon.appiconset/PadelMaster.png` | Deterministically regenerate the existing iPhone icon from that source. |
| `PadelStrokeLab Watch App/Assets.xcassets/AppIcon.appiconset/PadelMaster.png` | Write the same regenerated image for Watch. |

The existing editable generator is the source of truth. It renders an opaque 1024 × 1024 sRGB image using CoreGraphics/ImageIO and writes identical outputs for both platforms. Preserve every coordinate, path, transform, gradient location, stroke width, size, alpha/compositing behavior, output path and racket/ball identity. Retain the existing subtle court geometry. Change colors and misleading palette names only; no new artwork, text, fonts, dependencies, bitmap transformations or image generation service.

Use the Package A palette: charcoal-to-black gradient (`#1B272A` to `#050809`), white racket (`#FFFFFF`), charcoal racket openings (`#1B272A`), turquoise ball (`#10D7CE`) and dark ball seam (`#041313`) with the existing seam alpha. Preserve the existing white decorative-court alpha. Native platform masks remain responsible for rounded-square and circular presentation.

Both existing AppIcon `Contents.json` files already reference the PNG as universal 1024 × 1024 for the respective iOS/watchOS platform. Keep those files byte-identical. Do not change asset names, project configuration, signing, bundle identifiers, version/build, app source, tests, participant files or frozen Package A inputs.

## Before-state identities and sequence

Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Intentional unpublished changes are preserved. These read-only pre-package identities were verified:

- Generator SHA-256: `7adaa29d9a32b6c07a2374fac6a60233e46be7aa86f13bd4c28f5aeff9acf2be`.
- Each original PNG SHA-256: `73846ffd3127af00d1aa99726b12fd67b13648ab5da6816928c5f7cf599e191a`.

Start only after the director accepts and freezes A's source, then explicitly releases B against that exact manifest. Record A's accepted manifest and the two catalog hashes before editing. No parallel production, build or simulator jobs may alter those inputs.

## Verification and evidence

1. Inspect the generator diff: only palette values/semantic names changed, within three files and 60 changed source lines. Verify every non-palette rendering statement, geometry, output path and both catalogs are unchanged.
2. Use the approved Xcode 27 Swift runtime with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Render twice to isolated scratch output roots containing the expected directories. Verify both runs and both platform outputs are byte-identical before placing the approved output at the two allowed paths.
3. Verify each output's 1024 × 1024 dimensions, sRGB profile and opacity using image metadata/decoding. Inspect the complete icon and its actual iPhone rounded-square and Watch circular system presentations, including contrast and essential racket/ball geometry at launcher sizes. Do not manufacture preview masks by editing raster pixels.
4. Build both OS 27 Release products and verify the compiled asset catalogs include the correct icon. Record fresh app/icon presentation evidence for those exact products on the released simulator pair. Reuse A's protected UI/logic evidence when its inputs remain byte-identical; no unrelated behavior tests or full core reruns are needed for this asset-only package.
5. Freeze the combined A+B source identity and record changed paths/line counts, repeat-render hashes, image properties, Release results and captures. Obtain independent read-only exact-source review. Preserve any failure and any unobserved system icon surface; do not claim a successful observation from a source preview alone.

Historical icons and presentation/build evidence remain evidence for their original source. Regenerated asset catalogs invalidate affected app-build and icon-presentation evidence; they do not imply changes to unchanged logic results.

No physical installation, account/App Store action, Git mutation, release, collection or readiness claim is included. Participant implementation remains held until the coordinator supplies the subsequently accepted frozen baseline.
