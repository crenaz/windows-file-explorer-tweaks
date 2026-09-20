# New Markdown Document Tweak

Adds a **Markdown Document** template entry to the Windows File Explorer right-click **New** context menu, allowing you to instantly create blank `.md` files.

## Menu Placement

In Windows 11, File Explorer sorts items in the **New** submenu alphabetically by file extension (`.md`), positioning it cleanly between `.docx` (Microsoft Word) and `.odg` (OpenDocument Drawing).

## Files

| File | Purpose | Delivery Method |
| :--- | :--- | :--- |
| `apply.reg` | Imports registry keys into `HKEY_CLASSES_ROOT` | Double-click / Registry Editor |
| `revert.reg` | Deletes `ShellNew` and custom ProgID keys | Double-click / Registry Editor |
| `Apply.ps1` | Creates registry keys with elevation check & shell notification | PowerShell (Administrator) |
| `Revert.ps1` | Removes registry keys and refreshes shell icon/association cache | PowerShell (Administrator) |

## Quick Start

### Option A: Registry Files
1. Double-click `apply.reg` and accept the UAC prompt to merge the changes.
2. To uninstall, double-click `revert.reg`.

### Option B: PowerShell
Run PowerShell as Administrator (or let the script auto-elevate):
```powershell
powershell -ExecutionPolicy Bypass -File .\Apply.ps1
```
To revert:
```powershell
powershell -ExecutionPolicy Bypass -File .\Revert.ps1
```

> **Note**: Both PowerShell scripts trigger Windows Shell change notification (`SHCNE_ASSOCCHANGED`) so changes take effect immediately without needing to log out or reboot.
