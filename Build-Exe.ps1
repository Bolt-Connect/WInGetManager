#Requires -Version 5.1
<#
.SYNOPSIS
    Bundles all PowerShell source files into a single .exe via PS2EXE.
.DESCRIPTION
    Output: build\WinGetManager.exe (+ build\config\settings.json)
    Double-click that EXE to start the app.
#>

$ErrorActionPreference = 'Stop'
$root      = $PSScriptRoot
$buildDir  = Join-Path $root 'build'
$bundle    = Join-Path $buildDir 'WinGetManager.bundle.ps1'
$exeFile   = Join-Path $buildDir 'WinGetManager.exe'

# --- 1. PS2EXE module ------------------------------------------------------
Write-Host "[1/6] PS2EXE module..." -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "      Installing..."
    Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
}
Import-Module ps2exe -Force

# --- 2. Build map opzetten -------------------------------------------------
Write-Host "[2/6] Preparing build folder..." -ForegroundColor Cyan

Get-Process -Name 'WinGetManager' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "      Terminating running process (PID $($_.Id))..."
    $_ | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

if (Test-Path $buildDir) {
    try {
        Remove-Item $buildDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "      Cleanup warning: $_" -ForegroundColor Yellow
        Remove-Item "$buildDir\WinGetManager.bundle.ps1" -Force -ErrorAction SilentlyContinue
        Remove-Item "$buildDir\WinGetManager.exe"        -Force -ErrorAction SilentlyContinue
    }
}
$null = New-Item -ItemType Directory -Path "$buildDir\config" -Force
$null = New-Item -ItemType Directory -Path "$buildDir\logs"   -Force

# --- 3. Helper: lees bron, strip signature-blocks en module-only kram -----
function Read-Cleaned {
    param([string]$Path, [switch]$IsModule, [switch]$StripParam)

    $rawLines = Get-Content $Path -Encoding UTF8

    # Stap 1: signature blocks weg
    $stage1 = New-Object System.Collections.Generic.List[string]
    $inSig  = $false
    foreach ($line in $rawLines) {
        if ($line -match '#\s*SIG\s*#\s*Begin signature block') { $inSig = $true; continue }
        if ($line -match '#\s*SIG\s*#\s*End signature block')   { $inSig = $false; continue }
        if (-not $inSig) { $stage1.Add($line) }
    }

    # Stap 2: Export-ModuleMember en Import-Module verwijderen, INCLUSIEF
    # backtick-line-continuation regels
    $stage2 = New-Object System.Collections.Generic.List[string]
    $skipContinuation = $false
    foreach ($line in $stage1) {
        if ($skipContinuation) {
            $skipContinuation = $line -match '`\s*$'
            continue
        }
        $stripThis = $false
        if ($IsModule -and $line -match '^\s*Export-ModuleMember\b')      { $stripThis = $true }
        if ((-not $IsModule) -and $line -match '^\s*Import-Module\b')     { $stripThis = $true }
        if ((-not $IsModule) -and $line -match '^\s*\$ScriptRoot\s*=\s*Split-Path') { $stripThis = $true }
        if ((-not $IsModule) -and $line -match '^\s*\$ScriptRoot\s*=\s*\$PSScriptRoot\s*$') { $stripThis = $true }
        if ($line -match '^\s*#Requires -Version') { $stripThis = $true }

        if ($stripThis) {
            $skipContinuation = $line -match '`\s*$'
            continue
        }
        $stage2.Add($line)
    }

    $c = ($stage2 -join "`r`n")

    if ($IsModule) {
        $c = $c.Replace('Join-Path $PSScriptRoot "..\..\$LogDirectory"',  'Join-Path $PSScriptRoot "$LogDirectory"')
        $c = $c.Replace("Join-Path `$PSScriptRoot '..\\..\\config\\settings.json'", "Join-Path `$PSScriptRoot 'config\\settings.json'")
    }

    if ($StripParam) {
        $c = [regex]::Replace($c, '(?s)^\s*param\s*\(.*?\)\s*', '', 'IgnoreCase')

        # Strip init-block uit WinGet-Silent.ps1 (de bundle initialiseert al)
        # Behoud alleen alles vanaf de eerste "if ($Search)" command-handler
        $lines3 = $c -split "`r?`n"
        $stage3 = New-Object System.Collections.Generic.List[string]
        $started = $false
        foreach ($l in $lines3) {
            if (-not $started) {
                if ($l -match '^\s*if\s*\(\s*\$Search\b') { $started = $true }
                else { continue }
            }
            $stage3.Add($l)
        }
        if ($stage3.Count -gt 0) { $c = ($stage3 -join "`r`n") }
    }

    return $c
}

