# DevSweep — Release & Distribution

## Distribution model: Developer ID (direct), NOT the Mac App Store

DevSweep is distributed as a **notarized Developer ID app** (direct download / DMG /
Homebrew cask) — **not** through the Mac App Store.

**Why this is forced, not a preference:** the Mac App Store requires the **App
Sandbox**, and DevSweep's core function is incompatible with it:

- `DockerModule` shells out to the `docker` CLI (`docker system df`, `… prune`).
  Sandboxed apps cannot exec arbitrary binaries.
- `PackageCacheModule` deletes global caches (`~/.npm`, `~/.gradle/caches`,
  `~/Library/pnpm/store`, …). Sandboxed apps can only touch their own container.
- `NodeModulesModule` scans arbitrary trees anywhere on disk.

Full-disk reach is granted by the user once via **Full Disk Access** (System Settings →
Privacy & Security) — a TCC permission that only **non-sandboxed** apps can use. This is
the same reason CleanMyMac and similar disk tools ship Developer ID, not App Store.

### Consequence for StoreKit / In-App Purchases

StoreKit IAPs only work for App Store builds. Under Developer ID:

- The App Store Connect app record (`com.flow-finders.devsweep`, Apple App ID
  `6778351839`) and the **4 IAP products** registered there
  (`com.flowfinders.devsweep.{skin.dotmatrix, skin.synthwave, themepack.retro, allaccess}`)
  are **dormant / unused**. They are not deleted — left as drafts in case the
  decision is ever revisited — but they are not part of this distribution.
- The M6 StoreKit code (`StoreKit2Backend`, `EntitlementResolver`, `SkinStore`) stays
  in the tree but is not the active monetization path.
- Monetization on this path = **voluntary donation** (`DonationLinks`, external URLs,
  already in the app). A paid-skin unlock, if wanted later, needs a non-StoreKit
  mechanism (e.g. Paddle / LemonSqueezy / Gumroad + license keys) — a separate decision.

## Build pipeline — `packaging/build_app.sh`

Assembles the `.app` from the SwiftPM release binary, signs it (Hardened Runtime), and
optionally notarizes + staples and builds a DMG.

```bash
# Local launch test (ad-hoc signed, no notarization):
./packaging/build_app.sh --adhoc

# Full release (signed + notarized + DMG):
IDENTITY="Developer ID Application: Taejin Yoo (TEAMID)" \
NOTARY_PROFILE=devsweep \
./packaging/build_app.sh --dmg
```

Env / flags: see the header comment in `build_app.sh`
(`IDENTITY`, `NOTARY_PROFILE`, `VERSION`, `BUILD`, `UNIVERSAL=1`; `--adhoc --dmg --no-build`).

Bundle facts: id `com.flow-finders.devsweep`, `LSUIElement` (menubar accessory, no Dock
icon), min macOS 14.0, executable `Contents/MacOS/DevSweep`.

## Credential setup the user does once (cannot be automated here)

These touch your Apple Developer account / Keychain — do them yourself:

1. **Developer ID Application certificate** (one-time):
   - Easiest: Xcode → Settings → Accounts → (your Apple ID) → Manage Certificates →
     `+` → **Developer ID Application**. It lands in your login Keychain.
   - Confirm the exact identity string:
     ```bash
     security find-identity -v -p codesigning | grep "Developer ID Application"
     ```
     Use that full string (incl. the `(TEAMID)`) as `IDENTITY`. Team ID is `ECXX8U4NXM`
     (verify with the command above).

2. **App-specific password** for notarization: create one at
   <https://appleid.apple.com> → Sign-In & Security → App-Specific Passwords.

3. **Store notary credentials in a keychain profile** (one-time):
   ```bash
   xcrun notarytool store-credentials devsweep \
     --apple-id "yprecious@gmail.com" \
     --team-id "ECXX8U4NXM" \
     --password "<app-specific-password>"
   ```
   Then `NOTARY_PROFILE=devsweep` in the release command above.

## Remaining before public release

- [x] Developer ID Application cert (already in the login Keychain — see step 1).
- [x] Notary credentials stored (keychain profile `devsweep`, ASC API key auth) and a
      full signed + **notarized** + stapled `--dmg` build produced (see "Verified" below).
- [x] App icon: real designed icon (teal→blue rounded-square tile, broom sweeping
      disk/cache clutter into a pile) committed as `packaging/icon-master.png`.
      `IconGen.swift` now serves only as a fallback if the master PNG is missing.
- [ ] Distribution channel: host the DMG (GitHub Releases) and/or author a Homebrew cask.
- [ ] First-run onboarding that requests Full Disk Access.
- [ ] (optional) `UNIVERSAL=1` if Intel Macs are in scope (current binary is arm64-only).

## Verified — notarized release build

- Release build green (`swift build -c release`), 205 tests green prior.
- Signed with **Developer ID Application: Yoo Taejin (ECXX8U4NXM)**, Hardened Runtime
  (`flags=0x10000(runtime)`), secure timestamp; full cert chain to Apple Root CA.
- **Notarized** via Apple notary service (status `Accepted`) and **stapled**:
  `xcrun stapler validate` → "The validate action worked!".
- Gatekeeper: `spctl -a -t exec` → `accepted, source=Notarized Developer ID`.
- Distributable **`DevSweep-1.0.0.dmg`** is itself signed + notarized + stapled:
  `spctl -a -t open` → `accepted, source=Notarized Developer ID` (clean on download).
- Prior functional verification (ad-hoc build) still holds: launches as a menubar
  accessory (AX confirms one status item), main thread idle while scanning on a
  background thread, SQLite history persists under
  `~/Library/Application Support/DevSweep/devsweep.sqlite` (real store), no crash/fault logs.
