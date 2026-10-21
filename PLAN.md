# Quick Settings for KDE Plasma 6: plan

Goal: one panel icon that opens a GNOME-style Quick Settings popup (sliders,
toggle tiles with expandable detail pages, media card), built as a single
Plasma 6 plasmoid.

## Why build it (research, Oct 2026)

| Project | State |
|---|---|
| Prayag2/kde_controlcentre (macOS-style) | Plasma 5 origin, last push Aug 2024, many open issues; Plasma 6 fork reported broken on 6.1 (`NightColorInhibitor is not a type`) |
| KDE Control Station (EliverLara) | Plasma 6, nice layouts, but reports of crashes on 6.3 (a fix was published) |
| Plasma Control Hub / Plasma Flex Hub (zayronxio) | Plasma 6, actively developed, but not a full tray replacement (no per-item settings links, many items missing) |
| KDE itself | No official GNOME-style quick settings; Plasma 6.5 added quick toggles to System Settings, 6.7 added background apps and a dark-mode toggle in the tray |

None cover the full list (Wi-Fi/Bluetooth detail pages, clipboard, KDE Connect,
input method, camera indicator, tray) and several depend on private QML
modules that break between Plasma releases.

## Design rules

1. All state lives in `Backend.qml`; UI files never import private KDE modules.
   When Plasma changes an API, only the backend changes.
2. Prefer stable interfaces (D-Bus: NetworkManager, UPower, BlueZ,
   power-profiles-daemon, KWin NightLight, MPRIS, PipeWire) over
   `org.kde.plasma.private.*`.
3. Every tile degrades gracefully if its service is missing.

## Milestones

