# Changelog

All notable changes to WinGet Manager are tracked in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.3] - 2026-07-21

### Added
- **Self-update integrity via SHA256** — every release now ships a `checksums.txt`, and the self-update verifies the downloaded `WinGetManager.exe` against its published hash before swapping it in. A PE-header check only proves "this is an exe"; the hash proves the bytes match what we published. Releases that predate `checksums.txt` still update (the check is skipped with a logged warning). This is integrity protection against corrupt or in-transit-tampered downloads — not a substitute for code-signing.
- **Actionable "WinGet not found" prompt** — when App Installer/winget is missing, the app now offers to open the Microsoft Store to install it (one click) instead of showing a dead-end error and exiting.

### Changed
- **Self-update re-validates the asset download URL** — `Test-TrustedUpdateUrl` now runs on the resolved asset URL just before download, not only on the API endpoint, closing the gap where a derived URL was trusted implicitly.

### Fixed
- **Install now prompts for admin rights instead of silently doing nothing** — the install action was the only operation without UAC elevation (update and uninstall already had it). Installing a machine-scope package such as an MSI/wix installer therefore never showed a UAC prompt and quietly failed. Install now mirrors the update flow: when winget reports it needs elevation, the app offers to retry with administrator rights.
- **Install no longer reports false success** — the result was judged purely on winget's exit code, so a package that was never actually installed could still produce "installed successfully". After a reported success the app now verifies the package really appears in the installed list, and says so honestly when it does not.
- **Async operations are now logged** — `Start-WinGetWork` (used by install, update and uninstall) recorded nothing, so a failed operation left no trace in the log. It now logs winget's exit code for every operation, plus the last lines of output when something goes wrong.
- **Bulk operations now log which packages failed** — bulk update and bulk uninstall reported only a total ("3 of 12 failed") with no record of *which* packages failed or why. Per-package exit codes are now collected in the runspace and written to the log when the batch finishes. Logs stay local; nothing is transmitted.
- **Self-update no longer chokes on pre-release-style version tags** — version comparison now extracts the numeric core (e.g. `0.4.0-rc1` → `0.4.0`) instead of throwing on a bare `[version]` cast, and logs clearly instead of returning a silent `invalid_version`.

### Tests
- **i18n key-parity test** (`tests/Test-I18nParity.ps1`) — asserts the `nl-NL` and `en-US` dictionaries expose exactly the same key set, so a translation added to one language but forgotten in the other (which would surface as a raw `{{Key}}` in the UI) fails the build. Dependency-free (no Pester) and wired into CI.

---

## [0.3.2] - 2026-06-13

### Changed
- **Installer default is now system-wide** (`Install for all users (recommended)`). WinGet Manager is a system-management tool — WinGet itself is system-wide, Task Scheduler auto-update entries apply to all users, and packages installed with `--scope machine` work for everyone. The per-user install remains available as a fallback in the install-mode dialog (`Install for me only`) for users without admin rights. Existing per-user installs from v0.3.1 keep working via self-update and don't need to be re-installed.
- **Installer always shows the language picker at start** — added `ShowLanguageDialog=yes` so every user gets an explicit English/Dutch choice when launching `WinGetManager-Setup-0.3.2.exe`, regardless of system locale. The dropdown defaults to the system locale (Dutch on Dutch Windows, English elsewhere) so most users can just click through. Portable users skip this entirely — the app itself keeps auto-detecting language via `CurrentUICulture` on first launch.

