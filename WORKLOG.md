# Quick Settings plasmoid — worklog

Live summary of the project state; kept up to date by the assistant. Targets live in `TARGETS.md`.
Versions are git tags (`git tag -l 'v*'`), one point release per verified iteration.

## Current state (after v0.12.9)

- **v0.12.9** (this release): the stock keyboard-layout applet is available as a panel
  icon and as a pill in the popup, both individually configurable and using the stock
  `KeyboardLayout` module, display styles, flags and wheel switching.  Clicking either
  place opens the layout list as a reliable native menu (right-click too on the panel
  icon), with the current layout checked.  Panel hover feeds the layout's long name into
  the single applet-level tooltip.
- **v0.12.8**: screen toasts now use the stock architecture — one
  `NotificationPopup` window per notification, created by an `Instantiator`, stacked
  bottom-right with the stock 2 px timeout bar, hover pause and borderless dialog.
  The parked "first toast missing" bug is fixed (a fresh window per row, no shared
  pre-created dialog).
- **v0.12.7**: the tray is now event-driven using plasma-workspace's own
  `StatusNotifierModel` (the exact model the stock systemtray renders), the panel battery
  icon shows the charging state again, and tray icons have the stock press-bounce with a
  left-click fallback to the context menu for menu-only items.
- **v0.12.6**: toast row layout (full-width content, boxed rows, no overlap).
- **v0.12.5**: panel tray icon polish (full-size glyphs, faster polling — superseded by
  v0.12.7's event-driven model).
- **v0.12.4**: panel tray icons moved left of the applet icons, per-icon show/hide config.
- **v0.12.3**: history action close semantics.

### Verified working (v0.12.9)

- **Same engine as the stock applet.** `contents/ui/KeyboardLayoutIndicator.qml`
  instantiates `org.kde.plasma.workspace.keyboardlayout.KeyboardLayout` directly, uses
  `KCMKeyboard.Flags.getIcon()` for the artwork and `WorkspaceComponents.BadgeOverlay`
  for display style 2. No layout logic is re-implemented.
- **Panel icon and popup pill.** `CompactRepresentation.qml` renders a bare square icon
  at the same size as the other panel glyphs; `FullRepresentation.qml` renders a rounded
  pill next to the battery pill. Each placement has its own show/hide setting, and the
  display style is shared.
- **Stock face and wheel.** Display styles 0/1/2 match the stock applet (name, flag,
  flag with name badge). The wheel uses the stock accumulator logic to switch to the
  previous/next layout.
- **Native layout menu.** Clicking the panel icon (left or right) or the pill opens
  `PlasmaExtras.Menu` — a native `QMenuProxy`, like the tray menus in `SniMenu.qml`,
  rather than a QQC2 menu that the panel/popup would paint over. It lists every layout
  with its flag and long name, checks the current one, switches on selection, opens on
  the screen-facing side of the panel, and closes on any outside click.
- **One tooltip in the panel.** The panel indicator has no tooltip of its own; hovering
  sets `Backend.panelHoverKeyboardLayout`, so the shell-positioned applet tooltip shows
  the layout long name instead of the Quick Settings summary. The popup pill keeps its
  own tooltip because there is no applet tooltip there.
- **Configuration.** New "Keyboard Layout" tab: show in panel, show in popup, display
  style. Defaults are on/on/0.

### Verified working (v0.12.8)

- **First toast appears immediately.** `contents/ui/NotificationToast.qml` is now an
  `Instantiator` that creates a fresh `NotificationPopup` window per popup-model row
  (stock `global/Globals.qml` architecture). There is no shared, invisibly pre-created
  dialog whose first show could race the window expose. Verified by the user in a real
  shell.
- **One popup per notification.** Each row is its own `PlasmaCore.Dialog` with
  `type: Notification` / `CriticalNotification` (KWin notification layer on Wayland,
  `NET::Notification` on X11), borderless, `WindowDoesNotAcceptFocus`.
- **Bottom-right stacking.** Popups sit at the applet screen's bottom-right
  (`Plasmoid.screenGeometry + Plasmoid.availableScreenRect`), oldest nearest the corner,
  newer ones stacked upwards; beyond 20 % remaining screen fill only the oldest stays
  visible (stock `popupMaximumScreenFill`).
- **Stock timeout bar + hover pause.** The 2 px `highlightColor` bar hugs the top edge
  and shrinks over the notification's timeout. Hovering pauses both the bar and the
  expiry timer; leaving restarts the countdown (same as stock's timer). Critical
  notifications use the left accent bar instead. The popup stops the model timeout on
  creation and restarts it on destruction, like stock.
- **Stock popup content.** App icon + application/origin in the header, relative age,
  configure/minimize/close buttons, summary (hidden when identical to the app name, like
  stock), rich-text body with theme link colour, notification artwork, action buttons,
  left-click default action and middle-click close.
- **Popups off.** With `showNotificationPopups` disabled, new rows are expired
  immediately so they do not accumulate.

### Verified working (v0.12.7)

- **Instant tray updates.** `contents/ui/backends/TrayModelBackend.qml` instantiates
  `org.kde.plasma.private.systemtray`'s `StatusNotifierModel` and flattens it into the
  `{title, icon, tooltip, isMenu, service, path}` array the applet already used.
  `NewIcon`/`NewTitle`/`NewStatus`/`NewToolTip` are pushed by `StatusNotifierItemHost`,
  so panel icons, SNI pills and the Tray page repaint at stock latency. No poll timer,
  no subprocesses, no cache file. Verified end-to-end with an instrumented applet.
- **Battery charging icon.** `BatteryBackend` already selected `battery-*-charging`, but
  both panel and popup rendered it with `isMask: true`, flattening Breeze's coloured
  charging bolt. Both now use plain `Kirigami.Icon`, like stock `BatteryIcon.qml`.
- **Stock click bounce.** Panel tray icons scale to 0.8 while pressed with
  `OutCubic`/`InCubic` `Behavior` (stock `AbstractItem.qml`); Tray page rows and SNI
  pills bounce too.
- **Left-click fallback.** Menu-only items (`ItemIsMenu`) open their menu on left click,
  like stock's `ItemIsMenu ? openContextMenu : activate`. If `Activate` itself fails on
  D-Bus, `Backend.trayActivate` also falls back to the context menu.
- **Daemon retired.** The resident `tray-watch-daemon.py` and the `file://` XHR/mode
  ladder were removed; background apps (not exported to QML by plasma-workspace) use a
  new lightweight `qs.sh bgpoll` on a slow timer (5 s popup / 30 s idle).
- **Safety net kept.** If the private tray module cannot be loaded, `TrayBackend.qml`
  falls back to the old `qs.sh traypoll` path automatically.

### In progress / next

- Toast duplication when the stock notifications applet is also present — verify whether
  that is still reachable / desired. This applet assumes plasma-workspace ships without
  `org.kde.plasma.notifications` (as on this system).

## Key learnings (keep for future iterations)

- **Deploy**: `rsync -a --checksum` silently skips files on this box — always deploy
  `cp -r contents/. <target>/contents/` + `cp metadata.json` + `diff -r` → `SYNC-OK`.
- **QML `XMLHttpRequest` on `file://` is unusable on this Qt 6.7 build**: `send()`
  succeeds but `readyState` never reaches 4 (no error, no callback). Verified with an
  instrumented applet. Do not build data paths on local-file XHR.
- **`StatusNotifierModel` is exported to QML** by plasma-workspace for plasma-mobile
  (`QML_ELEMENT`, default constructor). It is the stock event-driven SNI list and works
  inside a normal applet. Roles used: `Title`, `ToolTipTitle`, `ToolTipSubTitle`,
  `Icon`, `IconName`, `ItemIsMenu`, `Status`, `DataEngineSource` ("service/path").
- **Never read `effectiveStatus`** from a default-constructed `StatusNotifierModel`:
  `BaseModel::calculateEffectiveStatus` dereferences the optional `SystemTraySettings`,
  which is null for the QML-exported constructor → segfault. `status` is safe.
- **Pixmap SNIs**: `model.Icon` returns a `QIcon`; pass it straight to `Kirigami.Icon.source`
  (QVariant) like stock does. Theme icons arrive as `IconName`. Prefer `Icon || IconName`.
- **Battery icons must not be masked**: Breeze's `-charging` variants encode the bolt in
  `ColorScheme-PositiveText`; `isMask: true` collapses it to the same white as the body.
- **Click bounce**: scale the icon container to 0.8 while pressed with
  `Behavior { NumberAnimation { duration: longDuration; easing OutCubic/InCubic } }`.
- **plasmoidviewer limitations**: never owns `org.freedesktop.Notifications`
  (plasmashell owns the name → PopupNotifications model always count=0 there).
  QML `console.log` is swallowed; to debug an applet under plasmoidviewer, log through a
  `Plasma5Support.DataSource` (`engine: "executable"`) to a file.
- **Notification plumbing**: `Server::self()`/`NotificationsModel` is per-process;
  inside real plasmashell the applet shares the process with the service owner —
  toasts MUST be tested in real plasmashell (user restart of the shell).
- **PlasmaCore.Dialog** default property is `mainItem: Item` — `Connections` cannot be a
  direct child; duplicate `onXxxChanged` = "Property value set multiple times" load error.
  `Timer`/`NumberAnimation` must live inside `mainItem`.
- **Never add `Qt.WindowStaysOnTopHint` to a notification `PlasmaCore.Dialog`**: the
  dialog's `applyType()` rewrites the type to `Dock` (panel role, "windows go below") for
  any non-AppletPopup/Tooltip dialog with that flag, overriding `Notification` /
  `CriticalNotification`. Use `flags: Qt.WindowDoesNotAcceptFocus` only (the `flags`
  writer ORs in `FramelessWindowHint`).
- **One window per toast**: stock uses an `Instantiator` over the popup model, not one
  shared dialog. Instantiator's delegate gets `index`/`model` even with
  `required property` declarations; a hidden window's `width`/`height` stay 0 until the
  first show, so position with `popup.mainItem.width/height` as the fallback.
- **Wayland placement needs the real shell**: `plasmoidviewer` has no plasma-shell
  integration, so `PlasmaCore.Dialog.x/y` snap back to 0 (a plain `Window` probe does the
  same). The position is stored and applied by `PlasmaShellWaylandIntegration` only in a
  real plasmashell session.
- **Missing `import org.kde.plasma.plasmoid`** breaks any file referencing `Plasmoid.*`
  (bit twice: DND switch, NotificationToast).
- **busctl gotchas**: newline titles arrive as literal `\n` (use `first_line()`), pixmap
  icons need the ARGB32→PNG converter with crc-named cache (`sni_pixmap_icon` in qs.sh).
- QML sanity check: python brace-balance + `sh -n` for qs.sh before every deploy.

## Test harnesses

- Applet-under-plasmoidviewer probe: log via `Plasma5Support.DataSource` to
  `/tmp/opencode/probe.log`; useful for model/component loading checks.
- Test notification with actions: `python3 /tmp/opencode/actnotify.py` (dbus, non-blocking).
- Screenshot: `spectacle -b -n -o file.png`.
