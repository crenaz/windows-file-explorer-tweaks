<#
.SYNOPSIS
    Adds "Markdown Document" to the Windows File Explorer "New" context menu.

.DESCRIPTION
    Configures HKEY_CLASSES_ROOT for .md files to include a ShellNew subkey.
    Uses display name "Markdown Document" for a clean, native entry in the New submenu.
    Performs automated pre-flight registry backups before making changes.

.PARAMETER RestartExplorer
    If specified, restarts the Windows Explorer process (explorer.exe) after applying changes.

.EXAMPLE
    .\Add-MarkdownNew.ps1
    Applies the registry changes and notifies the Windows Shell.

.EXAMPLE
    .\Add-MarkdownNew.ps1 -RestartExplorer
    Applies the registry changes and restarts Windows Explorer.
#>

[CmdletBinding()]
param(
    [switch]$RestartExplorer
)

# 1. Resolve Safety Engine module (if present in repo)
$tweakEnginePath = $null
$possibleModulePaths = @(
    (Join-Path $PSScriptRoot "..\tools\TweakEngine.psm1"),
    (Join-Path $PSScriptRoot "..\..\tools\TweakEngine.psm1")
)
foreach ($p in $possibleModulePaths) {
    if (Test-Path $p) {
        $tweakEnginePath = (Resolve-Path $p).Path
        break
    }
}
if ($tweakEnginePath) {
    Import-Module $tweakEnginePath -Force -ErrorAction SilentlyContinue
}

# 2. Ensure Administrator Privileges
if (Get-Command Confirm-AdminPrivilege -ErrorAction SilentlyContinue) {
    $argString = ""
    if ($RestartExplorer) { $argString = "-RestartExplorer" }
    Confirm-AdminPrivilege -ScriptPath $PSCommandPath -ArgumentString $argString
} else {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "[!] Administrator privileges required. Attempting elevation..." -ForegroundColor Yellow
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($RestartExplorer) { $argList += " -RestartExplorer" }
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
            exit
        }
        catch {
            Write-Error "Failed to elevate. Please run PowerShell as Administrator and retry."
            exit 1
        }
    }
}

Write-Host "==> Applying 'Markdown Document' Explorer New Menu Tweak..." -ForegroundColor Cyan

$mdPath = "Registry::HKEY_CLASSES_ROOT\.md"
$shellNewPath = "$mdPath\ShellNew"
$progIdPath = "Registry::HKEY_CLASSES_ROOT\MarkdownDocument"
$iconPath = "$progIdPath\DefaultIcon"

try {
    # 3. Pre-Flight Safety Backup
    $backupFiles = @()
    if (Get-Command Backup-RegistryKey -ErrorAction SilentlyContinue) {
        $b1 = Backup-RegistryKey -RegistryKey "HKCR\.md" -TweakName "new-markdown-document"
        if ($b1) { $backupFiles += $b1 }
        $b2 = Backup-RegistryKey -RegistryKey "HKCR\MarkdownDocument" -TweakName "new-markdown-document"
        if ($b2) { $backupFiles += $b2 }
    }

    # 4. Back up existing ProgID default if present and not already MarkdownDocument
    if (Test-Path -Path $mdPath) {
        $currentDefault = (Get-ItemProperty -Path $mdPath -ErrorAction SilentlyContinue).'(default)'
        if ($currentDefault -and $currentDefault -ne "MarkdownDocument") {
            Write-Host "    Preserving current default ProgID ($currentDefault) as fallback..." -ForegroundColor Gray
            Set-ItemProperty -Path $mdPath -Name "BackupDefaultProgId" -Value $currentDefault -Force
        }
    } else {
        New-Item -Path $mdPath -Force | Out-Null
    }

    # 5. Configure .md file association
    Write-Host "    Setting .md file type association..." -ForegroundColor Gray
    Set-ItemProperty -Path $mdPath -Name "(Default)" -Value "MarkdownDocument" -Force
    Set-ItemProperty -Path $mdPath -Name "Content Type" -Value "text/markdown" -Force
    Set-ItemProperty -Path $mdPath -Name "PerceivedType" -Value "text" -Force

    # 6. Create ShellNew entry
    Write-Host "    Creating ShellNew template..." -ForegroundColor Gray
    if (-not (Test-Path -Path $shellNewPath)) {
        New-Item -Path $shellNewPath -Force | Out-Null
    }
    Set-ItemProperty -Path $shellNewPath -Name "NullFile" -Value "" -Force

    # 7. Configure ProgID and Friendly Name
    Write-Host "    Configuring ProgID 'MarkdownDocument' display name..." -ForegroundColor Gray
    if (-not (Test-Path -Path $progIdPath)) {
        New-Item -Path $progIdPath -Force | Out-Null
    }
    Set-ItemProperty -Path $progIdPath -Name "(Default)" -Value "Markdown Document" -Force

    # 8. Configure Default Icon
    Write-Host "    Configuring icon..." -ForegroundColor Gray
    if (-not (Test-Path -Path $iconPath)) {
        New-Item -Path $iconPath -Force | Out-Null
    }
    Set-ItemProperty -Path $iconPath -Name "(Default)" -Value "%SystemRoot%\System32\imageres.dll,-102" -Force

    # 9. Register in State Manifest
    if (Get-Command Register-TweakState -ErrorAction SilentlyContinue) {
        Register-TweakState -TweakId "context-menu.new-markdown-document" `
                            -TweakName "Markdown Document New Menu" `
                            -ModifiedKeys @("HKCR\.md", "HKCR\.md\ShellNew", "HKCR\MarkdownDocument") `
                            -BackupFiles $backupFiles
    }

    # 10. Notify the Windows Shell
    if (Get-Command Invoke-ShellRefresh -ErrorAction SilentlyContinue) {
        Invoke-ShellRefresh -RestartExplorer:$RestartExplorer
    } else {
        Write-Host "    Notifying Windows Shell of association change..." -ForegroundColor Gray
        if (-not ([System.Management.Automation.PSTypeName]'ShellNotify.Win32Shell').Type) {
            $sig = '[System.Runtime.InteropServices.DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);'
            Add-Type -MemberDefinition $sig -Name "Win32Shell" -Namespace "ShellNotify" -ErrorAction SilentlyContinue
        }
        [ShellNotify.Win32Shell]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)

        if ($RestartExplorer) {
            Write-Host "    Restarting Windows Explorer..." -ForegroundColor Yellow
            Stop-Process -Name explorer -Force
            Start-Sleep -Seconds 1
            Start-Process explorer.exe
        }
    }

    Write-Host "[OK] Successfully installed 'Markdown Document' into Explorer New menu!" -ForegroundColor Green
    Write-Host "    Right-click in File Explorer -> New -> 'Markdown Document'." -ForegroundColor Gray
}
catch {
    Write-Error "Failed to apply registry changes: $_"
    exit 1
}