### Added
- **Friendly self-update message when running from Program Files** — system-wide installs in `C:\Program Files\WinGetManager\` cannot self-update without admin rights. Instead of failing silently, the app now detects this case and offers to open the download page so the user can fetch the new Setup.exe manually (it links straight to the `Setup.exe` release asset when available, otherwise the release page). Detection probes the install directory for write permission, so unusual setups (read-only Program Files, locked-down kiosks) are also handled correctly.

### Security
- **Self-update download links are validated before opening** — the new "download Setup.exe manually" flow passes its URL through `Test-TrustedUpdateUrl` (HTTPS + `github.com`/`objects.githubusercontent.com` allow-list) before handing it to `Start-Process`, so a tampered GitHub API response cannot cause the shell to launch an arbitrary path instead of a browser.

### Fixed
- **`OrderedDictionary does not contain a method named 'Clone'` crash on fresh installs** — `Config.psm1` used `$Defaults.Clone()` in both the catch branch and the no-settings.json branch. `[ordered]@{}` returns an `OrderedDictionary`, which does NOT have a `Clone()` method. This crash was latent since at least v0.2.x but was never triggered because settings.json always existed in our test scenarios. Replaced with a `Copy-OrderedDict` helper that iterates keys and copies values into a fresh ordered dictionary. **Important for v0.3.2** because this code path is hit by every fresh install (portable users who run the EXE without any prior settings.json).
- **Set-Status fallback for new `requires_admin` reason code** — the Self-update flow now sets the status bar to "v{0} available - click 'Update app' above" hint after the user has dismissed the admin dialog, instead of stale "Downloading..." text.

---

## [0.3.1] - 2026-05-18

### Added
- **Automatic UAC elevation flow** — when an update or uninstall returns "needs admin rights" (exit code `-1978334969`), the app now offers a confirm dialog "Retry now with admin rights? (Windows will show a UAC prompt.)" and on Yes triggers one UAC prompt. Works for single, bulk update, and bulk uninstall flows. Bulk operations batch all admin-required packages into ONE UAC prompt via `cmd /c "winget ... && winget ..."`.
- **UAC prompt visibility helpers** — new Win32 P/Invoke wrapper (`WinGetMgr.UacHelper`) calls `AllowSetForegroundWindow` before triggering UAC and re-focuses the main window after completion, so the consent dialog appears on top instead of as a hidden taskbar flash.
- **Sources tab: `local` explainer** — the info panel at the top of the Sources tab now shows a third bullet describing what `local` means (apps installed outside WinGet — `.exe` installers, MSI — that can't be updated through this GUI).
- **Row-selected fallback for "Update selection"** — on the Updates tab, the green "Update selection" button now uses the highlighted row when no checkboxes are ticked. Convenient for the common case of a single available update.
- **Settings tab icon** — replaced the thin monochrome `⚙` symbol with the proper Windows Settings glyph from Segoe Fluent Icons (`U+E713`, falls back to Segoe MDL2 Assets on Windows 10).

### Changed
- **"Up-to-date" status only when verifiable** — packages with `local` (ARP) or empty source no longer claim to be "Up-to-date" since WinGet can't actually check their upstream. They now show `— Unknown` / `— Onbekend`. Packages from `winget`/`msstore` show "Up-to-date" as before.

### Fixed
- **Truncated package IDs in Updates and Installed tabs** — long IDs like `Microsoft.VCRedist.2015+.x86` were being cut off (last chars bled into the next column, e.g. shown as `.x8` with `6` appearing in the CURRENT column). Root cause: PS2EXE `-NoConsole` builds have no parent console, so winget falls back to a narrow default width. Fix: invoke winget through `cmd /c "MODE CON: COLS=250 LINES=3000 & winget ..."` in a hidden console, giving winget a 250-column buffer. IDs now come through intact and packages like VC++ Redistributable can actually be updated.
- **Bulk update failure dialog mixed Dutch into English UI** — `Show-Info "$msg\n\nMislukt: $failed"` was still hardcoded. Now uses `Get-Text 'Dialog.SomeFailed'` so it correctly says "Failed:" in EN and "Mislukt:" in NL.
- **`{0} update(s) found` displayed literally** when there were zero updates. Root cause: PowerShell unwraps `@(0)` to scalar `0` in boolean context, so `if ($FormatArgs -and ...)` evaluated to `$false`. Fix: explicit `$null -ne $FormatArgs` check in `Get-Text`.
- **WinGet `source list` noisy WARN** — `source list` does not support `--output json`, but we were passing that flag and logging the resulting error code. Now uses text parsing via new `Parse-SourceText` helper.
- **`ᵃ` legend-markers in parsed package IDs** — when winget output is squeezed in narrow consoles it prefixes IDs with superscript letters as legend markers. `Parse-PackageText` now strips leading non-alphanumeric chars from the parsed Id field as a defensive fallback.
- **Dialog titles via i18n** — `Show-Info`/`Show-Error`/`Ask-Confirm`/`Ask-ConfirmEx` and the Package-details box had hardcoded Dutch titles (`Fout`, `Bevestig`, `Bevestigen`, `Package details`). Now route through new keys `Dialog.Title.Info` / `.Error` / `.Confirm` / `.Details`.
- **Hardcoded Dutch text in "Niet meer vragen" checkbox** — the `Ask-ConfirmEx` dialog showed Dutch text regardless of language. Now uses `Dialog.DontAskAgain` placeholder.
- **`$args` shadowing PowerShell automatic variable** — six call sites in `WinGet-Core.psm1` and `MainWindow.ps1` used `$args` as a user variable for winget argument arrays. PowerShell resets `$args` automatically inside scriptblocks, which could silently truncate arguments on entry to an inner block. All renamed to `$cmdArgs`.
- **Hardcoded Dutch fallback `"Bezig..."`** — `Start-WinGetWork` default `BusyMessage` was a Dutch literal. Now uses `Get-Text 'Status.WorkingOn'`.

---

## [0.3.0] - 2026-05-17

### Added
- **i18n infrastructure** — new `src/Core/I18n.psm1` module with embedded English and Dutch dictionaries (~150 keys). Translations apply through `{{Key}}` placeholder substitution in XAML and `Get-Text` calls in code.
- **Language picker** in Settings tab: `Automatic (system)` / `Nederlands` / `English`. Save prompts for restart to apply.
- **Auto-detect language** via `CurrentUICulture` at startup: `nl-*` → Dutch, anything else → English (fallback). Default `Language` setting changed from `nl-NL` to `auto`.
- **All documentation translated to English** (README, CHANGELOG, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, CLAUDE).

### Changed
- **Source column derivation** — `Parse-PackageJson` and `Parse-PackageText` now derive a logical source when winget leaves the column empty: `MSIX\…` → `msstore`, `ARP\…` → `local`, anything else → `winget`. Previously most installed packages showed an empty BRON column. New helper `Resolve-PackageSource` in `WinGet-Core.psm1`.
- **All log messages translated to English** (~60 strings across `WinGet-Silent.ps1`, `MainWindow.ps1`, `WinGet-Core.psm1`). Logs are now language-neutral regardless of UI language, making them easier to share in bug reports.
- **Status bar and runtime status messages** now i18n-aware (`Set-Status` calls go through `Get-Text`).
- **Dialog texts** for Show-Info / Show-Error / Ask-Confirm fully translated (~45 dialogs across install, uninstall, update, import/export, sources, settings, self-update flows).
- **Self-update reason strings** translated (up-to-date / no asset / download failed / corrupt / invalid exe / untrusted URL / not-exe runtime).
- **Sources tab description paragraph** fully translated, including the Run blocks explaining `winget` / `msstore` defaults.
- **Repo renamed** on GitHub from `WinGetManager` to `WinGet-Manager`. All internal references updated (README, CHANGELOG, CONTRIBUTING, CLAUDE, SECURITY, Config defaults, Inno Setup script).
- `SelfUpdateUrl` in new builds now points to the renamed repo. **One-time automatic migration**: when v0.2.5 users upgrade to v0.3.0, the legacy URL in their saved `settings.json` is rewritten to the new repo URL on first start.
- **Inno Setup installer** now uses `[CustomMessages]` with English + Dutch task descriptions instead of a hardcoded Dutch string.
- **Build pipeline and CI workflow** step names and console output translated to English.

### Fixed
- **Search returned 0 results in English mode** — `CmbSearchSource` filter compared the translated `Content` string ("Alle bronnen") which broke in EN. ComboBox items now use a language-neutral `Tag` attribute (`""` / `"winget"` / `"msstore"`) for the filter check. Same pattern applied to the Logs level filter (`CmbLogFilter`).
- **`EmptySearch.Text` reset still showed Dutch placeholder** when typing fewer than 2 characters, regardless of UI language. Now reads from `Get-Text 'Search.Empty'`.

---

## [0.2.5] - 2026-05-15

### Added
- **New app icon** based on the site logo (blue monitor with stand). Transparent background so it fits both dark and light Windows title bars and taskbar. `Generate-Icon.ps1` regenerates this design.
- **Monitor logo in app header** — replaced the `⊞` text symbol with a native XAML rendering of the actual logo. Theme-aware background (dark in dark, blends in light).
- **`BETA` badge** next to the version number in the header (amber yellow `#d29922`).
- **Status pill column** on the Installed tab: green "↑ Update" pill for updatable packages, grey "Up-to-date" for the rest. Replaces the green row text.
- **Tab badges as colored pills** in the tab header (blue for Installed/Sources, green for Updates).
- **Search icon (🔍)** in filter bars on Search and Installed tabs.

