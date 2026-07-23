#Requires -Version 5.1

$Script:WinGetExe = 'winget'
$Script:AppVersion = '0.3.3'

# ---------------------------------------------------------------------------
# Initialisatie
# ---------------------------------------------------------------------------

function Initialize-WinGetCore {
    param([string]$WinGetPath = 'winget')
    $Script:WinGetExe = $WinGetPath
    if (-not (Test-WinGetInstalled)) {
        throw (Get-Text 'Throw.WinGetNotFound')
    }
}

function Test-WinGetInstalled {
    try {
        $null = & $Script:WinGetExe --version 2>&1
        return $LASTEXITCODE -eq 0
    } catch { return $false }
}

function Get-WinGetVersion {
    try {
        $out = & $Script:WinGetExe --version 2>&1
        return ($out | Select-Object -First 1).ToString().Trim().TrimStart('v')
    } catch { return 'onbekend' }
}

# ---------------------------------------------------------------------------
# Interne helper: voer winget uit en geef JSON of tekst terug
# ---------------------------------------------------------------------------

function Invoke-WinGet {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$UseJson,
        [switch]$Elevated
    )

    $allArgs = $Arguments + @('--accept-source-agreements', '--disable-interactivity')
    if ($UseJson) { $allArgs += @('--output', 'json') }

    Write-Log "Executing: $Script:WinGetExe $allArgs" -Level DEBUG -Source WinGetCore

    if ($Elevated -and -not (Test-IsAdmin)) {
        # Start elevated proces en wacht
        $joined  = $allArgs -join ' '
        $process = Start-Process -FilePath $Script:WinGetExe -ArgumentList $joined `
                       -Verb RunAs -Wait -PassThru -WindowStyle Hidden
        return [PSCustomObject]@{ ExitCode = $process.ExitCode; Output = @() }
    }

    # Invoke winget through cmd.exe with MODE 250 to force wide column output.
    # In PS2EXE -NoConsole mode there's no parent console, so winget would
    # truncate long IDs like 'Microsoft.VCRedist.2015+.x86'. Wrapping in
    # `cmd /c "MODE CON: COLS=250 LINES=3000 & winget ..."` gives winget a
    # hidden console with wide buffer, no truncation.
    $tmpOut = [System.IO.Path]::GetTempFileName()
    try {
        # Quote each arg that contains spaces (winget IDs don't, but safety)
        $quoted = foreach ($a in $allArgs) {
            if ($a -match '\s') { '"' + $a + '"' } else { "$a" }
        }
        $wingetCmd = "$Script:WinGetExe " + ($quoted -join ' ')
        # MODE: 250 cols, 3000 lines. Redirect output to temp file for capture.
        $cmdLine = "/d /c `"MODE CON: COLS=250 LINES=3000 >nul 2>&1 & $wingetCmd > `"$tmpOut`" 2>&1`""
        $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdLine `
                  -WindowStyle Hidden -Wait -PassThru
        $ec = $proc.ExitCode
        $output = if (Test-Path $tmpOut) { Get-Content $tmpOut -Encoding UTF8 } else { @() }
    } catch {
        # Fallback to direct invocation
        $output = & $Script:WinGetExe @allArgs 2>&1
        $ec     = $LASTEXITCODE
    } finally {
        Remove-Item $tmpOut -Force -ErrorAction SilentlyContinue
    }

    if ($ec -ne 0 -and $ec -ne -1978335212) {   # -1978335212 = no updates available
        Write-Log "WinGet exitcode $ec for: $allArgs" -Level WARN -Source WinGetCore
    }

    return [PSCustomObject]@{ ExitCode = $ec; Output = $output }
}

# ---------------------------------------------------------------------------
# Zoeken
# ---------------------------------------------------------------------------

function Search-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string]$Source,
        [int]$Count = 50
    )

    Write-Log "Searching for: $Query" -Source WinGetCore
    $cmdArgs = @('search', $Query, '--count', $Count)
    if ($Source) { $cmdArgs += @('--source', $Source) }

    $result = Invoke-WinGet -Arguments $cmdArgs
    return Parse-PackageText $result.Output
}

# ---------------------------------------------------------------------------
# Geïnstalleerde packages
# ---------------------------------------------------------------------------

function Get-WinGetInstalled {
    param([string]$Source)

    Write-Log "Fetching installed packages" -Source WinGetCore
    $cmdArgs = @('list')
    if ($Source) { $cmdArgs += @('--source', $Source) }

    $result = Invoke-WinGet -Arguments $cmdArgs
    return Parse-PackageText $result.Output
}

# ---------------------------------------------------------------------------
# Beschikbare updates
# ---------------------------------------------------------------------------

function Get-WinGetUpdates {
    Write-Log "Checking for updates" -Source WinGetCore
    $result = Invoke-WinGet -Arguments @('upgrade')
    return Parse-PackageText $result.Output
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Version,
        [ValidateSet('user','machine')][string]$Scope = 'user',
        [switch]$Silent,
        [switch]$Elevated
    )

    Write-Log "Installing: $Id $(if($Version){"v$Version"})" -Source WinGetCore
    # Note: $args is a PowerShell automatic variable — never use it as a user variable
    # inside script-scope or scriptblocks where PS may reset it.
    $cmdArgs = @('install', '--id', $Id, '--exact', '--scope', $Scope)
    if ($Version) { $cmdArgs += @('--version', $Version) }
    if ($Silent)  { $cmdArgs += '--silent' }
    $cmdArgs += '--accept-package-agreements'

    $result = Invoke-WinGet -Arguments $cmdArgs -Elevated:$Elevated
    $ok     = $result.ExitCode -eq 0

    Write-Log "Installation $Id $(if($ok){'succeeded'}else{"failed (code $($result.ExitCode))"})" `
              -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

function Uninstall-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [ValidateSet('user','machine')][string]$Scope = 'user',
        [switch]$Silent,
        [switch]$Elevated
    )

    Write-Log "Uninstalling: $Id" -Source WinGetCore
    $cmdArgs = @('uninstall', '--id', $Id, '--exact', '--scope', $Scope)
    if ($Silent) { $cmdArgs += '--silent' }

    $result = Invoke-WinGet -Arguments $cmdArgs -Elevated:$Elevated
    $ok     = $result.ExitCode -eq 0

    Write-Log "Uninstall $Id $(if($ok){'succeeded'}else{"failed (code $($result.ExitCode))"})" `
              -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

function Update-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [switch]$Silent,
        [switch]$Elevated
    )

    Write-Log "Updating: $Id" -Source WinGetCore
    $cmdArgs = @('upgrade', '--id', $Id, '--exact', '--accept-package-agreements')
    if ($Silent) { $cmdArgs += '--silent' }

    $result = Invoke-WinGet -Arguments $cmdArgs -Elevated:$Elevated
    $ok     = $result.ExitCode -eq 0

    Write-Log "Update $Id $(if($ok){'succeeded'}else{"failed (code $($result.ExitCode))"})" `
              -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

