<#
.SYNOPSIS
    Shared Safety and Utility Module for Windows File Explorer Tweaks.

.DESCRIPTION
    Provides automated pre-flight registry backups using native reg.exe export,
    state manifest management (.state/manifest.json), administrative privilege checks,
    and Windows Shell notification (SHChangeNotify).
#>

function Get-RepoRoot {
    <#
    .SYNOPSIS
        Resolves the root directory of the windows-file-explorer-tweaks repository.
    #>
    [CmdletBinding()]
    param()
    
    $current = $PSScriptRoot
    while ($current -and -not (Test-Path (Join-Path $current "docs\TAXONOMY.md"))) {
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
    if ($current -and (Test-Path (Join-Path $current "docs\TAXONOMY.md"))) {
        return $current
    }
    return (Get-Location).Path
}

function Confirm-AdminPrivilege {
    <#
    .SYNOPSIS
        Verifies administrator privileges and attempts self-elevation if unprivileged.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [string]$ArgumentString = ""
    )

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "[!] Administrator privileges required. Attempting elevation..." -ForegroundColor Yellow
        try {
            $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
            if ($ArgumentString) { $argList += " $ArgumentString" }
            Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
            exit 0
        }
        catch {
            Write-Error "Failed to elevate process. Please launch PowerShell as Administrator."
            exit 1
        }
    }
}

function Convert-ToNativeRegPath {
    <#
    .SYNOPSIS
        Converts PowerShell registry paths to native reg.exe paths (e.g. HKCR\..., HKCU\...).
    #>
    [CmdletBinding()]
    param([string]$Path)

    $clean = $Path -replace '^Registry::', ''
    $clean = $clean -replace '^HKEY_CLASSES_ROOT\\?', 'HKCR\'
    $clean = $clean -replace '^HKCR:\\?', 'HKCR\'
    $clean = $clean -replace '^HKEY_CURRENT_USER\\?', 'HKCU\'
    $clean = $clean -replace '^HKCU:\\?', 'HKCU\'
    $clean = $clean -replace '^HKEY_LOCAL_MACHINE\\?', 'HKLM\'
    $clean = $clean -replace '^HKLM:\\?', 'HKLM\'
    return $clean.TrimEnd('\')
}

function Convert-ToPSRegPath {
    <#
    .SYNOPSIS
        Converts any registry path format to a valid PowerShell PSDrive path.
    #>
    [CmdletBinding()]
    param([string]$Path)

    if ($Path -match '^Registry::') { return $Path }
    if ($Path -match '^(HKCU|HKLM|HKCR):') { return $Path }
    if ($Path -match '^HKEY_') { return "Registry::$Path" }
    if ($Path -match '^(HKCR|HKCU|HKLM)\\(.*)$') {
        return "$($Matches[1]):\$($Matches[2])"
    }
    return "Registry::$Path"
}

function Backup-RegistryKey {
    <#
    .SYNOPSIS
        Performs an automated pre-flight backup of a registry key using reg.exe export.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistryKey,

        [Parameter(Mandatory = $true)]
        [string]$TweakName,

        [string]$BackupDir = ""
    )

    if (-not $BackupDir) {
        $repoRoot = Get-RepoRoot
        $BackupDir = Join-Path $repoRoot ".backups"
    }

    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }

    $nativeKey = Convert-ToNativeRegPath $RegistryKey
    $psPath = Convert-ToPSRegPath $RegistryKey
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $sanitizedKey = ($nativeKey -replace '[\/\\:]', '_').Trim('_')
    $backupFileName = "${timestamp}_${TweakName}_${sanitizedKey}.reg"
    $backupFilePath = Join-Path $BackupDir $backupFileName

    # Check if the registry key exists before attempting export
    $keyExists = $false
    try {
        if (Test-Path -Path $psPath) {
            $keyExists = $true
        }
    } catch {
        $keyExists = $false
    }

    if ($keyExists) {
        if ($PSCmdlet.ShouldProcess($nativeKey, "Pre-flight registry export to $backupFileName")) {
            Write-Host "    [Safety] Backing up existing key '$nativeKey'..." -ForegroundColor DarkGray
            & reg.exe export "$nativeKey" "$backupFilePath" /y 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [Safety] Backup saved: $backupFileName" -ForegroundColor Gray
                return $backupFilePath
            } else {
                Write-Warning "Could not export '$nativeKey'. The key may be restricted or empty."
            }
        }
    } else {
        Write-Host "    [Safety] Key '$nativeKey' does not currently exist. Rollback will safely delete it." -ForegroundColor DarkGray
    }

    return $null
}