- **M1: Skeleton. DONE.** Panel icon cluster, popup, tiles, sliders, detail-page navigation, resizable popup.
- **M2: Core controls. DONE (v0.2.0).** Volume and mic (`wpctl`), brightness (PowerDevil `org.kde.ScreenBrightness`, sysfs/logind fallback), battery (sysfs), lock, KDE shutdown dialog, Spectacle, System Settings, scroll-to-change-volume. All system access is in `contents/scripts/qs.sh`, run via one wrapper in `Backend.qml`.
- **M3: Network and Bluetooth. DONE (v0.3.0).** Real Wi-Fi and Bluetooth toggles; Wi-Fi page (scan, connect to saved/open/password networks, disconnect); Bluetooth page (paired devices, connect/disconnect). Uses `nmcli` and `bluetoothctl` through `qs.sh`.
- **M4: System toggles. DONE (v0.4.0).** Power profiles (powerdevil's `PowerProfilesControl` via `org.kde.plasma.private.batterymonitor`), Night Light (KWin `org.kde.KWin.NightLight` D-Bus + `kwinrc`), Dark/Light style (`plasma-apply-colorscheme`), Do Not Disturb (`org.kde.notificationmanager` Settings + Server, identical to the notifications applet), Airplane mode (`rfkill block/unblock all`, the same kernel interface Plasma's own indicator uses). Power Mode tile expands to a profile-picker detail page that mirrors the stock powerdevil batterymonitor applet (active profile, inhibition reasons, profile holds).
- **M5: Extras. DONE (v0.5.0).** Media player card (plasma-workspace's `org.kde.plasma.private.mpris` `Mpris2Model`/`PlayerContainer` — same source the stock mediacontroller applet uses), Clipboard (plasma-workspace's `org.kde.plasma.private.clipboard` `HistoryModel`/`KlipperInterface` — same source the stock clipboard applet uses), KDE Connect (`org.kde.kdeconnect.DevicesModel` from kdeconnect-kde — same source the stock KDE Connect plasmoid uses), Disks & Devices (`plasma.applet.org.kde.plasma.devicenotifier` `DeviceFilterControl` — same source the stock devicenotifier applet uses), Input Method / On-Screen Keyboard (`org.kde.plasma.workspace.keyboardlayout.KWinVirtualKeyboard` — same source the stock manage-inputmethod applet uses). Each extra is a tile in the main grid (or, for media, a card above the sliders) that opens a detail page mirroring the upstream applet's full representation.
- **M6: Camera indicator and system tray. DONE (v0.6.0).** Camera-in-use and microphone-in-use indicators in the panel — both reuse `org.kde.pipewire.monitor.Monitor.MediaMonitor` from the kpipewire repo (same source the stock cameraindicator applet uses), with `role: Camera` and `role: Communication` respectively. The panel icon slots in CompactRepresentation.qml light up automatically when the backends populate `backend.cameraInUse` / `backend.microphoneInUse`. Tray & Background Apps page: the stock systemtray is a ContainmentItem and can't be embedded, so the Tray page talks to the same public D-Bus services its private models wrap (`org.kde.StatusNotifierWatcher` for SNI items, `org.freedesktop.background.Monitor` for background apps) through `qs.sh`. Clicking a SNI calls its `Activate(0, 0)` (same as a left-click in the stock tray); the menu button calls `ContextMenu(0, 0)` (same as right-click); clicking a background app calls `OpenApp(app_id)`; the "Stop" button calls `StopApp(instance)`.
- **M7: Polish + Additions. DONE (v0.7.0).** Combines the originally-planned polish (settings page) with four feature additions requested after M6:
  - **Battery detail page** (click the battery pill): per-battery list with health/capacity and charge state (uses the same `BatteryControlModel` rows the stock batterymonitor applet uses — `PrettyName`, `Percent`, `Capacity`, `ChargeState`, `IsPowerSupply`), charge-stop-threshold hint ("charges up to ~80%"), and a "Keep Display Awake" toggle that calls `InhibitionControl.inhibit()` / `uninhibit()` — the same call the stock batterymonitor's middle-click makes.
  - **SNI pills**: any StatusNotifierItem can be promoted to a QuickTile-style pill in the main grid via the Tray page's right-click → "Pin to Quick Settings". Pinned SNIs are stored in `Plasmoid.configuration.pinnedSnis` (a StringList of "service|path" pairs). Lets the user keep IBus, Discord, Steam, etc. visible without opening the Tray page.
  - **Notifications page** (footer entry above Tray): lists recent notifications using `org.kde.notificationmanager.Notifications` — the same model the stock notifications applet uses. Shows app icon, summary, body, relative time, and action buttons. Header has a DND switch + Clear All. Marks everything read on open (same as the stock applet).
  - **Screenshot options**: the screenshot button now has left-click (uses configured default mode + backend) and right-click (popup menu with Full Screen / Rectangular Region / Window Under Cursor). Backends supported: Spectacle, grim+slurp (Wayland), Flameshot, GNOME Screenshot, maim (X11). Configurable in the Screenshot tab.
  - **Configuration page** (three tabs): Panel Icons (camera/mic/network/volume/battery/battery-percent show/hide), Popup Contents (every slider, tile, and button has its own checkbox), Screenshot (backend + default mode). Stored in `~/.config/plasma-org.kde.plasma.quicksettingsrc` via standard Plasma KConfig.

## Milestone 6 notes (the two extra items)

- **Camera indicator:** watch PipeWire for active video capture nodes
  (`pw-dump`/`pw-mon`, or the `org.kde.pipewire` QML types) and set
  `backend.cameraInUse`. The compact icon already reserves a slot for it.
- **System tray:** the tray itself is a separate Plasma applet and cannot be
  embedded. Two options: (a) host StatusNotifierItems directly via
  `org.kde.plasma.private.systemtray` models or the `org.kde.StatusNotifierWatcher`
  D-Bus service and draw them in the "Tray" page; (b) keep Plasma's tray and
  make Quick Settings a tray-aware sibling. M6 will start with (a) as a
  prototype and fall back to (b) if the model is too unstable.

## Known limits after M6