function Update-AllWinGetPackages {
    param(
        [switch]$Silent,
        [switch]$Elevated,
        [scriptblock]$OnProgress
    )

    Write-Log "Updating all packages" -Source WinGetCore

    $updates = Get-WinGetUpdates
    if (-not $updates -or $updates.Count -eq 0) {
        Write-Log "No updates available" -Source WinGetCore
        return @{ Success = 0; Failed = 0; Packages = @() }
    }

    $success = 0; $failed = 0; $results = @()

    foreach ($pkg in $updates) {
        if ($OnProgress) { & $OnProgress $pkg.Name }
        $ok = Update-WinGetPackage -Id $pkg.Id -Silent:$Silent -Elevated:$Elevated
        if ($ok) { $success++ } else { $failed++ }
        $results += [PSCustomObject]@{ Id = $pkg.Id; Name = $pkg.Name; Success = $ok }
    }

    Write-Log "Update done: $success succeeded, $failed failed" -Source WinGetCore
    return @{ Success = $success; Failed = $failed; Packages = $results }
}

# ---------------------------------------------------------------------------
# Package details
# ---------------------------------------------------------------------------

function Get-WinGetPackageInfo {
    param([Parameter(Mandatory)][string]$Id)

    Write-Log "Fetching details: $Id" -Source WinGetCore
    $result = Invoke-WinGet -Arguments @('show', '--id', $Id, '--exact') -UseJson
    return Parse-PackageJson $result.Output | Select-Object -First 1
}

# ---------------------------------------------------------------------------
# Export / Import
# ---------------------------------------------------------------------------