function Register-TweakState {
    <#
    .SYNOPSIS
        Records an applied tweak in the .state/manifest.json file.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakId,

        [Parameter(Mandatory = $true)]
        [string]$TweakName,

        [string[]]$ModifiedKeys = @(),
        [string[]]$BackupFiles = @(),
        [string]$StateDir = ""
    )

    if (-not $StateDir) {
        $repoRoot = Get-RepoRoot
        $StateDir = Join-Path $repoRoot ".state"
    }

    if (-not (Test-Path $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    }

    $manifestPath = Join-Path $StateDir "manifest.json"
    $manifest = @{ appliedTweaks = @() }

    if (Test-Path $manifestPath) {
        try {
            $content = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
            if ($content.appliedTweaks) {
                $manifest.appliedTweaks = [System.Collections.ArrayList]@($content.appliedTweaks)
            }
        } catch {
            Write-Warning "Could not parse existing manifest. Creating a new one."
        }
    }

    # Filter out any prior entry for this tweak ID
    $filtered = @()
    foreach ($entry in $manifest.appliedTweaks) {
        if ($entry.id -ne $TweakId) { $filtered += $entry }
    }

    $newEntry = [ordered]@{
        id           = $TweakId
        name         = $TweakName
        appliedAt    = (Get-Date).ToString("o")
        modifiedKeys = $ModifiedKeys
        backupFiles  = $BackupFiles
    }
    $filtered += $newEntry

    $manifest.appliedTweaks = $filtered

    if ($PSCmdlet.ShouldProcess($manifestPath, "Update applied tweaks manifest")) {
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
        Write-Host "    [Safety] State registered in .state/manifest.json" -ForegroundColor DarkGray
    }
}

function Unregister-TweakState {
    <#
    .SYNOPSIS
        Removes an uninstalled tweak from the .state/manifest.json file.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakId,

        [string]$StateDir = ""
    )

    if (-not $StateDir) {
        $repoRoot = Get-RepoRoot
        $StateDir = Join-Path $repoRoot ".state"
    }

    $manifestPath = Join-Path $StateDir "manifest.json"
    if (Test-Path $manifestPath) {
        try {
            $content = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
            if ($content.appliedTweaks) {
                $filtered = @()
                foreach ($entry in $content.appliedTweaks) {
                    if ($entry.id -ne $TweakId) { $filtered += $entry }
                }
                if ($PSCmdlet.ShouldProcess($manifestPath, "Unregister tweak $TweakId from manifest")) {
                    @{ appliedTweaks = $filtered } | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
                    Write-Host "    [Safety] Tweak removed from .state/manifest.json" -ForegroundColor DarkGray
                }
            }
        } catch {
            Write-Warning "Could not update manifest during rollback: $_"
        }
    }
}

function Invoke-ShellRefresh {
    <#
    .SYNOPSIS
        Broadcasts SHCNE_ASSOCCHANGED to the Windows Shell and optionally restarts explorer.exe.
    #>
    [CmdletBinding()]
    param(
        [switch]$RestartExplorer
    )

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

Export-ModuleMember -Function Get-RepoRoot, Confirm-AdminPrivilege, Backup-RegistryKey, Register-TweakState, Unregister-TweakState, Invoke-ShellRefresh, Convert-ToNativeRegPath, Convert-ToPSRegPath