- Commands run through `org.kde.plasma.plasma5support` (executable engine), which is deprecated in Plasma 6 with no official replacement; it is isolated in `Backend.qml`.
- Audio needs PipeWire + WirePlumber (`wpctl`). State is polled (1 s open, 3 s closed), not event-driven; `pactl subscribe` could make it instant later.
- Brightness controls one display (the internal one if present). Per-monitor sliders come later.
- Wi-Fi: a network counts as "saved" only if its NetworkManager profile name equals its SSID (the default); otherwise it asks for the password again. Hidden networks and 802.1X (enterprise) networks are not handled here; the page points to Network settings for those.
- Wi-Fi password: typed into the popup, then passed to `nmcli` as a command-line argument, so it is visible to *your own user's* other processes (`ps`) for a moment. Nothing is logged or stored by the plasmoid. After a wrong password the half-created profile of that exact name is deleted so it can't fail forever as "saved".
- Bluetooth: only *paired* devices are listed; pairing new ones goes through Bluetooth settings. The list runs one `bluetoothctl info` per device (fine for a handful; a single D-Bus call would be lighter).
- Bluetooth presence is detected from `/sys/class/bluetooth/hci*`; the adapter must be visible to the kernel.
- Power Mode requires `power-profiles-daemon` to be installed and running (the same gate the stock powerdevil applet uses). When TLP is installed, the tile is dimmed and the page explains why. Inhibition reasons (lap detected, high temperature) and profile holds come straight from powerdevil's `PowerProfilesControl`, so behaviour matches the stock applet.
- Night Light talks to KWin's `org.kde.KWin.NightLight` directly. The toggle writes `kwinrc [NightColor] Active=` and calls `reconfigure()` — the same path the KCM uses, so the change is picked up identically. There is no separate "inhibit for an hour" mode here yet; only on/off.
- Dark Style pairs schemes by name ("Breeze" ↔ "Breeze Dark"). If the partner name isn't installed, the tile is disabled. Custom scheme pairs (e.g. Catppuccin variants) aren't auto-detected — set them as your active scheme and toggle will still work as long as a partner exists.
- Do Not Disturb toggles `notificationsInhibitedUntil` to "a year from now" (effectively "until turned off"), which is exactly what the notifications applet does — so the state stays in sync whether you toggle from here or from the tray. Application-initiated inhibitions are reported but not revokeable from here; turn them off from the notifications applet.
- Airplane mode uses `rfkill block/unblock all`, so it touches Wi-Fi, Bluetooth, and WWAN at once. Hard blocks (the physical switch on some laptops) are reported in the subtitle but can't be changed. After unblocking, individual radios stay off until you turn them back on with their own tiles (this is the same behaviour as Plasma's airplane-mode indicator).
- Media player card needs at least one MPRIS2-capable player running (Spotify, VLC, Elisa, Firefox with the MPRIS extension, etc.). The card follows the stock mediacontroller applet's `currentPlayer` rule (most-recently-active wins); if two players are running, pick the one you want from its own window. Seek bar appears only when the player reports a track length; some players (e.g. browser audio) don't, so it's hidden then.
- Clipboard needs klipper running (it's part of plasma-workspace, so it always is on a Plasma 6 system). Password masking follows klipper's own rule: when the clipboard currently holds a secret, the page hides all rows until the secret is cleared. Image snippets are shown with an "image" icon and their UUID; clicking them copies the image back to the clipboard.
- KDE Connect needs `kdeconnectd` running and at least one paired device. The detail page mirrors the stock KDE Connect applet's action set (Send File, Browse Files, Find My Phone); more advanced actions (SMS, remote input, virtual monitor) are reachable through "KDE Connect Settings…" rather than duplicated here.
- Disks & Devices uses the same `DeviceFilterControl` as the stock devicenotifier, so the device list, mount/unmount actions, and free-space readout are identical. Camera import, MTP browse, and Audio-CD actions come from the same per-device `Actions` list the stock applet uses; we expose mount/unmount/eject and "Open in File Manager" here, and the rest are reachable from "Removable Devices settings…".
- Input Method / On-Screen Keyboard uses KWin's `KWinVirtualKeyboard` singleton, so toggling it here has the same effect as clicking the tray icon. The three "automatic display" modes match the stock manage-inputmethod applet. Fcitx/IBus-style text input methods (kimpanel) are not separately wired yet — the page focuses on the OSK, which is what the stock applet does too.
- Camera / mic in-use indicators need `kpipewire` installed (it ships the `org.kde.pipewire.monitor` QML module). The camera backend uses `role: Camera` (matches the stock cameraindicator applet exactly). The mic backend uses `role: Communication`, which is the role VoIP/conferencing apps register with PipeWire — so it lights up for Zoom/Discord/Teams/Jitsi but not for, say, a bare `arecord`. A true "any audio capture" indicator would need a PipeWire node-type watcher; that's a future refinement.
- Tray & Background Apps talks to the public `org.kde.StatusNotifierWatcher` and `org.freedesktop.background.Monitor` D-Bus services directly (the same ones the stock systemtray's private models wrap). The stock systemtray applet itself is a `ContainmentItem` and can't be embedded, so we don't try — instead we provide a parallel view. If you also keep the stock tray in your panel, both will be live simultaneously and there's no conflict (each is read-only on the SNI list, and clicks go to the same D-Bus methods). Per-SNI context menus use the SNI's own `ContextMenu(0, 0)` method, which some legacy apps don't implement — those rows just have no menu button. Background-app instance IDs aren't fully parsed from the `a(ssa{sv})` D-Bus struct yet (the script pulls only `app_id`), so the "Stop" button stops by app_id rather than by per-instance PID; for typical single-instance flatpaks that's correct, but multi-instance apps may need a future fix.

## Design principle (from 0.3.1): reuse Plasma's own logic
Features are taken from Plasma's applets/modules and only re-skinned; each lives in
`contents/ui/backends/*.qml`, loaded through a `Loader` so a missing module disables only that feature.
- Bluetooth: `org.kde.bluezqt` + `org.kde.plasma.private.bluetooth` (BlueDevil). Presence = rfkill state, not adapter count.
- Battery: `org.kde.plasma.private.battery` BatteryControlModel (combined multi-battery percentage).
- Power Profile: `org.kde.plasma.private.batterymonitor` `PowerProfilesControl` (powerdevil) — same source the stock "Power & Battery" applet uses, so the profile list, inhibition reasons, and per-application profile holds all match.
- Do Not Disturb: `org.kde.notificationmanager` `Settings` + `Server` (plasma-workspace libnotificationmanager) — same objects the notifications applet uses, so toggling here matches the tray.
- Night Color / Dark Style / Airplane Mode: no Plasma-private QML module exists, so they go through `qs.sh` and the same stable D-Bus / CLI surface Plasma itself uses (`org.kde.KWin.NightLight`, `plasma-apply-colorscheme`, `rfkill`).
- Media Player: `org.kde.plasma.private.mpris` `Mpris2Model` (plasma-workspace libkmpris) — same model the stock mediacontroller applet uses.
- Clipboard: `org.kde.plasma.private.clipboard` `HistoryModel` + `KlipperInterface` — same source the stock clipboard applet uses.
- KDE Connect: `org.kde.kdeconnect.DevicesModel` (kdeconnect-kde) — same source the stock KDE Connect plasmoid uses.
- Disks & Devices: `plasma.applet.org.kde.plasma.devicenotifier` `DeviceFilterControl` — same source the stock devicenotifier applet uses.
- Input Method / OSK: `org.kde.plasma.workspace.keyboardlayout.KWinVirtualKeyboard` — same source the stock manage-inputmethod applet uses.
- Camera / mic indicators: `org.kde.pipewire.monitor.Monitor.MediaMonitor` (kpipewire) — same source the stock cameraindicator applet uses, with `role: Camera` and `role: Communication`.
- Tray & Background Apps: no Plasma-private QML module exists for these (the stock systemtray is a ContainmentItem); instead `qs.sh` talks to the public `org.kde.StatusNotifierWatcher` and `org.freedesktop.background.Monitor` D-Bus services that the stock tray's private models wrap.
- Still script-based, to migrate next: audio (plasma-pa), Wi-Fi (plasma-nm), brightness (powerdevil ScreenBrightness), Night Color (could use a private KWin module if one appears).
