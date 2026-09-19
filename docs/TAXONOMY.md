# Repository Taxonomy & Architectural Guidelines

This document defines the structural taxonomy, scope boundaries, and safety standards for the `windows-file-explorer-tweaks` repository. All past, present, and future tweaks must adhere to these guidelines to ensure safety, modularity, and clean rollbacks.

---

## 1. Scope Boundaries: In-Scope vs. Out-of-Scope

To keep the repository focused, reliable, and maintainable, tweaks must strictly adhere to the following scope boundary:

> **Core Rule**: If a tweak does not directly affect how Windows File Explorer (its context menus, tree view, or directory display) looks, navigates, or performs, it is **out of scope**.

| In-Scope (File Explorer Ecosystem) | Out-of-Scope (Belongs in Separate Repos) |
| :--- | :--- |
| **Context Menus**: ShellNew templates, classic menu toggles, context actions | **System Debloat**: Uninstalling Edge, OneDrive app, Cortana |
| **Navigation Pane**: Show/hide Gallery, Network, Home, custom CLSID pins | **Taskbar & Start Menu**: Centering icons, Start layout, Copilot |
| **Folder Views**: Disabling auto-discovery sniffing, details view, BagMRU resets | **Deep OS Hacks**: Patching system DLLs, kernel tweaks, telemetry blocking |
| **Explorer Behavior**: File extensions, hidden files, compact layout, startup target | **Services & Daemons**: Disabling Windows services or background tasks |

---

## 2. Domain Classification

Tweaks are organized into dedicated domain directories based on which subsystem of Windows File Explorer they target:

```
windows-file-explorer-tweaks/
├── context-menu/          # Context menu customizations (ShellNew, context actions, classic menu)
├── navigation-pane/       # Sidebar customizations (Gallery, Home/Quick Access, Network, CLSID pins)
├── folder-views/          # Folder templates, view caching (BagMRU), and column presets
├── explorer-behavior/     # Global Explorer flags (extensions, hidden files, compact mode, startup target)
├── docs/                  # Architecture, taxonomy, and safety documentation
├── tools/                 # Shared safety engine (TweakEngine.psm1)
├── registry/              # Root-level shortcuts / legacy flat registry scripts
└── scripts/               # Root-level shortcuts / legacy flat PowerShell scripts
```

### Domain Descriptions

| Domain | Scope & Examples |
| :--- | :--- |
| **`context-menu/`** | Customizations modifying right-click menus: adding `ShellNew` templates (e.g., Markdown, JSON), toggling Windows 11 classic vs modern menu, custom commands ("Open in VS Code"). |
| **`navigation-pane/`** | Customizations controlling items pinned to the left-hand Explorer tree: showing/hiding the Windows 11 Gallery icon, toggling Network, Home, or This PC items. |
| **`folder-views/`** | Optimizations and resets for folder display: preventing Windows from erroneously sniffing dev folders as "Pictures/Music", forcing default "Details" view, clearing corrupted `BagMRU` view cache. |
| **`explorer-behavior/`** | General settings: displaying file extensions (`HideFileExt=0`), showing system hidden files, compact item spacing, and defaulting startup view to "This PC". |

---

## 3. The "Twin Contract" Standard

Every tweak added to this repository must honor the **Twin Contract**: for every action applied to the system, a corresponding, fully tested revert action must exist.

### Required Artifacts Per Tweak Folder

Each tweak resides in its own self-contained subfolder under its domain (e.g. `context-menu/new-markdown-document/`) and must contain:

```
<domain>/<tweak-name>/
├── apply.reg       # Pure Windows Registry import to apply the tweak
├── revert.reg      # Pure Windows Registry script to cleanly undo the tweak
├── Apply.ps1       # Elevated PowerShell script with pre-flight backup & shell refresh
├── Revert.ps1      # Elevated PowerShell script to undo changes and restore state
└── README.md       # Tweak documentation (registry keys touched, screenshots, usage)
```

### Dual Delivery Philosophy
1. **`.reg` Files (Minimalist & Portable)**:
   - For users who prefer double-click registry imports without running scripts.
   - Must contain only standard Windows Registry Editor syntax.
2. **`PowerShell` Scripts (Intelligent & Automated)**:
   - Self-elevates if run from an unprivileged console.
   - Automatically exports targeted pre-flight backups to `.backups/*.reg` before writing.
   - Registers state in `.state/manifest.json`.
   - Calls the Windows Shell API (`SHChangeNotify`) to immediately broadcast changes across all running Explorer windows, avoiding reboot requirements.

---

## 4. Registry Safety & Rollback Principles

### A. Non-Destructive Targeting
- **Never wipe shared parent keys**:
  - `[-HKEY_CLASSES_ROOT\.md]` is forbidden because it destroys third-party file associations, content types, and application registrations.
  - Instead, use targeted deletion: `[-HKEY_CLASSES_ROOT\.md\ShellNew]`.
- Always verify that removing a tweak leaves the system in a clean, working default state.

### B. User-Scope (`HKCU`) Preference
- Whenever possible, target `HKEY_CURRENT_USER\Software\...` rather than `HKEY_LOCAL_MACHINE`.
- HKCU requires no administrative privileges and isolates tweaks to the active user profile.

### C. Idempotency
- Applying a tweak twice must produce the exact same clean state as applying it once.
- Reverting a tweak when it has not been applied must succeed without throwing errors.

### D. Live Refresh
- Shell tweaks must trigger shell updates whenever possible (`SHCNE_ASSOCCHANGED`).

---

## 5. Checklist for Adding a New Tweak

When creating a new tweak:
1. Verify the tweak is **in-scope** for File Explorer.
2. Identify the appropriate domain directory (`context-menu/`, `navigation-pane/`, etc.).
3. Create a descriptive, lowercase, kebab-case directory name (e.g., `hide-gallery/`).
4. Author `apply.reg` and `revert.reg`.
5. Author `Apply.ps1` and `Revert.ps1` utilizing `tools/TweakEngine.psm1` for automated backup and shell notification (with inline fallbacks for standalone execution).
6. Create `README.md` documenting keys modified and behavior changes.
7. Verify both apply and revert operations on a clean session.
