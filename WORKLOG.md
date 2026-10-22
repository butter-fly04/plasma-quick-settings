# Quick Settings plasmoid — worklog

Live summary of the project state; kept up to date by the assistant. Targets live in `TARGETS.md`.
Versions are git tags (`git tag -l 'v*'`), one point release per verified iteration.

## Current state (after v0.12.3, working tree beyond)

- **v0.12.3** (`6d71ae9`) is the last tagged release: toasts working (2nd notification),
  tray poll fixed, history action close semantics fixed.
- Working tree (uncommitted) contains the M12.2 polish round — deployed locally, verified by user where noted:

### Verified working
- Toasts appear again after the layout deadlock fix (`stackHeight` reserved height in `NotificationToast.qml`);
  the *first* notification still doesn't show — parked, see targets.
- Per-app panel tray icons moved LEFT of the applet icons, slightly larger (1.15 × iconSize).
- Applet tooltip suppressed while hovering a panel tray icon (SNI title/tooltip takes over —
  `Backend.setPanelSniHover/clearPanelSniHover` + `main.qml` bindings).
- Per-icon config plumbing: `Backend.applyTrayPoll` writes a `panelTrayIconList` snapshot
  ("service|path|title" entries) into the configuration; KCM pages can read it via
  `cfg_panelTrayIconList` (verified in journal: the pages DO receive the list).
- Per-icon checkboxes moved to the **Panel icons** config tab (was accidentally in
  "Popup contents" — that's why they "didn't appear" first).

### In progress / next
- Remove the fallback bell icon from toast rows (done in tree: icon hidden when
  the notification provides none) — verify with user.
- Per-icon checkbox UI — verify with user after the page move.
- First-notification toast missing — deadlock analysis: an invisible
  PlasmaCore.Dialog never runs layout polish; current approach reserves a fixed minimum
  stack height (12px-ish) so the "trying to show an empty dialog" refusal can't trigger;
  first toast still misses for the user, root cause not yet isolated. Parked at user request.

## Key learnings (keep for future iterations)

- **Deploy**: `rsync -a --checksum` silently skips files on this box — always deploy
  `cp -r contents/. <target>/contents/` + `cp metadata.json` + `diff -r` → `SYNC-OK`.
- **plasmoidviewer limitations**: never owns `org.freedesktop.Notifications`
  (plasmashell owns the name → PopupNotifications model always count=0 there).
  Fake-model harness (`/tmp/opencode/toastpreview-main.qml` → snitest `contents/ui/main.qml`)
  renders the toast dialog but plasmoidviewer draws dialogs unreliably (empty squares).
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

- `/tmp/opencode/snitest/` applet copy + `harness-main.qml` (pills) /
  `toastpreview-main.qml` (fake toast backend).
- Test notification with actions: `python3 /tmp/opencode/actnotify.py` (dbus, non-blocking).
- Screenshot: `spectacle -b -n -o file.png`.
