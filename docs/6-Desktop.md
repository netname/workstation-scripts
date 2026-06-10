> **Development Workstation** · [Overview](0-Overview.md) · [Stack](1-Stack.md) · [Installation](2-Installation.md) · [Terminal](3-Terminal.md) · [Projects](4-Projects.md) · [Editors](5-Editors.md) · **Desktop** · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

## Desktop — Connection and Tiling Reference

> [!note] **Installation is fully automated.** XFCE4, LightDM, XRDP, WezTerm, VS Code, Chrome, ksnip, and the polkit shutdown rule are all installed by `setup-desktop.sh` (Installation Step 5). This appendix covers the steps that the script cannot automate: connecting from Windows and configuring window tiling shortcuts.

> [!note] **This appendix applies to any Ubuntu machine** — VMware VM, bare metal, VirtualBox, or cloud instance. VMware Tools (see [2-Installation.md — VMware section](2-Installation.md)) improves clipboard and display behaviour if you are in a VMware VM, but it is not required for XRDP to work.

---

### L.1 Why XFCE4?

- **Lightweight** — low RAM footprint
- **XRDP-compatible** — LightDM uses Xorg by default (do not switch to Wayland — XRDP does not support it)
- **Not Xubuntu** — Xubuntu uses Arctica Greeter, which conflicts with XRDP

None of the desktop components interact with Nix, Home Manager, or your dotfiles repository. Adding or removing the desktop does not affect the development environment.

---

### L.2 Connecting from Windows via RDP

#### Single Monitor

1. Open **Remote Desktop Connection** (`mstsc`)
2. Enter the VM's IP address (from `ip addr show`)
3. Select **Xorg** as the session type
4. Log in with your Ubuntu username and password

---

#### Firewall Considerations

> [!warning] **Enabling UFW with a subnet rule can block your RDP connections.**
>
> A common pattern found in tutorials looks like this:
> ```bash
> sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp
> sudo ufw enable
> ```
> This has two problems. First, the subnet `192.168.1.0/24` is hardcoded — if your LAN uses a different range (common with ISP routers that assign `10.x.x.x` or `192.168.0.x`), the rule silently does not match and RDP connections are blocked. Second, enabling UFW on a VM that is already behind a NAT router or a corporate firewall adds a second firewall layer with no practical security benefit for a single-developer workstation.

**For a VM on a trusted private LAN (home office, dedicated dev network), the recommended approach is to leave UFW disabled.** Your router is the perimeter. The VM is not directly reachable from the internet.

If you are on a network where you cannot trust other machines on the same LAN segment — a shared office network, a conference network, a colocation environment — then enable UFW with a rule that matches your actual LAN range:

```bash
# First, find your actual LAN subnet:
ip route | grep -v default

# Then set a rule matching that subnet, allow SSH first:
sudo ufw allow OpenSSH
sudo ufw allow from <your-actual-subnet> to any port 3389 proto tcp
sudo ufw enable
```

**Verify connectivity before closing your current terminal session.** If you lose access, power-cycle the VM from the VMware console.

---

#### Connect from Windows — Single Monitor

* Open **Remote Desktop Connection** (`mstsc`)
* Enter the VM's IP address (from `ip addr show`)
* Select **Xorg** as the session type
* Log in with your Ubuntu username and password

---

#### Connect from Windows — Multiple Monitors

XRDP supports two approaches for multi-monitor setups. Choose based on how you want the session to behave.

#### Option A: Span Mode (recommended — Zero Server configuration)

Span mode sends both monitors as a single wide logical display to XRDP. The VM sees one screen whose width is the sum of your two monitors (e.g. 3840×1080 for two 1920×1080 displays). XFCE and all applications work normally within this wide canvas.

**Steps:**

1. Open **Remote Desktop Connection** and click **Show Options**
2. Go to the **Display** tab
3. Check **Use all my monitors for the remote session**
4. Connect as normal

Alternatively, save the configuration to an `.rdp` file and set it directly:

```
screen mode id:i:2
use multimon:i:1
desktopwidth:i:3840
desktopheight:i:1080
```

Replace `3840` and `1080` with the combined width and height of your monitors. Run `mstsc /l` in a Windows terminal to list your monitor numbers if you want to use only specific monitors.

> [!note] **What tiling looks like in span mode**
> With a single wide logical display, xfwm4 tiles relative to the full 3840px canvas. "Left half" places a window in the left 1920px — which happens to be your left physical monitor. "Right half" places it in the right 1920px. Halves and quarters work naturally for a two-monitor setup. If you have three or more monitors, the arithmetic becomes less convenient; consider Option B.

#### Option B: True Dual-Monitor via xrdp_dualmon (advanced)

