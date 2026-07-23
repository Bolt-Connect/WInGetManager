# CLAUDE.md

Context for AI assistants (Claude Code, Cursor, GitHub Copilot, etc.) working on this repo.

## What this project is

WinGet Manager — a lightweight PowerShell + WPF GUI around Microsoft's `winget` CLI, bundled as a single `.exe` (~225 KB) via PS2EXE. Dark/light/auto theme, async UI, silent mode for automation, single-file portable + Inno Setup installer. Bilingual UI (English + Dutch) with auto-detect.

Target audience: personal Windows machines, end users who want to manage WinGet through a GUI.

## Architecture

```
WinGetManager.ps1          Entry point for PS1 mode (dev)
src/
├── Core/
│   ├── Logging.psm1       Writes to file + observable for GUI
│   ├── Config.psm1        Loads/saves settings.json
│   ├── I18n.psm1          Translations (NL + EN dictionaries, Get-Text, Apply-Translations)
│   └── WinGet-Core.psm1   Wrappers around winget.exe + self-update
├── GUI/MainWindow.ps1     WPF interface (XAML in here-string)
└── Silent/WinGet-Silent.ps1   Headless CLI mode

Build-Exe.ps1              Bundles everything into a single .ps1 + compiles via PS2EXE
└── build/WinGetManager.exe   Final product

installer/WinGetManager.iss  Inno Setup script
.github/workflows/build.yml  CI: builds EXE + Setup.exe per release tag
```

## Build process

```powershell
.\Build.bat                       # Generates build/WinGetManager.exe
.\Build-Installer.ps1 -Version x  # Requires Inno Setup, output in release/
```

Build-Exe.ps1 does:
1. Reads `src/Core/*.psm1` and strips Export-ModuleMember + signature blocks
2. Reads `src/GUI/MainWindow.ps1` and `src/Silent/WinGet-Silent.ps1`, strips Import-Module and duplicate init code
3. Concatenates everything into a single script file with param block + ScriptRoot detection
4. Compiles via `Invoke-PS2EXE` with icon, version, etc.

## Important conventions

### PowerShell 5.1 compatibility (required)
PS2EXE uses Windows PowerShell 5.1, **not** PowerShell 7. So:

- ❌ `$x ?? $y` (null-coalescing)
- ❌ `$x ?: $y` (ternary)
- ❌ `$x?.Property` (null-conditional)
- ✅ `if ($x) { $x } else { $y }`
- ✅ Verb-noun cmdlets, `[System.Type]` casts

### Async pattern for long operations
Use `Start-WinGetWork` (in MainWindow.ps1) for single async winget calls. For bulk operations: synchronized hashtable + DispatcherTimer + runspace. See `Start-BulkUpdate` as an example.

**Never** run synchronous winget calls on the UI thread — freezes the GUI.

### Closures in event handlers
Variables needed inside a Tick handler must be captured via `.GetNewClosure()`; otherwise you rely on script scope, which leads to null references during fast repeated events:

```powershell
$timer.Add_Tick({
    if ($handle.IsCompleted) {  # $handle from closure
        $timer.Stop()
        ...
    }
}.GetNewClosure())
```

### `$args` is a PowerShell automatic variable
Never use `$args` as your own variable name in scriptblocks with `param(...)`. PowerShell resets `$args` automatically. Use `$cmdArgs`, `$wingetArgs`, etc.

### Theme system
`MainWindow.ps1` has a `$Script:Themes` hashtable with Dark/Light palettes. At window-load the XAML is walked via `Apply-ThemeColors`, which substitutes hex codes. The default XAML uses Dark colors (`#1E1E2E` etc).

For new colors: add a hex to both palettes and add `'#hexvalue' = $colors.NewKey` to the mapping in `Apply-ThemeColors`.

Hex colors in XAML must exactly match the keys in the mapping.

### i18n system
`I18n.psm1` has a `$Script:Strings` hashtable with `nl-NL` and `en-US` sub-hashtables (~150 keys each). At window load:
1. `[xml]$Xaml = @'...'@` — XAML parsed into an XML object
2. `$xamlString = $Xaml.OuterXml` — serialize back
3. `$xamlString = Apply-Translations -Text $xamlString` — substitutes `{{Key}}` placeholders
4. `Apply-ThemeColors` substitutes hex codes
5. `[XamlReader]::Load(...)` builds the WPF tree

For runtime strings in code, use `Get-Text 'Key.Name'` (with optional `-FormatArgs @(...)` for `{0}` placeholders).

**Conventions**:
- All user-facing strings → through i18n (XAML `{{Key}}` or `Get-Text`)
- All log messages (`Write-Log "..."`) → **literal English** (logs are language-neutral)
- Source-column values (`winget`/`msstore`/`local`) → fixed English identifiers, not translated
- New string? Add the key to **both** dictionaries in `src/Core/I18n.psm1`