# --- 4. Bundle samenstellen ------------------------------------------------
Write-Host "[3/6] Building bundle..." -ForegroundColor Cyan

$loggingCode = Read-Cleaned "$root\src\Core\Logging.psm1"      -IsModule
$configCode  = Read-Cleaned "$root\src\Core\Config.psm1"       -IsModule
$i18nCode    = Read-Cleaned "$root\src\Core\I18n.psm1"         -IsModule
$wingetCode  = Read-Cleaned "$root\src\Core\WinGet-Core.psm1"  -IsModule
$guiCode     = Read-Cleaned "$root\src\GUI\MainWindow.ps1"
$silentCode  = Read-Cleaned "$root\src\Silent\WinGet-Silent.ps1" -StripParam

$header = @'
# === WinGet Manager - bundled EXE ===
# Source: edit src/*.ps* and re-run Build-Exe.ps1

[CmdletBinding(DefaultParameterSetName = 'GUI')]
param(
    [Parameter(ParameterSetName='Silent')][switch]$UpdateAll,
    [Parameter(ParameterSetName='Silent')][switch]$Update,
    [Parameter(ParameterSetName='Silent')][string]$PackageId,
    [Parameter(ParameterSetName='Silent')][string]$Install,
    [Parameter(ParameterSetName='Silent')][string]$Uninstall,
    [Parameter(ParameterSetName='Silent')][string]$Search,
    [Parameter(ParameterSetName='Silent')][string]$ExportPath,
    [Parameter(ParameterSetName='Silent')][string]$ImportPath,
    [Parameter(ParameterSetName='Silent')][switch]$ListInstalled,
    [Parameter(ParameterSetName='Silent')][switch]$ListUpdates,
    [Parameter(ParameterSetName='Silent')][switch]$SelfUpdate,
    [Parameter(ParameterSetName='Silent')][switch]$Silent,
    [Parameter(ParameterSetName='Silent')][switch]$Elevated,
    [Parameter(ParameterSetName='Silent')][ValidateSet('user','machine')][string]$Scope = 'user',
    [Parameter(ParameterSetName='Silent')][switch]$IgnoreUnavailable,
    [Parameter(ParameterSetName='Silent')][switch]$NoConfirm,
    [Parameter(ParameterSetName='Silent')][string]$Source
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

$IsSilent = $PSCmdlet.ParameterSetName -eq 'Silent'
'@

$footer = @'

# === Main entry ===

# Handle empty ScriptRoot (can be empty under PS2EXE)
if (-not $ScriptRoot -or -not (Test-Path $ScriptRoot)) {
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if ($exePath) { $ScriptRoot = [System.IO.Path]::GetDirectoryName($exePath) }
    } catch {}
}
if (-not $ScriptRoot) { $ScriptRoot = (Get-Location).Path }

# === Smart config/log location ===
# Portable: write next to the exe if that folder is writable
# Otherwise: use %APPDATA%\WinGetManager (when installed in Program Files)
function Test-FolderWritable {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return $false }
        $testFile = Join-Path $Path ".wm_writetest_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        [System.IO.File]::WriteAllText($testFile, 'x')
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

if (Test-FolderWritable $ScriptRoot) {
    $DataRoot = $ScriptRoot
} else {
    $DataRoot = Join-Path $env:APPDATA 'WinGetManager'
    if (-not (Test-Path $DataRoot)) {
        New-Item -ItemType Directory -Path $DataRoot -Force | Out-Null
    }
}

$configPath = Join-Path $DataRoot 'config\settings.json'
Initialize-Config -ConfigPath $configPath
$cfg = Get-AppConfig