### Changed
- **Dark theme palette matches GitHub style** (same palette as the website CSS):
  - `BgPrimary` `#1A1B26` → `#0d1117`
  - `BgSecondary` `#24283B` → `#161b22`
  - `BgCard` `#2F3349` → `#21262d`
  - `BorderColor` `#3B4261` → `#30363d`
  - `TextMuted` `#7A88B0` → `#8b949e`
  - `TextPrimary` `#E5E9F0` → `#e6edf3`
  - `AccentBlue` `#4FA3FF` → `#2f81f7`
  - `AccentGreen` `#4ADE80` → `#3fb950`
  - `AccentRed` `#FF6B7A` → `#f85149`
  - `AccentYellow` `#FFD23F` → `#d29922`
- **Minimal tab styling**: tabs now without background/borders — only text with a blue underline for the active tab. Much cleaner.
- **Cleaner DataGrid**: no frame border, transparent background, only subtle horizontal row separators, column headers now UPPERCASE + muted (`NAME`, `ID`, `VERSION`, etc).
- **Airier row spacing**: MinHeight 38px + DataGridCell padding 10x8px for more breathing room.
- **Bigger filter bar**: padding 14×9 + MinHeight 38 for a prominent, GitHub-style input.
- **Header and status bar background** now match `BgPrimary` instead of a separate darker card color — more uniform.
- **Window icon** is now extracted at runtime from the EXE (PS2EXE-embedded resource) — works without an extra `assets/icon.ico` file next to the exe.
- README badge "current stable" → **"public beta"** with an orange beta status badge at the top.

