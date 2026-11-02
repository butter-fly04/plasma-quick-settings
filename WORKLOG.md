# Quick Settings plasmoid — worklog

Live summary of the project state; kept up to date by the assistant. Targets live in `TARGETS.md`.
Versions are git tags (`git tag -l 'v*'`), one point release per verified iteration.

## Current state (after v0.12.7)

- **v0.12.7** (this release): the tray is now event-driven using plasma-workspace's own
  `StatusNotifierModel` (the exact model the stock systemtray renders), the panel battery
  icon shows the charging state again, and tray icons have the stock press-bounce with a
  left-click fallback to the context menu for menu-only items.
- **v0.12.6**: toast row layout (full-width content, boxed rows, no overlap).
- **v0.12.5**: panel tray icon polish (full-size glyphs, faster polling — superseded by
  v0.12.7's event-driven model).
- **v0.12.4**: panel tray icons moved left of the applet icons, per-icon show/hide config.
- **v0.12.3**: history action close semantics.

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

- **First toast missing after a fresh session** — parked. v0.12.7 carries the stock-style
  imperative show (`visible: false`, `Connections` on `notifToastCount`, `position()` then
  `visible = true`) plus the toast toggle handler. The temporary `[QS]` probes were
  removed; the fix still needs a real-shell fresh-session test (plasmoidviewer cannot
  own `org.freedesktop.Notifications`).
- Toast duplication when the stock notifications applet is also present — verify whether
  that is still reachable / desired.

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
