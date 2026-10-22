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
- **First toast missing after a fresh session** — parked; hints in WORKLOG.md.
- ~~Panel tray icons left of the applet icons~~ — done & verified.
- ~~Panel tray icons slightly larger~~ — superseded: v0.12.5 renders them at
  exactly the unified size, artwork fills the tile, no padding/hover ring.
- ~~Tooltip switch when hovering tray icons~~ — final form (v0.12.5): the
  shell-positioned plasmoid tooltip shows title + app tooltip.
- ~~Per-icon show/hide config~~ — done & verified (v0.12.4, Panel icons tab).
- ~~Tray icon update latency~~ — v0.12.5: 400 ms poll while panel icons shown.
- ~~Small gap between tray icons and unified icons~~ — user-tuned, v0.12.5.

## Explicit user workflow rules

- Commit + tag a point release for every verified iteration; never skip versions.
- Real-shell testing only for notifications (plasmoidviewer can't own the bus name).
- User restarts plasmashell; assistant never restarts the user's session.
- Keep this worklog + targets updated in the working directory.
