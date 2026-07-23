#Requires -Version 5.1
<#
.SYNOPSIS
    Asserts that every i18n language dictionary exposes exactly the same set of keys.
.DESCRIPTION
    The translations in src/Core/I18n.psm1 are hand-maintained hashtables (nl-NL,
    en-US). It is easy to add a key to one language and forget the other, which
    surfaces as a raw "{{Key.Name}}" in the UI. This standalone test catches that
    whole class of bug. It is dependency-free (no Pester) so CI can run it on the
    Windows PowerShell 5.1 that ships with the runner.

    Exit code 0 = all languages in sync. Exit code 1 = missing keys (details printed).
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module "$root\src\Core\I18n.psm1" -Force

$strings = Get-I18nStrings
$langs   = @($strings.Keys)

if ($langs.Count -lt 2) {
    Write-Host "Only $($langs.Count) language(s) found; nothing to compare." -ForegroundColor Yellow
    exit 0
}

# Union of all keys across every language, then report per-language gaps.
$allKeys = [System.Collections.Generic.HashSet[string]]::new()
foreach ($lang in $langs) {
    foreach ($k in $strings[$lang].Keys) { [void]$allKeys.Add($k) }
}

$hasError = $false
foreach ($lang in $langs) {
    $present = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($k in $strings[$lang].Keys) { [void]$present.Add($k) }

    $missing = @($allKeys | Where-Object { -not $present.Contains($_) } | Sort-Object)
    if ($missing.Count -gt 0) {
        $hasError = $true
        Write-Host "[$lang] is missing $($missing.Count) key(s):" -ForegroundColor Red
        foreach ($m in $missing) { Write-Host "    $m" -ForegroundColor Red }
    } else {
        Write-Host "[$lang] OK - $($present.Count) keys" -ForegroundColor Green
    }
}

if ($hasError) {
    Write-Host ""
    Write-Host "i18n key parity FAILED - add the missing keys to both dictionaries in src/Core/I18n.psm1" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "i18n key parity OK - all $($langs.Count) languages share $($allKeys.Count) keys." -ForegroundColor Green
exit 0