---

## [0.2.4] - 2026-05-14

### Fixed
- **Updates tab counter was wrong**: WinGet's footer line "X upgrades available." was being parsed as a package. Parser now also filters these footer lines (NL + EN) plus rows without an Id-column value.
- **Logs tab stayed empty in GUI**: `DataGridTextColumn` default binding mode (TwoWay) did not work with `PSCustomObject` NoteProperty. Bindings are now explicit `Mode=OneWay`. Also: ObservableCollection has no `Dispatcher` property — replaced by a separate `$Script:LogDispatcher` with the Window's Dispatcher for thread-safe Add from background runspaces.
- **`ConfirmUpdate` setting didn't work**: the checkbox in Settings saved the value but no update button checked it. Now wired in `BtnUpdateSelectedInstalled`, `BtnUpdateAll`, and `BtnUpdateSelected` with "Don't ask again" option via `Ask-ConfirmEx`.

### Changed
- `Set-LogObservable` now also accepts a `-Dispatcher` parameter (optional) for thread-safe collection updates.
- Keyboard shortcut diagnostic logs lowered back to `DEBUG` level (no longer polluting the logs).
- **Installed tab sorting**: items with an available update now appear at the top, then alphabetical. This way users immediately see what's updatable without scrolling.

---

## [0.2.3] - 2026-05-07

### Added
- **Tab badges with count**: tabs now show the number of items per category, e.g. `📦 Installed (147)`, `⬆ Updates (3)`, `🔗 Sources (2)`. Updates and Sources only show a counter at ≥1 item.
- **Empty-state messages** in all DataGrids:
  - Search (no text): "🔍 Type at least 2 characters to search"
  - Search (no match): "🔍 No results for 'xyz'"
  - Installed (empty): "📦 No packages found"
  - Updates (empty): "✓ All packages are up-to-date 🎉" (green)
  - Sources (empty): "🔗 No sources configured"
- **Info card on Sources tab** explaining what `winget` and `msstore` are and what you can do here.

---

## [0.2.2] - 2026-05-06

### Added
- Global keyboard shortcuts:
  - `F5` refreshes the current tab (Installed / Updates / Sources / Search)
  - `Ctrl+F` jumps to the Search tab and focuses the search bar
  - `Ctrl+R` opens the Updates tab and refreshes immediately
  - `Ctrl+L` opens the Logs tab
  - `Ctrl+W` closes the app
  - `Esc` clears the search field on the Search tab
- F5 simulates a click on the corresponding Refresh button with a **gold flash animation** (250ms) for visible feedback.
- "Keyboard shortcuts" section in the Settings tab with an overview of all shortcuts.
- "Don't ask again" checkbox on uninstall confirmations; ticking it saves `ConfirmUninstall=false` in the config.
- `Ask-ConfirmEx` helper: themed custom dialog with optional opt-out checkbox per action.

