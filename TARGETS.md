# Quick Settings plasmoid — targets

What the user asked for; strikethrough = done and verified (or user explicitly parked it).

## Milestone 12 (system tray + notifications)

1. ~~Toast notifications (no stock notifications applet on this system) — v0.12.0/0.12.1~~
2. ~~Per-app panel tray icons with activate/context-menu — v0.12.0~~
3. ~~Toast dialog load fixes (Connections child / Plasmoid import) — v0.12.1~~
4. ~~Tray poll keeps running for panel icons when popup closes — v0.12.2~~
5. ~~History action button semantics (InvokeBehavior.Close) — v0.12.3~~

## M12.2 polish round (user request, Oct 22)

- ~~Toast UI restyle: dark disc behind bell, spacing~~ — v0.12.6: full-width
  content (plain-Item mainItem with explicit sizing), boxed rows, no overlap.
- ~~No fallback bell icon~~ — v0.12.4, verified.
- ~~First toast missing after a fresh session~~ — v0.12.8: per-notification
  `Instantiator` + fresh `NotificationPopup` windows (stock Globals.qml architecture),
  verified by the user in a real shell.
- ~~Toast UI: stock popup clone~~ — v0.12.8: one borderless window per notification,
  bottom-right, header/summary/body/actions, 2 px shrinking timeout bar, hover pause,
  critical accent bar, left-click default action + middle-click close.
- ~~Panel tray icons left of the applet icons~~ — done & verified.
- ~~Panel tray icons slightly larger~~ — superseded: v0.12.5 renders them at
  exactly the unified size, artwork fills the tile, no padding/hover ring.
- ~~Tooltip switch when hovering tray icons~~ — final form (v0.12.5): the
  shell-positioned plasmoid tooltip shows title + app tooltip.
- ~~Per-icon show/hide config~~ — done & verified (v0.12.4, Panel icons tab).
- ~~Tray icon update latency~~ — v0.12.7: event-driven `StatusNotifierModel`,
  stock latency, no polling (supersedes the v0.12.5 400 ms poll).
- ~~Small gap between tray icons and unified icons~~ — user-tuned, v0.12.5.

## M12.3 tray fidelity (user request, Nov 2)

- ~~Instant tray icon updates~~ — v0.12.7: live `StatusNotifierModel` bridge,
  verified by user.
- ~~Battery panel icon shows charging state~~ — v0.12.7: un-masked battery icon
  (Breeze's coloured charging bolt), verified by user.
- ~~Stock press-bounce on tray icons~~ — v0.12.7: scale 0.8 on press with
  OutCubic/InCubic, panel icons + Tray page rows + SNI pills, verified by user.
- ~~Left click on menu-only tray items opens the menu~~ — v0.12.7:
  `ItemIsMenu` fallback plus D-Bus `Activate` failure fallback, verified by user.
- ~~Retire the tray watch daemon~~ — v0.12.7: daemon + `file://` XHR ladder
  removed; background apps use `qs.sh bgpoll` (5 s popup / 30 s idle).

## M12.4 keyboard layout (user request, Nov 3)

- ~~Keyboard layout as a popup pill and a separate panel icon, individually
  configurable, reusing the stock applet's `KeyboardLayout` module and display
  styles~~ — v0.12.9.
- ~~Clicking opens the layout list; the wheel switches layouts~~ — v0.12.9.
- ~~Panel icon behaves like a tray entry: one layout-name tooltip, both left and
  right click open the layout list~~ — v0.12.9.
- ~~Native layout menu: full height, stacks above the panel/popup, closes when
  clicking outside it~~ — v0.12.9 (native `PlasmaExtras.Menu`, same mechanism as
  the tray menus).

## Explicit user workflow rules

- Commit + tag a point release for every verified iteration; never skip versions.
- Real-shell testing only for notifications (plasmoidviewer can't own the bus name).
- User restarts plasmashell; assistant never restarts the user's session.
- Keep this worklog + targets updated in the working directory.