function Export-WinGetPackages {
    param([Parameter(Mandatory)][string]$OutputPath)

    Write-Log "Exporting to: $OutputPath" -Source WinGetCore
    $result = Invoke-WinGet -Arguments @('export', '--output', $OutputPath)
    $ok     = $result.ExitCode -eq 0
    Write-Log "Export $(if($ok){'succeeded'}else{'failed'})" -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

function Import-WinGetPackages {
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [switch]$IgnoreUnavailable,
        [switch]$Elevated
    )

    Write-Log "Importing from: $InputPath" -Source WinGetCore
    $cmdArgs = @('import', '--import-file', $InputPath, '--accept-package-agreements')
    if ($IgnoreUnavailable) { $cmdArgs += '--ignore-unavailable' }

    $result = Invoke-WinGet -Arguments $cmdArgs -Elevated:$Elevated
    $ok     = $result.ExitCode -eq 0
    Write-Log "Import $(if($ok){'succeeded'}else{'failed'})" -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

# ---------------------------------------------------------------------------
# Bronnen (Sources)
# ---------------------------------------------------------------------------

function Get-WinGetSources {
    Write-Log "Fetching sources" -Source WinGetCore
    # Note: `winget source list` does not support --output json, so we parse text.
    $result = Invoke-WinGet -Arguments @('source', 'list')
    return Parse-SourceText $result.Output
}

function Add-WinGetSource {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [string]$Type = 'Microsoft.Rest'
    )

    Write-Log "Adding source: $Name ($Url)" -Source WinGetCore
    $result = Invoke-WinGet -Arguments @('source', 'add', '--name', $Name, '--arg', $Url, '--type', $Type) -Elevated
    $ok     = $result.ExitCode -eq 0
    Write-Log "Add source $(if($ok){'succeeded'}else{'failed'})" -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

function Remove-WinGetSource {
    param([Parameter(Mandatory)][string]$Name)

    Write-Log "Removing source: $Name" -Source WinGetCore
    $result = Invoke-WinGet -Arguments @('source', 'remove', '--name', $Name) -Elevated
    $ok     = $result.ExitCode -eq 0
    Write-Log "Remove source $(if($ok){'succeeded'}else{'failed'})" -Level $(if($ok){'INFO'}else{'ERROR'}) -Source WinGetCore
    return $ok
}

function Reset-WinGetSources {
    Write-Log "Resetting sources" -Source WinGetCore
    $result = Invoke-WinGet -Arguments @('source', 'reset', '--force') -Elevated
    return $result.ExitCode -eq 0
}

# ---------------------------------------------------------------------------
# Zelf-update
# ---------------------------------------------------------------------------

function Get-AppVersion { return $Script:AppVersion }

function Get-LatestAppVersion {
    param([string]$Url)
    if (-not $Url) { return $null }
    try {
        $data = Invoke-RestMethod -Uri $Url -TimeoutSec 15 -Headers @{
            'User-Agent' = "WinGetManager/$Script:AppVersion"
            'Accept'     = 'application/vnd.github+json'
        }
        $version = ($data.tag_name -replace '^v','').Trim()
        return [PSCustomObject]@{
            Version    = $version
            TagName    = $data.tag_name
            Name       = $data.name
            Body       = $data.body
            Url        = $data.html_url
            Assets     = @($data.assets | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.name
                    Url  = $_.browser_download_url
                    Size = $_.size
                }
            })
        }
    } catch {
        Write-Log "Version check failed: $_" -Level WARN -Source WinGetCore
        return $null
    }
}

function Test-TrustedUpdateUrl {
    param([string]$Url)
    if (-not $Url) { return $false }
    try {
        $uri = [System.Uri]$Url
        if ($uri.Scheme -ne 'https') { return $false }
        # Whitelist GitHub-hosts: api.github.com (releases API) en github.com (download URLs)
        return ($uri.Host -in @('api.github.com', 'github.com', 'objects.githubusercontent.com'))
    } catch { return $false }
}

function Test-PEFile {
    param([string]$Path)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path) | Select-Object -First 64
        # PE-bestand begint met "MZ" (0x4D 0x5A)
        return ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A)
    } catch { return $false }
}

function ConvertTo-AppVersion {
    # Extract a comparable [version] from a tag/version string.
    # '0.4.0-rc1' -> 0.4.0, 'v0.3.3' -> 0.3.3. Returns $null when no numeric
    # version can be found, so callers can fail gracefully instead of throwing.
    param([string]$Raw)
    if (-not $Raw) { return $null }
    $m = [regex]::Match($Raw, '\d+(\.\d+){1,3}')
    if (-not $m.Success) { return $null }
    try { return [version]$m.Value } catch { return $null }
}

function Get-FileSha256 {
    param([string]$Path)
    try {
        $sha    = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($Path)
        try { $hash = $sha.ComputeHash($stream) } finally { $stream.Dispose(); $sha.Dispose() }
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } catch { return $null }
}