### Fixed
- ComboBoxItems were unreadable in dark mode (dark system text on dark background). Added: explicit ComboBoxItem style with theme-aware Foreground.
- DataGrid.ItemsSource crashed on pipelines with 1 result (PowerShell unwraps single-item arrays to scalar). All assignments now wrapped with `@(...)`.
- Keyboard shortcut handler did not always fire if a TextBox/DataGrid had focus. Replaced with `AddHandler` and `handledEventsToo=$true`.

---

## [0.2.1] - 2026-05-06

### Added
- README badges: build status, latest release, downloads count, license.
- Direct download links in README via stable `/releases/latest/download/` URL pattern — works automatically for every new release without updating the README.
- `CLAUDE.md` with project context for AI assistants (Claude Code, Cursor, Copilot).

### Changed
- GitHub Actions now uploads both versioned (`WinGetManager-Setup-0.2.1.exe`) and stable (`WinGetManager-Setup.exe`) filenames per release.
- Same for portable zip: `WinGetManager-v0.2.1-portable.zip` + `WinGetManager-portable.zip`.
- README install section simplified: now a clear comparison of Setup vs Portable vs Bundle.

### Fixed
- v0.2.0 release was missing the stable `WinGetManager-Setup.exe` filename — direct download links in README pointed to 404 for the installer. From 0.2.1 onward all `/releases/latest/download/...` URLs work.

---

## [0.2.0] - 2026-05-06

### Added
- Working self-update via GitHub Releases API: detects newer version, downloads the new `.exe`, replaces itself and restarts automatically.
- Background update check at startup — "Update app" button turns orange when a newer version is available.
- Search-as-you-type on the Search tab with 400ms debouncing and async runspaces (UI freeze-free).
- Live progress text during Update All / Update selection: "Updating (3/12): Firefox..."
- Failure overview after bulk update shows which packages could not be updated.
- Screenshots folder structure and README section for visual documentation.

### Changed
- Version bumped from `1.0.0` (internal) to `0.2.0` to align with the release tag.
- Update button now points to the GitHub Releases API instead of a placeholder URL.

### Fixed
- Race condition in search debouncing where old timers caused null-reference errors.
- "Cannot bind argument" error during update due to collision with PowerShell's `$args` automatic variable.

---

## [0.1.0] - 2026-05-06

First public release.

### Added
- WPF GUI with 7 tabs: Search, Installed, Updates, Import/Export, Sources, Logs, Settings.
- Dark / Light / Auto theme (Auto follows Windows system preference).
- Async background runspace so the UI doesn't freeze during long winget operations.
- Auto-detect running apps that block an update, with a confirmation dialog to close them and resume the update.
- Mapping of WinGet exit codes to readable messages (instead of raw codes).
- Updates tab: checkable checkbox column to selectively update packages.
- Installed tab: shows current version + available version, colors rows green when an update is available.
- Silent CLI mode for automation (Task Scheduler, scripts):
  - `-UpdateAll`, `-Install`, `-Uninstall`, `-Search`, `-ExportPath`, `-ImportPath`, `-ListInstalled`, `-ListUpdates`.
- Smart config location: portable (next to the exe) or `%APPDATA%\WinGetManager\` if the app folder isn't writable.
- Logging with daily rotation, retention setting and a live log panel in the GUI.
- Single-file `.exe` distribution (146 KB) via PS2EXE bundling.
- Inno Setup installer with optional desktop shortcut and Task Scheduler task.
- GitHub Actions workflow that automatically publishes portable + installer + zip as a release on every tag.
- Documentation: README, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, LICENSE (MIT).

### Known
- Self-update functionality is provided in the architecture but not yet implemented; updates must be done manually via a new download.
- Smart App Control (Windows 11) blocks running the exe — disabling is a one-way action. Will be resolved once the app is distributed via Microsoft Store.
- SmartScreen shows an "Unknown publisher" warning on first launch (click *More info* → *Run anyway*). Will be resolved later via SignPath or Microsoft Store distribution.

[Unreleased]: https://github.com/Bolt-Connect/WinGet-Manager/compare/v0.3.3...HEAD
[0.3.3]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.3.3
[0.3.2]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.3.2
[0.3.1]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.3.1
[0.3.0]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.3.0
[0.2.5]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.2.5
[0.2.4]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.2.4
[0.2.3]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.2.3
[0.2.2]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.2.2
[0.2.1]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.2.1
[0.2.0]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.2.0
[0.1.0]: https://github.com/Bolt-Connect/WinGet-Manager/releases/tag/v0.1.0
