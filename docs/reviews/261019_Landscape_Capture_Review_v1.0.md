# Landscape capture diagnosis — v1.0

19 October2026. Astra Extra High, review only; no source edits, tests, builds, launches or device actions. [Pre-edit diagnostic contract](../testing/261019_Landscape_Screenshot_Diagnostic_Contract_v1.0.md) bounds the subsequent paired screenshot fixture. Current source manifest55 entries/SHA256 `ea180bdee7036dd996fda592301f773b31e28e2e5779adda279f890a6f19d295` verified by reviewer.

Result: the observed clipping is an application-screenshot collection artifact. Proceed with final full phone UI collection; no production layout correction is justified.

Initial run26 application screenshots contained cropped pixels and black padding in the original PNG, beyond any viewer orientation handling. The same short-edge-square pattern appeared in all four XL landscape guide/home images and both ordinary-text landscape launch images. Both collectors used app.screenshot(). Preserve those images as failed visual evidence; successful navigation assertions alone did not establish correct rendering.

Focused paired run30 passed in96.934 seconds without changing navigation/content assertions or reveal conditions. At every capture point it preserves app.screenshot(), adds XCUIScreen.main.screenshot() and records geometry. Independent review inspected all four full-screen images and the paired malformed application capture:

- Actual application/window frames are852×393 in all four records.
- Application screenshot reports392.667×852 and reproduces black padding/clipping.
- Full-screen screenshot reports852×392.667 and shows the complete landscape viewport, readable horizontal wrapping and normal vertical scrolling, without the padding/truncation.
- Example private exported pair: `30-phone-attachments/E60ED3EA-0384-4212-9A20-63AF0DF1C0FF.txt` geometry and `0E8C1662-D97C-45AE-8175-30BFFFBF2B68.png` full-screen practice guide.

Compared with previous manifest `6b4b2c82…`, only two phone UI fixture files and workflow manifest reference changed;52 other entries, including all production, are byte-identical. Parent verification may carry existing core/app-host/Watch/build/signing evidence only through those unchanged per-file hashes. Use `-full-screen` attachments for visual assessment and retain both types/geometry for diagnosis. Final full-suite result, physical-device accessibility and independent committed-HEAD review remain separate requirements.