### PS2EXE-specific gotchas
- `$PSScriptRoot` is empty in a PS2EXE EXE — use `[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName` as a fallback
- `Write-Host` with `-NoConsole` shows a MessageBox — use `Write-Log` with `-WriteToHost:$false`
- WPF only works in STA — PS2EXE compile with `-STA` flag
- Encoding: source files with non-ASCII chars (emojis, accented chars) **must have a UTF-8 BOM**, otherwise PowerShell 5.1 reads them as cp1252 and corrupts the bytes. The `I18n.psm1` module relies on this.

### Silent mode integration
The bundler merges the silent script body into the main script via `Read-Cleaned -StripParam`. That strips everything before the first `if ($Search)` line — so the silent script now always starts with that as a marker. Don't remove it.

## Self-update

Only works in the EXE distribution. Steps:

1. `Get-LatestAppVersion` fetches the GitHub Releases API
2. Compare via `ConvertTo-AppVersion` (extracts the numeric core so a pre-release-style tag like `0.4.0-rc1` doesn't throw on the `[version]` cast)
3. Re-validate the asset URL with `Test-TrustedUpdateUrl` (the API URL was already checked; the derived asset URL must be re-checked)
4. Download `.exe` asset as `WinGetManager.exe.new`
5. Verify PE header (`Test-PEFile`) **and** SHA256 against the release's `checksums.txt` (`Get-FileSha256` / `Get-ExpectedSha256`). If the release has no `checksums.txt`, the hash check is skipped with a logged warning (backward-compat with pre-v0.3.3 releases)
6. Write `WinGetManager-Update-*.bat` to TEMP, spawn it
7. The bat waits for exit, moves `.new` → original, restarts

`checksums.txt` is generated in CI (see `build.yml`) as sha256sum-style `<hash>  <filename>` lines over every release asset. The self-update matches the `WinGetManager.exe` line by asset name. SHA256 gives integrity against corrupt/tampered downloads — it is **not** authenticity (a fully compromised release could swap both the exe and the checksums); that's what code-signing (roadmap) is for.

`$Script:AppVersion` in `WinGet-Core.psm1` must match the release tag.

## Tests

`tests/Test-I18nParity.ps1` is a dependency-free (no Pester) script that asserts the `nl-NL` and `en-US` dictionaries in `I18n.psm1` share the exact same key set — run it after adding any string. It relies on the exported `Get-I18nStrings` helper. CI runs it before the build (fail-fast), so a key added to one language but not the other breaks the build instead of shipping a raw `{{Key}}`.

## What to do for a new feature

1. Make the change in the right `src/` file
2. Run `.\Build.bat` locally — output in `build/`
3. Test `build\WinGetManager.exe`
4. Add a line to `## [Unreleased]` in `CHANGELOG.md`
5. Commit with a conventional commit prefix (`feat:`, `fix:`, `docs:`, `refactor:`)
6. Push — GitHub Actions builds the artifact

## What to do for a release

1. Update `$Script:AppVersion` in `src/Core/WinGet-Core.psm1`
2. Update `Version` in `Build-Exe.ps1` (PS2EXE param)
3. Promote `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD` in CHANGELOG
4. Add a new empty `[Unreleased]` section
5. Commit + push
6. `git tag -a vx.y.z -m "..."` and `git push origin vx.y.z`
7. GitHub Actions publishes the release with portable + installer + zip

## What the user wants to see

- A stable GUI without freezes
- Clear error messages (no raw exit codes)
- As few clicks as possible for common tasks
- Theme follows the Windows preference unless set otherwise
- Language follows the OS UI culture unless set otherwise
- Self-update is "magic" — click the button, restart, done

## Known gotchas / footguns

- `IsReadOnly="True"` on the DataGrid makes ALL columns non-editable, including checkboxes. Use `IsReadOnly="True"` per `DataGridTextColumn` instead of on the DataGrid itself if you want checkboxes to work.
- WPF StackPanel has NO `Spacing` property (that's WinUI). Use `Margin` on the children.
- `Foreground="#CDD6F4"` directly as an attribute does not work for theme substitution if the hex is missing from the mapping. Always use colors from the palette.
- Files containing emojis or non-ASCII need a UTF-8 BOM, otherwise PS5.1 reads them as cp1252 and the module fails to parse.
- **PS2EXE `-NoConsole` + winget = truncated output**: winget formats tabular output based on console buffer width via `GetConsoleScreenBufferInfo`. With no console it falls back to a narrow default and truncates long IDs (`Microsoft.VCRedist.2015+.x86` becomes `Microsoft.VCRedist.2015+.x8`, last char bleeds into the next column). Fix: wrap winget in `cmd /c "MODE CON: COLS=250 LINES=3000 & winget ..."` to give it a wide hidden console. See `Invoke-WinGet` in `WinGet-Core.psm1`.
- **`@(0)` is falsy in PowerShell boolean context**: a single-element array unwraps to its scalar, and `0` is `$false`. So `if ($FormatArgs -and $FormatArgs.Count -gt 0)` short-circuits to `$false` when `$FormatArgs = @(0)`. Always use `if ($null -ne $FormatArgs -and $FormatArgs.Count -gt 0)`.
- **WPF emoji rendering**: `⚙️` (U+2699 + VS16) does NOT render as a colored emoji — WPF strips the variation selector. For a clean Settings-style gear, use Segoe Fluent Icons glyph `&#xE713;` with `FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"` in a `<Run>` inside the TabItem header. Other tabs use full emoji codepoints (`🔍 📦 📂 🔗 📋`) which do render colored.
- **UAC consent dialog often appears as a hidden taskbar flash** instead of on top. Fix: call Win32 `AllowSetForegroundWindow(ASFW_ANY)` and `SetForegroundWindow` on the main window IMMEDIATELY before `Start-Process -Verb RunAs`, then `$Window.Activate()` after the elevated child completes. See `Prepare-UacForeground` / `Restore-AppForeground` in `MainWindow.ps1`.
- **`local` is not a real winget source** — it's our derived label for ARP-tracked apps (installed outside winget). WinGet cannot update or even check version for these, so the Installed-tab status pill must show `— Unknown` rather than misleading "Up-to-date".
- **`winget source list` does not support `--output json`** — calling it with `-UseJson` returns exit code `-1978335230`. Use text parsing via `Parse-SourceText`. Other commands like `winget upgrade --output json` are also unsupported on older winget versions (1.x).
- **`[ordered]@{}` (`OrderedDictionary`) has NO `.Clone()` method** — `$hashtable.Clone()` works, but an ordered dictionary throws `"does not contain a method named 'Clone'"` at runtime. This bit us in `Config.psm1` (`$Defaults.Clone()`) where it stayed latent until a fresh install with no `settings.json` finally hit that path. Copy ordered dicts by hand: `$c = [ordered]@{}; foreach ($k in $src.Keys) { $c[$k] = $src[$k] }`. See `Copy-OrderedDict` in `Config.psm1`.
- **A winget exit code of `0` does NOT prove anything was installed** — winget can return success while the installer silently no-ops (e.g. a machine-scope MSI/wix package run without elevation). Never report success on the exit code alone; the install flow calls `Refresh-Installed` and then `Test-PackageInstalled` to confirm the package actually appears before telling the user it worked.
- **Every winget action that can touch machine scope needs an elevation retry** — `Get-WinGetErrorInfo` maps exit code `-1978334969` to `Action = 'elevate'`, but that only helps if the caller acts on it. Install originally lacked this (update and uninstall had it), so installing an MSI package never showed a UAC prompt. Mirror the `$doUpdate` / `$doInstall` self-referencing scriptblock pattern: `param([bool]$Elevated = $false)`, retry via `& $doX -Elevated $true`, and treat exit `1223` as "user dismissed UAC".
- **`Write-Log` does not exist inside the bulk runspaces** — `Start-BulkUpdate` / `Start-BulkUninstall` create a bare runspace, so you cannot log from the loop. Collect per-package results into the synchronized `$progress` hashtable (see the `Failures` array of `@{Id, Name, Exit}`) and write them out from the DispatcherTimer tick on the UI thread, where `Write-Log` is available.
- **`Start-WinGetWork` runs winget directly (`& winget @a`), not through the `cmd /c MODE CON` wrapper** — so the wide-console truncation fix does NOT apply to the async path. It also means exit codes come from `$LASTEXITCODE` inside the runspace. The tick handler logs the exit code (and output tail on failure) for every async operation; keep that logging, it is the only trace these operations leave.
- **Self-update only validates the API URL, not asset URLs** — `Update-App` runs `Test-TrustedUpdateUrl` on the configured API endpoint, then trusts the asset/`html_url` values it returns. Any code that hands one of those derived URLs to `Start-Process` or a downloader should re-run `Test-TrustedUpdateUrl` on it first (the `requires_admin` "open download page" flow in `MainWindow.ps1` does this). `Test-TrustedUpdateUrl` must stay in `WinGet-Core.psm1`'s `Export-ModuleMember` list or dev-mode (Import-Module) GUI calls break.

## Roadmap (see also README)

- v0.4.0: System tray icon, toast notifications, cancel button, package details panel
- v0.5.0: Test phase + SignPath signing
- v1.0.0: First stable release / Microsoft Store distribution

## Links

- Repo: https://github.com/Bolt-Connect/WinGet-Manager
- WinGet docs: https://learn.microsoft.com/en-us/windows/package-manager/winget/
- PS2EXE: https://github.com/MScholtes/PS2EXE
- Inno Setup: https://jrsoftware.org/isinfo.php
