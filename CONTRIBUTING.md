# Contributing to WinGet Manager

Thanks for wanting to contribute! Here's how to get started.

## Reporting a bug

Open an issue with:

- Version of WinGet Manager (see title bar)
- Version of Windows (`winver`)
- Steps to reproduce
- Expected vs. actual behavior
- Logs from the app (**Logs** tab → copy relevant lines)

## Feature proposal

Open an issue labeled `enhancement` describing:

- What you are trying to achieve
- Why current behavior is not enough
- How your proposal would work (UI mock-up, sample code welcome)

## Pull request

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes in `src/`
4. Build locally: `.\Build.bat` and test `build\WinGetManager.exe`
5. Add an entry under the appropriate section in [CHANGELOG.md](CHANGELOG.md) → `## [Unreleased]`
6. Commit with clear messages (`feat: ...`, `fix: ...`, `docs: ...`)
7. Open a PR describing what changed and why

### Conventional commits (recommended)

| Prefix | When |
|---|---|
| `feat:` | New user-facing feature |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `style:` | Formatting, no code change |
| `refactor:` | Code restructuring without behavior change |
| `test:` | Add or update tests |
| `chore:` | Build, CI, dependencies |

## Code style

- PowerShell 5.1 compatible (no `??`, `?:`, etc.)
- Functions follow verb-noun naming (`Get-X`, `Update-Y`)
- Code, comments and log messages in **English**
- User-facing strings (XAML, dialogs, status bar) go through `Get-Text` / `{{Key}}` and live in `src/Core/I18n.psm1`
- No unnecessary large refactors without opening an issue first

## i18n: adding a new user-facing string

1. Add the key to **both** dictionaries in `src/Core/I18n.psm1` (`nl-NL` and `en-US`)
2. In XAML, use `{{Key.Name}}` — `Apply-Translations` substitutes it during parse
3. In code, use `Get-Text 'Key.Name'` (or `-FormatArgs @($var)` for placeholders)
4. **Log messages stay English** — use literal strings, not `Get-Text`

> CI runs `tests/Test-I18nParity.ps1`, which fails the build if a key exists in one
> language but not the other. Run it locally before pushing (see **Tests** below).

## Project structure

```
src/
├── Core/              Wrapper modules (Logging, Config, I18n, WinGet-Core)
├── GUI/MainWindow.ps1 WPF interface
└── Silent/            Headless CLI

tests/                 Dependency-free test scripts (run in CI)
Build-Exe.ps1          Bundles into a single .exe via PS2EXE
.github/workflows/     CI/CD for auto-build
```

## Tests

The project uses lightweight, dependency-free PowerShell test scripts (no Pester
required) that also run in CI before every build. Run them locally before pushing:

```powershell
.\tests\Test-I18nParity.ps1   # asserts nl-NL and en-US share the exact same key set
```

A non-zero exit code means a test failed; the output lists what's wrong.

## Building locally

```powershell
git clone https://github.com/Bolt-Connect/WinGet-Manager.git
cd WinGet-Manager
.\Build.bat                              # builds build\WinGetManager.exe
.\build\WinGetManager.exe                # runs the locally built version
```

### Building the setup installer

[Inno Setup 6](https://jrsoftware.org/isdl.php) is required:

```powershell
winget install JRSoftware.InnoSetup
.\Build-Installer.ps1 -Version 0.3.3     # output: release\WinGetManager-Setup-0.3.3.exe
```

### Regenerating the icon

```powershell
.\Generate-Icon.ps1                      # output: assets\icon.ico
```

## Questions?

Open an issue labeled `question` — happy to help.
