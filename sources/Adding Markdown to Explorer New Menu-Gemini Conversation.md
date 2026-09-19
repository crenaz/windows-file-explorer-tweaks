# **Adding Markdown to Explorer New Menu**

[https://gemini.google.com/app/d781db3eaf549407](https://gemini.google.com/app/d781db3eaf549407)

&nbsp;

*User prompt: I mostly do software development on the command line for POSIX environments. I'm currently using a Windows 11 laptop and I'm wondering about the software stack needed to add an entry to this contextual menu in the Windows File Explorer. Or maybe what I'm thinking about already exists. As you can see in the screenshot, I have 'Right-clicked' in the File Explorer and selected 'New'; It then shows the options to create a New item, whether it's a folder, shortcut, archive, or a document type. I'd like to add a custom entry to this list, called: "Markdown Document" right under the entry for 'Text Document'.*

Response: You do not need to compile code or install a software stack for this. In Windows, the File Explorer **New** menu is controlled directly by the **Windows Registry** using a special subkey called ShellNew.

Because Windows sorts this submenu alphabetically based on the display name of the file type, naming it **"Markdown Document"** will naturally position it between **"Bitmap image"** and **"Microsoft Access Database"**. Windows File Explorer does not support manual reordering of items in this list, but you can register the template entry so it creates a .md file directly.

### **Method 1: Using a .reg file (Fastest)**

> 1. Open your text editor and paste the following content:

`Windows Registry Editor Version 5.00`

`[HKEY_CLASSES_ROOT\.md]`  
`@="MarkdownDocument"`  
`"Content Type"="text/markdown"`  
`"PerceivedType"="text"`

`[HKEY_CLASSES_ROOT\.md\ShellNew]`  
`"NullFile"=""`

`[HKEY_CLASSES_ROOT\MarkdownDocument]`  
`@="Markdown Document"`

`[HKEY_CLASSES_ROOT\MarkdownDocument\DefaultIcon]`  
`@="%SystemRoot%\\System32\\imageres.dll,-102"`

> 2. Save the file with the extension .reg (for example, AddMarkdownNew.reg).  
> 3. Double-click the saved .reg file and confirm the prompt to merge it into your registry.  
> 4. Right-click on your desktop or empty space in File Explorer, hover over **New**, and verify that **Markdown Document** is listed.

### **Method 2: From PowerShell (Administrator)**

If you prefer running a command directly:

`New-Item -Path "HKCR:\.md" -Force | Out-Null`  
`Set-ItemProperty -Path "HKCR:\.md" -Name "(Default)" -Value "MarkdownDocument"`  
`Set-ItemProperty -Path "HKCR:\.md" -Name "Content Type" -Value "text/markdown"`  
`Set-ItemProperty -Path "HKCR:\.md" -Name "PerceivedType" -Value "text"`

`New-Item -Path "HKCR:\.md\ShellNew" -Force | Out-Null`  
`Set-ItemProperty -Path "HKCR:\.md\ShellNew" -Name "NullFile" -Value ""`

`New-Item -Path "HKCR:\MarkdownDocument" -Force | Out-Null`  
`Set-ItemProperty -Path "HKCR:\MarkdownDocument" -Name "(Default)" -Value "Markdown Document"`

> * **Verification:** Right-click anywhere in File Explorer, open **New**, and click **Markdown Document**. A blank New Markdown Document.md should appear immediately.

*(Note: If you strictly need it to display right under "Text Document", the display name would need to start with "Text" — e.g., naming it "Text Document (Markdown)" — due to the alphabetical sorting behavior).*

---

*User prompt: If I were to save this in a repo on my Github profile, what would be a good name for the repository?*

Response: Depending on whether you plan to keep this script isolated or expand it into a broader collection of personal workstation tweaks, here are the most standard naming conventions:

**Focused (Registry & Context Menus)**

> * win-context-menu-tweaks  
> * windows-shell-extensions  
> * win-registry-snippets  
> * windows-explorer-tweaks

**Broader Scope (Dev Setup & Workstation Config)**

> * windows-dev-setup  
> * dotfiles-windows (or simply dotfiles if you include POSIX shells alongside it)  
> * win-env-setup  
> * workstation-bootstrap

If you are coming from a POSIX background and usually maintain a dotfiles repository, keeping a registry/ or windows/ subdirectory inside that existing repo is often the cleanest approach rather than maintaining a single-script repository.

---

*User prompt: I've always kept my \`dotfiles\` private and only keep a local backup of them; not actually on Github, although I have seen other developers keep theirs publicly accessible on Github. I haven't really thought about it. I'll probably use 'windows-file-explorer-tweaks' for this project, that way, it's open to other tweaks in the future.*

Response: windows-file-explorer-tweaks is a great choice. It is descriptive, instantly sets user expectations, and gives you plenty of room to add other tweaks later—like custom entries in the top-level context menu, directory shortcuts, or file association overrides.

Keeping dotfiles strictly local makes total sense, especially if they contain internal network paths, hostnames, or configurations you don't care to sanitize. A standalone, public repo like this lets you share practical system utilities without worrying about accidental credential leaks.

To keep the repository clean and modular as it grows, a straightforward structure works best:

`windows-file-explorer-tweaks/`  
`├── README.md`  
`├── registry/`  
`│   ├── add-markdown-shellnew.reg`  
`│   └── remove-markdown-shellnew.reg`  
`└── scripts/`  
&nbsp;&nbsp;&nbsp;&nbsp;`├── Add-MarkdownNew.ps1`  
&nbsp;&nbsp;&nbsp;&nbsp;`└── Remove-MarkdownNew.ps1`

Providing both the apply and revert (remove) scripts is standard etiquette for Windows registry tweaks—it makes it easy for others (and your future self on a fresh machine) to safely test and roll back changes.

---

