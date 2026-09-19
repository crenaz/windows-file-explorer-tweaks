<#
.SYNOPSIS
    Removes "Text Document (Markdown)" from the Windows File Explorer "New" context menu.

.DESCRIPTION
    Safely removes the ShellNew subkey under HKEY_CLASSES_ROOT\.md and cleans up
    the MarkdownDocument ProgID without disturbing third-party file handlers or extensions.
    Unregisters the tweak from the state manifest.

.PARAMETER RestartExplorer
    If specified, restarts the Windows Explorer process (explorer.exe) after applying changes.

.EXAMPLE
    .\Remove-MarkdownNew.ps1
    Rolls back the registry changes and notifies the Windows Shell.

.EXAMPLE
    .\Remove-MarkdownNew.ps1 -RestartExplorer
    Rolls back the registry changes and restarts Windows Explorer.
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

Write-Host "==> Reverting 'Text Document (Markdown)' Explorer New Menu Tweak..." -ForegroundColor Cyan

$mdPath = "Registry::HKEY_CLASSES_ROOT\.md"
$shellNewPath = "$mdPath\ShellNew"
$progIdPath = "Registry::HKEY_CLASSES_ROOT\MarkdownDocument"

try {
    # 3. Remove ShellNew subkey
    if (Test-Path -Path $shellNewPath) {
        Write-Host "    Removing ShellNew subkey under .md..." -ForegroundColor Gray
        Remove-Item -Path $shellNewPath -Recurse -Force
    }

    # 4. Restore or clean up .md (Default) ProgID pointer
    if (Test-Path -Path $mdPath) {
        $backupProgId = (Get-ItemProperty -Path $mdPath -ErrorAction SilentlyContinue).BackupDefaultProgId
        $currentDefault = (Get-ItemProperty -Path $mdPath -ErrorAction SilentlyContinue).'(default)'

        if ($backupProgId) {
            Write-Host "    Restoring previous ProgID ($backupProgId)..." -ForegroundColor Gray
            Set-ItemProperty -Path $mdPath -Name "(Default)" -Value $backupProgId -Force
            Remove-ItemProperty -Path $mdPath -Name "BackupDefaultProgId" -ErrorAction SilentlyContinue
        }
        elseif ($currentDefault -eq "MarkdownDocument") {
            Write-Host "    Clearing default ProgID pointer..." -ForegroundColor Gray
            Set-ItemProperty -Path $mdPath -Name "(Default)" -Value "" -Force
        }
    }

    # 5. Remove MarkdownDocument ProgID key
    if (Test-Path -Path $progIdPath) {
        Write-Host "    Removing ProgID key 'MarkdownDocument'..." -ForegroundColor Gray
        Remove-Item -Path $progIdPath -Recurse -Force
    }

    # 6. Unregister from State Manifest
    if (Get-Command Unregister-TweakState -ErrorAction SilentlyContinue) {
        Unregister-TweakState -TweakId "context-menu.new-markdown-document"
    }

    # 7. Notify Windows Shell
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

    Write-Host "[OK] Successfully removed 'Text Document (Markdown)' from Explorer New menu." -ForegroundColor Green
}
catch {
    Write-Error "Failed to revert registry changes: $_"
    exit 1
}