`xrdp_dualmon` is a small open-source hook that intercepts the XRDP session startup and writes a fake Xinerama configuration file, telling Xorg there are two separate screens at the correct dimensions. Applications then maximise to one screen rather than the full combined width, and XFCE's panel spans both monitors correctly.

> [!warning] **This is an advanced option.** It requires compiling and installing a small C program and editing XRDP's session startup script. It is not officially supported by XRDP. It has been tested on Ubuntu 22.04 and 24.04 but may break on XRDP version upgrades. For most workflows, span mode (Option A) is sufficient.

```bash
# Install build dependency
sudo apt install -y build-essential libx11-dev

# Clone and build
git clone https://github.com/asafge/xrdp_dualmon.git
cd xrdp_dualmon
make

# Install the hook
sudo cp xrdp_dualmon /usr/local/bin/
sudo chmod +x /usr/local/bin/xrdp_dualmon

# Inject into XRDP's session startup — adds the call before the final exec line
sudo sed -i 's|^exec|/usr/local/bin/xrdp_dualmon\nexec|' /etc/xrdp/startwm.sh

sudo systemctl restart xrdp
```

Connect using the same `.rdp` settings as Option A. The hook fires at session start and splits the wide display into two virtual Xinerama screens automatically.

---

> [!warning] **One session at a time**
> Do not keep a local XFCE session open at the VM console while an XRDP session is also active. Both sessions fight over the same user session resources, producing display corruption and clipboard failures.

---

#### Left-Handed Mouse (Optional)

```bash
xinput set-button-map "xrdpMouse" 3 2 1
```

To persist across sessions:

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/left-handed-mouse.desktop << EOF
[Desktop Entry]
Type=Application
Name=Left-handed mouse
Exec=xinput set-button-map xrdpMouse 3 2 1
X-GNOME-Autostart-enabled=true
EOF
```

> [!tip] Use the device name `xrdpMouse` rather than a numeric ID. Device IDs are reassigned on each connection; the name is stable.

---

#### Enable Shutdown / Restart via XRDP

By default, the power-off and reboot buttons in XFCE's session menu are greyed out for XRDP sessions because polkit requires an active local console session to authorise these actions. The rule below grants the permission to sudo-group members in any active session:

```bash
sudo tee /etc/polkit-1/rules.d/85-shutdown.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.reboot") &&
        subject.isInGroup("sudo") && subject.active) {
        return polkit.Result.YES;
    }
});
EOF

