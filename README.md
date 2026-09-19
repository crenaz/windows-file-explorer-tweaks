# Windows File Explorer Tweaks

A modular, non-destructive collection of Windows File Explorer customizations, context menu additions, navigation-pane tweaks, and view optimizations for Windows 11 and Windows 10.

---

## Featured Tweak: "Text Document (Markdown)" in New Menu

Adds a blank Markdown (`.md`) template to the File Explorer right-click **New** menu.

### Why "Text Document (Markdown)"?
Windows File Explorer sorts items in the **New** submenu alphabetically based on their display name.
- If named *"Markdown Document"*, Windows places it between *"Bitmap image"* and *"Microsoft Access Database"*.
- By naming it **"Text Document (Markdown)"**, the item naturally groups directly adjacent to Windows' native **"Text Document"** under the `T` section.

---

## Quick Start

You can apply tweaks either via direct `.reg` imports or via PowerShell scripts.

### Method 1: Using Registry Files (Double-Click)
1. Navigate to [`registry/`](./registry/) (or [`context-menu/new-markdown-document/`](./context-menu/new-markdown-document/)).
2. Double-click [`add-markdown-shellnew.reg`](./registry/add-markdown-shellnew.reg) and confirm the User Account Control (UAC) prompt to merge into the registry.
3. **To uninstall**: Double-click [`remove-markdown-shellnew.reg`](./registry/remove-markdown-shellnew.reg).

### Method 2: Using PowerShell (Automated with Live Refresh & Safety Backups)
Open PowerShell (Administrator) and run:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Add-MarkdownNew.ps1
```
To revert:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Remove-MarkdownNew.ps1
```

> **Safety Pre-Flight**: The PowerShell script automatically exports a timestamped `.reg` backup of targeted registry keys to `.backups/` before making any changes.
> **Live Refresh**: Calls Windows Shell API (`SHChangeNotify`), updating Explorer's context menu immediately without needing to log out or reboot.

---

## Repository Structure & Modular Taxonomy

This repository follows a domain-driven modular taxonomy designed to scale cleanly as new tweaks are added. Every tweak honors the **Twin Contract** (always paired with a clean rollback).

```
windows-file-explorer-tweaks/
├── README.md                                  # Repository overview and quick start
├── docs/
│   ├── TAXONOMY.md                            # Architectural guidelines & Twin Contract rules
│   └── SAFETY.md                              # Safety standards & emergency recovery guide
│
├── tools/
│   └── TweakEngine.psm1                       # Automated backups, state manifest, & shell refresh
│
├── context-menu/                              # Right-click context menu tweaks
│   ├── README.md
│   └── new-markdown-document/                 # Markdown ShellNew template
│       ├── apply.reg                          # Registry apply script
│       ├── revert.reg                         # Registry rollback script
│       ├── Apply.ps1                          # PowerShell apply script
│       ├── Revert.ps1                         # PowerShell rollback script
│       └── README.md                          # Tweak-specific details
│
├── navigation-pane/                           # Sidebar & tree customizations
│   └── README.md
│
├── folder-views/                              # Folder templates & view cache optimizations
│   └── README.md
│
├── explorer-behavior/                         # General Explorer settings & flags
│   └── README.md
│
├── registry/                                  # Flat registry shortcuts
│   ├── add-markdown-shellnew.reg
│   └── remove-markdown-shellnew.reg
│
├── scripts/                                   # Flat PowerShell shortcuts
│   ├── Add-MarkdownNew.ps1
│   └── Remove-MarkdownNew.ps1
│
└── sources/                                   # Notes, references, and screenshots
```

For complete taxonomy standards, see [TAXONOMY.md](./docs/TAXONOMY.md).
For emergency recovery procedures, see [SAFETY.md](./docs/SAFETY.md).

---

## Safety & Non-Destructive Rollback Guarantee

- **Automated Pre-Flight Backups**: Before modifying any key, scripts automatically export the pre-existing state to `.backups/YYYYMMDD_HHMMSS_<tweak>.reg`.
- **Targeted Operations**: Rollback scripts only remove the specific subkeys and values introduced by each tweak (e.g. `HKCR\.md\ShellNew`).
- **File Association Integrity**: Modifying or removing the `ShellNew` template does not erase your default app associations (such as VS Code or Sublime Text) or delete standard `.md` handlers.
- **Idempotent**: All scripts can be safely run multiple times without causing duplicate entries or registry corruption.
- **State Manifest**: Applied tweaks are recorded in `.state/manifest.json` for full system auditability.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