function Get-ExpectedSha256 {
    # Parse a sha256sum-style checksums.txt ("<64-hex>  <filename>") and return
    # the hash for $FileName, or $null if the file isn't listed.
    param([string]$ChecksumsText, [string]$FileName)
    if (-not $ChecksumsText) { return $null }
    foreach ($line in ($ChecksumsText -split "`n")) {
        $t = $line.Trim()
        if (-not $t) { continue }
        $m = [regex]::Match($t, '^([0-9a-fA-F]{64})\s+\*?(.+)$')
        if ($m.Success -and ($m.Groups[2].Value.Trim() -ieq $FileName)) {
            return $m.Groups[1].Value.ToLowerInvariant()
        }
    }
    return $null
}

function Update-App {
    param(
        [Parameter(Mandatory)][string]$Url,
        [scriptblock]$OnProgress,
        [string]$ExePath,
        [string]$AssetName = 'WinGetManager.exe'
    )

    # Security: weiger non-HTTPS of niet-vertrouwde hosts
    if (-not (Test-TrustedUpdateUrl $Url)) {
        Write-Log "Update denied - URL not trusted: $Url" -Level WARN -Source WinGetCore
        return [PSCustomObject]@{ Updated = $false; Reason = 'untrusted_url' }
    }

    $info = Get-LatestAppVersion -Url $Url
    if (-not $info -or -not $info.Version) {
        return [PSCustomObject]@{ Updated = $false; Reason = 'no_response' }
    }

    # Parse both versions defensively. A tag with a pre-release suffix
    # (e.g. '0.4.0-rc1') would throw on a bare [version] cast; ConvertTo-AppVersion
    # extracts the numeric core so comparison never crashes, and logs clearly
    # instead of returning a silent 'invalid_version'.
    $latestVer  = ConvertTo-AppVersion $info.Version
    $currentVer = ConvertTo-AppVersion $Script:AppVersion
    if (-not $latestVer -or -not $currentVer) {
        Write-Log "Cannot parse version for update comparison (latest='$($info.Version)', current='$Script:AppVersion')" -Level WARN -Source WinGetCore
        return [PSCustomObject]@{ Updated = $false; Reason = 'invalid_version'; Latest = $info.Version }
    }

    if ($latestVer -le $currentVer) {
        return [PSCustomObject]@{
            Updated = $false; Reason = 'up_to_date'
            Current = $Script:AppVersion; Latest = $info.Version
        }
    }

    # Vind het juiste asset
    $exeAsset = $info.Assets | Where-Object { $_.Name -eq $AssetName } | Select-Object -First 1
    if (-not $exeAsset) {
        return [PSCustomObject]@{ Updated = $false; Reason = 'no_asset'; Latest = $info.Version }
    }

    # Pad naar huidige exe (alleen werkt voor PS2EXE bundels - .ps1 niet vervangbaar)
    if (-not $ExePath) {
        try { $ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch {}
    }
    if (-not $ExePath -or $ExePath -notmatch '\.exe$') {
        return [PSCustomObject]@{ Updated = $false; Reason = 'not_exe_runtime'; Latest = $info.Version }
    }

    # Bail out gracefully when running from a system-wide install location.
    # Writing to C:\Program Files\... requires admin rights, and silently failing
    # makes the user think the update button is broken. Returning 'requires_admin'
    # lets the GUI show a friendly "Download Setup.exe manually" message with a link.
    $pf      = [Environment]::GetFolderPath('ProgramFiles')
    $pfX86   = [Environment]::GetFolderPath('ProgramFilesX86')
    $exeDir  = [System.IO.Path]::GetDirectoryName($ExePath)
    $inSysPF = ($pf    -and $exeDir.StartsWith($pf,    [StringComparison]::OrdinalIgnoreCase)) -or `
               ($pfX86 -and $exeDir.StartsWith($pfX86, [StringComparison]::OrdinalIgnoreCase))
    if ($inSysPF) {
        # Try to write a probe file to confirm we really cannot write here.
        # Some setups (e.g. very permissive folders) might still work, so we only
        # block when the write actually fails.
        $probe = Join-Path $exeDir ".wgm-update-probe-$([guid]::NewGuid().Guid.Substring(0,8))"
        try {
            [System.IO.File]::WriteAllBytes($probe, [byte[]]@(0))
            Remove-Item $probe -Force -ErrorAction SilentlyContinue
            Write-Log "ExE is in Program Files but folder is writable; continuing self-update" -Source WinGetCore
        } catch {
            Write-Log "Self-update blocked: $ExePath is in Program Files and not writable" -Level WARN -Source WinGetCore
            # Find the setup installer asset so the GUI can offer a direct download
            $setupAsset = $info.Assets | Where-Object { $_.Name -like '*Setup*.exe' } | Select-Object -First 1
            $setupUrl   = if ($setupAsset) { $setupAsset.Url } else { $info.Url }
            return [PSCustomObject]@{
                Updated  = $false
                Reason   = 'requires_admin'
                Current  = $Script:AppVersion
                Latest   = $info.Version
                SetupUrl = $setupUrl
                ReleaseUrl = $info.Url
            }
        }
    }

    # Re-validate the asset download URL. Test-TrustedUpdateUrl only ran on the
    # API endpoint; the asset URL is derived from the API response, so verify it
    # is itself an HTTPS github host before handing it to the downloader.
    if (-not (Test-TrustedUpdateUrl $exeAsset.Url)) {
        Write-Log "Update denied - asset URL not trusted: $($exeAsset.Url)" -Level WARN -Source WinGetCore
        return [PSCustomObject]@{ Updated = $false; Reason = 'untrusted_url'; Latest = $info.Version }
    }

    # Download naar tijdelijk bestand naast huidige exe
    $tempExe = "$ExePath.new"
    try {
        if ($OnProgress) { & $OnProgress 'download' $info.Version }
        Invoke-WebRequest -Uri $exeAsset.Url -OutFile $tempExe -UseBasicParsing -TimeoutSec 120
    } catch {
        Write-Log "Download failed: $_" -Level ERROR -Source WinGetCore
        return [PSCustomObject]@{ Updated = $false; Reason = 'download_failed'; Latest = $info.Version }
    }

    # Verify that the download succeeded and that it is a real PE/EXE
    if (-not (Test-Path $tempExe) -or (Get-Item $tempExe).Length -lt 50KB) {
        Remove-Item $tempExe -Force -ErrorAction SilentlyContinue
        return [PSCustomObject]@{ Updated = $false; Reason = 'corrupt_download'; Latest = $info.Version }
    }
    if (-not (Test-PEFile $tempExe)) {
        Remove-Item $tempExe -Force -ErrorAction SilentlyContinue
        Write-Log "Download is not a valid .exe (PE header missing)" -Level ERROR -Source WinGetCore
        return [PSCustomObject]@{ Updated = $false; Reason = 'invalid_exe'; Latest = $info.Version }
    }

    # Verify SHA256 against the release's checksums.txt. A PE-header check only
    # proves "this is an exe", not "this is our exe" — the hash confirms the bytes
    # match what we published. If the release has no checksums.txt (older releases
    # predating v0.3.3), log and proceed rather than blocking the update. This
    # gives integrity against corrupt/in-transit-tampered downloads; it is not a
    # substitute for code-signing (a fully compromised release could swap both).
    $sumsAsset = $info.Assets | Where-Object { $_.Name -eq 'checksums.txt' } | Select-Object -First 1
    if ($sumsAsset -and (Test-TrustedUpdateUrl $sumsAsset.Url)) {
        try {
            $sumsText = (Invoke-WebRequest -Uri $sumsAsset.Url -UseBasicParsing -TimeoutSec 30).Content
            $expected = Get-ExpectedSha256 -ChecksumsText $sumsText -FileName $exeAsset.Name
            if ($expected) {
                $actual = Get-FileSha256 $tempExe
                if ($actual -ne $expected) {
                    Remove-Item $tempExe -Force -ErrorAction SilentlyContinue
                    Write-Log "Checksum mismatch for $($exeAsset.Name): expected $expected got $actual" -Level ERROR -Source WinGetCore
                    return [PSCustomObject]@{ Updated = $false; Reason = 'checksum_mismatch'; Latest = $info.Version }
                }
                Write-Log "SHA256 verified for $($exeAsset.Name)" -Source WinGetCore
            } else {
                Write-Log "checksums.txt present but no entry for $($exeAsset.Name); skipping hash check" -Level WARN -Source WinGetCore
            }
        } catch {
            Write-Log "Could not fetch/verify checksums.txt: $_" -Level WARN -Source WinGetCore
        }
    } else {
        Write-Log "No checksums.txt in release; skipping SHA256 verification" -Level WARN -Source WinGetCore
    }

    Write-Log "Download succeeded ($([math]::Round((Get-Item $tempExe).Length/1KB,1)) KB), swapping exe..." -Source WinGetCore

    # Maak een replace-batch die de huidige exe vervangt zodra deze stopt
    $batPath = Join-Path $env:TEMP "WinGetManager-Update-$(Get-Date -Format 'yyyyMMddHHmmss').bat"
    $bat = @"
@echo off
:loop
ping -n 2 127.0.0.1 >nul
del "$ExePath" 2>nul
if exist "$ExePath" goto loop
move /Y "$tempExe" "$ExePath" >nul
start "" "$ExePath"
del "%~f0"
"@
    Set-Content -Path $batPath -Value $bat -Encoding ASCII

    if ($OnProgress) { & $OnProgress 'launching' $info.Version }
    Start-Process -FilePath $batPath -WindowStyle Hidden

    return [PSCustomObject]@{
        Updated = $true; Latest = $info.Version
        Current = $Script:AppVersion; ExePath = $ExePath
    }
}

# ---------------------------------------------------------------------------
# Admin check
# ---------------------------------------------------------------------------

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# JSON parse helpers
# ---------------------------------------------------------------------------

function Resolve-PackageSource {
    <#
    .SYNOPSIS
        Bepaalt de logische source van een package wanneer winget die niet meldt.
    .DESCRIPTION
        WinGet vult de Source-kolom niet altijd in voor `winget list` (MSIX/ARP
        installaties). We leiden af op basis van het ID-prefix:
          - 'MSIX\...'  -> 'msstore'   (Microsoft Store package)
          - 'ARP\...'   -> 'lokaal'    (handmatige/installer-install, geen winget-bron)
          - alles anders zonder source -> 'winget' (Publisher.AppName patroon)
    #>
    param(
        [Parameter(Mandatory)][AllowNull()][string]$Id,
        [AllowNull()][string]$ExistingSource
    )
    if ($ExistingSource -and $ExistingSource.Trim()) { return $ExistingSource }
    if (-not $Id) { return '' }
    if ($Id -match '^MSIX\\') { return 'msstore' }
    if ($Id -match '^ARP\\')  { return 'local' }
    return 'winget'
}

function Parse-PackageJson {
    param([object[]]$RawOutput)

    $json = ($RawOutput | Out-String).Trim()
    if (-not $json) { return @() }

    try {
        $data = $json | ConvertFrom-Json
        $list = if ($data.Sources) {
            $data.Sources | ForEach-Object { $_.Packages } | ForEach-Object { $_ }
        } elseif ($data.PSObject.Properties['Packages']) {
            $data.Packages
        } else {
            @($data)
        }

        return $list | ForEach-Object {
            $item = $_
            $id   = if ($item.PackageIdentifier) { $item.PackageIdentifier } elseif ($item.Id) { $item.Id } else { '' }
            $src  = if ($item.Source)            { $item.Source }            else { '' }
            [PSCustomObject]@{
                Id              = $id
                Name            = if ($item.PackageName)       { $item.PackageName }       elseif ($item.Name)        { $item.Name }    else { '' }
                Version         = if ($item.PackageVersion)    { $item.PackageVersion }    elseif ($item.Version)     { $item.Version } else { '' }
                AvailableVersion= if ($item.AvailableVersion)  { $item.AvailableVersion }  else { '' }
                Source          = Resolve-PackageSource -Id $id -ExistingSource $src
                Publisher       = if ($item.Publisher)         { $item.Publisher }         else { '' }
            }
        }
    } catch {
        # Fallback: parse tekst-tabel als JSON niet beschikbaar is
        return Parse-PackageText $RawOutput
    }
}

function Parse-PackageText {
    param([object[]]$Lines)

    if (-not $Lines) { return @() }

    # Normaliseer naar string-array
    $textLines = @()
    foreach ($l in $Lines) {
        if ($null -ne $l) { $textLines += $l.ToString() }
    }

    # Zoek scheidingslijn: aaneengesloten dashes (winget gebruikt - of unicode)
    $separatorIdx = -1
    for ($i = 1; $i -lt $textLines.Count; $i++) {
        if ($textLines[$i] -match '^[-─]{3,}\s*$') {
            $separatorIdx = $i
            break
        }
    }
    if ($separatorIdx -lt 1) { return @() }

    $headerLine = $textLines[$separatorIdx - 1]

    # Kolomposities afleiden uit de header (titels gescheiden door 2+ spaties)
    $columns = @()
    $regex   = [regex]'\S(?:[^ ]| (?! ))*'
    foreach ($m in $regex.Matches($headerLine)) {
        $columns += [PSCustomObject]@{
            Name  = $m.Value.Trim()
            Start = $m.Index
            End   = $m.Index + $m.Length
        }
    }
    if ($columns.Count -eq 0) { return @() }

    # Eindgrenzen verlengen tot start van volgende kolom (regels kunnen breder zijn)
    for ($i = 0; $i -lt $columns.Count - 1; $i++) {
        $columns[$i].End = $columns[$i + 1].Start
    }
    $columns[-1].End = 9999

    $results = @()
    for ($i = $separatorIdx + 1; $i -lt $textLines.Count; $i++) {
        $line = $textLines[$i]
        if ([string]::IsNullOrWhiteSpace($line))    { continue }
        # Footer-regels van winget (zowel NL als EN):
        #   "3 upgrades available."
        #   "X package(s) have...", "X pakket(ten)..."
        #   "X updates available"
        if ($line -match '^\s*\d+\s+(package|pakket|upgrade|update)') { continue }
        if ($line -match '\bavailable\.?\s*$')      { continue }
        if ($line -match '^(No|Geen)\b')            { continue }
        # Filter winget-progress chars (\, |, /, -)
        if ($line -match '^[\\\|\/\s-]+$')          { continue }
        # Tekstregels zonder package-id (alleen waarschuwingen of footer-tekst)
        # Een echte data-rij heeft minstens iets op de Id-kolom positie
        $idCol = $columns | Where-Object { $_.Name -eq 'Id' } | Select-Object -First 1
        if ($idCol -and $line.Length -gt $idCol.Start) {
            $idCheck = $line.Substring($idCol.Start, [Math]::Min($idCol.End, $line.Length) - $idCol.Start).Trim()
            if (-not $idCheck) { continue }
        }

        $obj = [PSCustomObject]@{
            Id = ''; Name = ''; Version = ''
            AvailableVersion = ''; Source = ''; Publisher = ''
        }

        foreach ($col in $columns) {
            if ($col.Start -ge $line.Length) { continue }
            $end = [Math]::Min($col.End, $line.Length)
            $val = $line.Substring($col.Start, $end - $col.Start).Trim()

            switch -Wildcard ($col.Name) {
                'Name'      { $obj.Name             = $val }
                'Id'        {
                    # Strip winget legend markers (leading ᵃ ᵇ ᵈ etc. — superscript
                    # letters that flag special packages like multi-installed VCRedist)
                    $obj.Id = ($val -replace '^[^A-Za-z0-9{]+', '').Trim()
                }
                'Version'   { $obj.Version          = $val }
                'Available' { $obj.AvailableVersion = $val }
                'Source'    { $obj.Source           = $val }
            }
        }
        if ($obj.Id -or $obj.Name) {
            $obj.Source = Resolve-PackageSource -Id $obj.Id -ExistingSource $obj.Source
            $results += $obj
        }
    }

    return $results
}

function Parse-SourceText {
    <#
    .SYNOPSIS
        Parses the text output of `winget source list`.
    .DESCRIPTION
        Output format (winget 1.x):
            Name        Argument                                           Type
            -------------------------------------------------------------------
            winget      https://cdn.winget.microsoft.com/cache             Microsoft.PreIndexed.Package
            msstore     https://storeedgefd.dsx.mp.microsoft.com/v9.0      Microsoft.Rest
    #>
    param([object[]]$RawOutput)

    if (-not $RawOutput) { return @() }

    $textLines = @()
    foreach ($l in $RawOutput) {
        if ($null -ne $l) { $textLines += $l.ToString() }
    }

    # Find separator line (dashes/unicode dashes)
    $separatorIdx = -1
    for ($i = 1; $i -lt $textLines.Count; $i++) {
        if ($textLines[$i] -match '^[-─]{3,}\s*$') { $separatorIdx = $i; break }
    }
    if ($separatorIdx -lt 1) { return @() }

    $headerLine = $textLines[$separatorIdx - 1]
    $columns = @()
    $regex   = [regex]'\S(?:[^ ]| (?! ))*'
    foreach ($m in $regex.Matches($headerLine)) {
        $columns += [PSCustomObject]@{
            Name  = $m.Value.Trim()
            Start = $m.Index
            End   = $m.Index + $m.Length
        }
    }
    if ($columns.Count -eq 0) { return @() }

    for ($i = 0; $i -lt $columns.Count - 1; $i++) {
        $columns[$i].End = $columns[$i + 1].Start
    }
    $columns[-1].End = 9999

    $results = @()
    for ($i = $separatorIdx + 1; $i -lt $textLines.Count; $i++) {
        $line = $textLines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $obj = [PSCustomObject]@{ Name = ''; Url = ''; Type = '' }

        foreach ($col in $columns) {
            if ($col.Start -ge $line.Length) { continue }
            $end = [Math]::Min($col.End, $line.Length)
            $val = $line.Substring($col.Start, $end - $col.Start).Trim()
            switch -Wildcard ($col.Name) {
                'Name'     { $obj.Name = $val }
                'Argument' { $obj.Url  = $val }
                'Type'     { $obj.Type = $val }
            }
        }
        if ($obj.Name) { $results += $obj }
    }
    return $results
}

Export-ModuleMember -Function `
    Initialize-WinGetCore, Test-WinGetInstalled, Get-WinGetVersion, `
    Search-WinGetPackage, Get-WinGetInstalled, Get-WinGetUpdates, `
    Install-WinGetPackage, Uninstall-WinGetPackage, `
    Update-WinGetPackage, Update-AllWinGetPackages, `
    Get-WinGetPackageInfo, `
    Export-WinGetPackages, Import-WinGetPackages, `
    Get-WinGetSources, Add-WinGetSource, Remove-WinGetSource, Reset-WinGetSources, `
    Get-AppVersion, Get-LatestAppVersion, Update-App, `
    Test-TrustedUpdateUrl, `
    Test-IsAdmin

# SIG # Begin signature block
# MIIFggYJKoZIhvcNAQcCoIIFczCCBW8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+DLG2dnVUM2vfv7O+RGJNGOZ
# 7KOgggMWMIIDEjCCAfqgAwIBAgIQERy/5noS0YNDQ+ns6effbDANBgkqhkiG9w0B
# AQsFADAhMR8wHQYDVQQDDBZXaW5HZXRNYW5hZ2VyIExvY2FsRGV2MB4XDTI2MDUw
# NTE2NDgxOVoXDTM2MDUwNTE2NTgxOVowITEfMB0GA1UEAwwWV2luR2V0TWFuYWdl
# ciBMb2NhbERldjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ807LAn
# KDnHe2OML2epBu8NQPQJcoungebjGrM9Sls7qYoaHxPzIwAn5O6NcjyPeBT27nFl
# eQD5HRtffpch5eH8G6weLo/GMmx6z9xWXYEuCqWbzaqcoyYcBTcbwvuz5rOHVxe1
# h4V577zRq5fMxI4oHkneX1/nc36IQznorEvflz86FAw3TwodaT4E7Gw/xH7EQ1MO
# UCwCpsZDdKvZdSrEzgpnFmHqbhjCsOBQLVVoYud0syXosGBQt9JwwaZvp3mQvoJu
# rch0yTuMCIlc46dkecMF4k6xxnXWSifCG+/qqJwYesgRdshr7BqRfXfhJBifREJe
# P6a2k+5RSuScq6kCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB0GA1UdDgQWBBTB/nzy91KscDO0MblJ8J7M61u28DANBgkqhkiG
# 9w0BAQsFAAOCAQEAUfMEGcqt3OmRMubGOQ7UP9GnMDHV6V74QDFa5Za2hcLCH14s
# J08tg9/3ahctk+0iXuLp/+UOT1pfMPDblQQ7QhLegc9PF0BJH+3DEMr0x7IXnquF
# BSzMgkvAFHUXwGmLOeatJjC1ryMk379hqIIt1eBx6852ye/ID0A3H42Od7v+Y2si
# AFPxSLu8NoLuuhzlsKqdY4lhRZ5vbflD3WGPxC92A747x9uRGCO5QipXSVJVviFL
# D1ZlACyUIRdpH4Ex3x+hfjr7rkJm63KiG9u3S0GYwZ5uU3x3RjA/h6e5F0lscWJa
# blzdQy335fx0Y5i2hoCBRue8IfYWbXy69JWQFDGCAdYwggHSAgEBMDUwITEfMB0G
# A1UEAwwWV2luR2V0TWFuYWdlciBMb2NhbERldgIQERy/5noS0YNDQ+ns6effbDAJ
# BgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAj
# BgkqhkiG9w0BCQQxFgQUe6BRJMCMw7Qp78BjsxO9fowjmJ4wDQYJKoZIhvcNAQEB
# BQAEggEAGgpo3dtQAcNxusBlmzwqSPCzI0jQH8zIfPhW2O3ljBCz0b1vMdgrRWIO
# cfmo5u25EB1znEny+RP1FSlEeGRJMTJTi0lyx8FqxKi/VQ3oB7iCRIMZTQM5qYc6
# Q79f+kVGsj/IRq/orkvAothPtkfQ4pg8M2rC703VRQ/67uUEksxIh/9sSv0EZQA7
# Hw+mfh3zAle+3XWwxkrS/Tq00DPiEBQopIfVPpu8E9o/jXYI6dL21S33hDt4W2kt
# 2DzsZNIjV/nPsApHVXIOe9uh6Baeu1TBqQ6CMO2j/gJQ6x178vHiXyBQuDaee8Uq
# cOySv+0oni8VEx8A8T5oBDQbiE9yeA==
# SIG # End signature block