sudo systemctl restart polkit
```

---

#### Recommended Reboot

```bash
sudo reboot
```

---

### L.3 Window Tiling — Keyboard Shortcuts via Xfwm4

XFCE's own window manager, xfwm4, includes full tiling support: halves (left, right, top, bottom) and quarters (all four corners). No additional software is required. Configuration is done once through the XFCE settings GUI and persists across sessions.

> [!note] **This section applies to any monitor setup.** Single monitor, dual monitor in span mode, or dual monitor via xrdp_dualmon — the tiling shortcuts work identically in all cases. The only difference is what "left half" means geometrically: on a single 1920×1080 display it occupies 960px; in span mode across two 1920×1080 monitors it occupies 1920px, which conveniently aligns with your left physical screen.

---

#### L.3.1 Enabling Drag-to-Tile (Mouse)

Before configuring keyboard shortcuts, enable the mouse drag-to-tile feature so both input methods work:

1. Open **Settings Manager** → **Window Manager Tweaks**
2. Go to the **Accessibility** tab
3. Enable **"Automatically tile windows when moving towards the screen edge"**

With this on, dragging a window to the middle third of a screen edge snaps it to a half; dragging to a corner snaps it to a quarter. This is helpful during initial exploration — you can discover the positions by mouse before relying on keyboard shortcuts exclusively.

---

#### L.3.2 Assigning Keyboard Shortcuts

xfwm4's tiling actions have no shortcuts assigned by default. Set them through:

**Settings Manager → Window Manager → Keyboard tab**

Scroll to the tiling actions and assign the following. Click an action, then press the desired key combination.

| Action | Recommended shortcut | Position |
|---|---|---|
| Tile window to the left | `Super + Left` | Left half |
| Tile window to the right | `Super + Right` | Right half |
| Tile window to the top | `Super + Up` | Top half |
| Tile window to the bottom | `Super + Down` | Bottom half |
| Tile window to the top-left | `Super + Ctrl + Left` | Top-left quarter |
| Tile window to the top-right | `Super + Ctrl + Right` | Top-right quarter |
| Tile window to the bottom-left | `Super + Shift + Left` | Bottom-left quarter |
| Tile window to the bottom-right | `Super + Shift + Right` | Bottom-right quarter |
| Maximize window | `Super + M` | Full screen |
| Restore window | `Super + R` | Back to original size |

These bindings follow the Windows 11 muscle memory pattern for halves (`Super+Arrow`) while extending it to quarters with `Ctrl` and `Shift` modifiers.

> [!tip] **Using a numpad?** xfwm4's tiling actions map spatially to the numpad layout. `KP_4` is left, `KP_6` is right, `KP_7` is top-left corner, and so on. If your keyboard has a numpad and NumLock is enabled, you can use `Super+KP_1` through `Super+KP_9` as an alternative to the arrow-key bindings above. The two sets can coexist — assign both if you switch between keyboard types.

---

#### L.3.3 The Whisker Menu Conflict

xfwm4 has a known issue: **if `Super` alone is assigned to open the Whisker menu (the application launcher), `Super+Arrow` tiling shortcuts will not fire.** The Super key is consumed on keypress for the menu binding before xfwm4 can process the combination.

Check whether you have this conflict:

```bash
xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom -l -v | grep -i super
```

If the output contains a line where `Super_L` or `Super_R` alone (without any other modifier) is mapped to `xfce4-popup-whiskermenu`, you have the conflict.

**Fix — reassign the Whisker menu to a combination:**

1. Open **Settings Manager → Keyboard → Application Shortcuts**
2. Find the `xfce4-popup-whiskermenu` entry
3. Change it from `Super` to `Super + Space` (or `Ctrl + F1` if you prefer)

Now `Super+Arrow` works as expected for tiling, and `Super+Space` opens the app launcher.

> [!note] The Super key still works as the Windows key in most application contexts (e.g. inside WezTerm and VS Code). The conflict only affects xfwm4-level shortcuts, not application-internal ones.

---

#### L.3.4 Cycling Through Sizes

xfwm4's tiling is not a one-size-per-position system. Pressing the same shortcut repeatedly **cycles the window through width presets** at that position. For example, pressing `Super+Left` once snaps the window to the left half. Pressing it again may snap it to the left third or left two-thirds, depending on your xfwm4 version and configuration.

This cycling behaviour is built in and requires no configuration. It is useful on wide displays where 50% is too wide for a reference pane — one extra keypress reduces it.

---

#### L.3.5 Backing Up the Configuration

The tiling shortcuts are stored in:

```
~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
```

To include them in your dotfiles repository:

```bash
cp ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml \
   ~/dotfiles/xfce4/xfce4-keyboard-shortcuts.xml
```

Add a corresponding entry to your dotfiles `README.md` noting that restoring this file requires either importing it through the XFCE settings editor or replacing the file while `xfconfd` is not running:

```bash
# To restore on a new machine:
pkill xfconfd
cp ~/dotfiles/xfce4/xfce4-keyboard-shortcuts.xml \
   ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
# Then log out and back in, or restart xfconfd:
/usr/lib/x86_64-linux-gnu/xfce4/xfconf/xfconfd &
```

> [!note] The bootstrap script does not restore XFCE settings — it manages the Nix/Home Manager layer only. XFCE configuration files are outside the Home Manager boundary (§1.5). Backing up `xfce4-keyboard-shortcuts.xml` in your dotfiles repo is optional but saves repeating this setup on a new machine.

---

### L.4 Desktop Setup Script Reference

The full `setup-desktop.sh` script installs XFCE4, LightDM, XRDP, Google Chrome, Noto fonts, WezTerm, VS Code, ksnip, the polkit shutdown rule, and sets WezTerm as the default terminal. It lives in your `workstation-scripts` repository and is run after the headless bootstrap:

```bash
wget -qO setup-desktop.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/setup-desktop.sh

bash setup-desktop.sh --dotfiles-dir "$HOME/dotfiles"
```

The authoritative source is `setup-desktop.sh` in your `workstation-scripts` repository. Refer to the script file for full implementation details.

### L.5 Installation Order Reference (Desktop path)

| Step | Action | How |
|---|---|---|
| — | Complete the Nix bootstrap first | Installation Steps 1–4 |
| Step 5 | XFCE4, LightDM, XRDP, WezTerm, VS Code, Chrome, ksnip, polkit | `setup-desktop.sh` (automated) |
| — | **Reboot** | Manual |
| Step 6 | Connect via RDP | §L.2 |
| Step 6 | Window tiling keyboard shortcuts | §L.3 (post-login, one time) |

> [!note] **VMware users** — install VMware Tools (§K.3) before running `setup-desktop.sh` if you have not already. VMware Tools enables clipboard sharing and display auto-resize between the VM and the XRDP session.

---

---
**Next:** [7-Troubleshooting.md — Troubleshooting](7-Troubleshooting.md)