# --- I18n: stel taal in op basis van config (Language='auto' detecteert via OS) ---
try {
    $lang = if ($cfg.Language) { $cfg.Language } else { 'auto' }
    Initialize-I18n -Language $lang
} catch {
    # Niet-fataal: app draait in fallback-taal
}

$logDir = if ([System.IO.Path]::IsPathRooted($cfg.LogDirectory)) {
    $cfg.LogDirectory
} else {
    Join-Path $DataRoot $cfg.LogDirectory
}
$logArgs = @{
    LogDirectory  = $logDir
    MinLevel      = $cfg.LogLevel
    RetentionDays = $cfg.LogRetentionDays
    MaxSizeMB     = $cfg.MaxLogFileSizeMB
}
if ($IsSilent) { $logArgs.WriteToHost = $true }   # alleen in silent-modus naar console
Initialize-Logging @logArgs

try {
    Initialize-WinGetCore -WinGetPath $cfg.WinGetPath
} catch {
    if ($IsSilent) {
        Write-Log $_ -Level ERROR -Source Main
    } else {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($_.Exception.Message, (Get-Text 'Status.WinGetMissing'), "OK", "Error") | Out-Null
    }
    exit 1
}

if ($IsSilent) {
SILENT_BLOCK
} else {
GUI_BLOCK
}
'@

$body = $footer.Replace('SILENT_BLOCK', $silentCode).Replace('GUI_BLOCK', $guiCode)

$fullBundle = @"
$header

# --- Logging module ---
$loggingCode

# --- Config module ---
$configCode

# --- I18n module ---
$i18nCode

# --- WinGet Core module ---
$wingetCode

$body
"@

Set-Content -Path $bundle -Value $fullBundle -Encoding UTF8

# Verificatie
$bundleCheck = Get-Content $bundle -Raw
if ($bundleCheck -match 'SIG\s*#\s*Begin signature block') {
    throw "Bundle still contains signature blocks! Strip logic is broken."
}
$bytes = (Get-Item $bundle).Length
Write-Host "      Bundle OK: $bytes bytes, no signature blocks." -ForegroundColor Green

# --- 5. Config + assets ----------------------------------------------------
Write-Host "[4/6] Copying config..." -ForegroundColor Cyan
Copy-Item "$root\config\settings.json" "$buildDir\config\settings.json" -Force

# --- 6. Compileren ---------------------------------------------------------
Write-Host "[5/6] Compiling EXE with PS2EXE..." -ForegroundColor Cyan

$iconFile = Join-Path $root 'assets\icon.ico'
$ps2exeArgs = @{
    InputFile     = $bundle
    OutputFile    = $exeFile
    Title         = "WinGet Manager"
    Description   = "WinGet Package Manager met GUI"
    Company       = "Bolt-Connect"
    Product       = "WinGet Manager"
    Version       = "0.3.3.0"
    NoConsole     = $true
    STA           = $true
}
if (Test-Path $iconFile) {
    $ps2exeArgs.IconFile = $iconFile
    Write-Host "      Icon: $iconFile" -ForegroundColor Green
} else {
    Write-Host "      No icon found (run Generate-Icon.ps1 to create one)" -ForegroundColor Yellow
}

Invoke-PS2EXE @ps2exeArgs

# --- 7. Resultaat ----------------------------------------------------------
Write-Host "[6/6] Verification..." -ForegroundColor Cyan
if (Test-Path $exeFile) {
    $size = [math]::Round((Get-Item $exeFile).Length / 1KB, 1)
    Write-Host ""
    Write-Host "DONE!" -ForegroundColor Green
    Write-Host "  EXE:    $exeFile  ($size KB)"
    Write-Host "  Config: $buildDir\config\settings.json"
    Write-Host ""
    Write-Host "Double-click WinGetManager.exe to start."
    Write-Host ""
    Write-Host "For automatic updates (Task Scheduler):"
    Write-Host "  WinGetManager.exe -UpdateAll -Silent"
} else {
    Write-Host "Compilation failed!" -ForegroundColor Red
    exit 1
}
