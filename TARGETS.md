# Quick Settings plasmoid — targets

What the user asked for; strikethrough = done and verified (or user explicitly parked it).

## Milestone 12 (system tray + notifications)

1. ~~Toast notifications (no stock notifications applet on this system) — v0.12.0/0.12.1~~
2. ~~Per-app panel tray icons with activate/context-menu — v0.12.0~~
3. ~~Toast dialog load fixes (Connections child / Plasmoid import) — v0.12.1~~
4. ~~Tray poll keeps running for panel icons when popup closes — v0.12.2~~
5. ~~History action button semantics (InvokeBehavior.Close) — v0.12.3~~

## M12.2 polish round (user request, Oct 22)

- **Second toast race / first toast missing** — partial: toasts appear again;
  *first* notification still silently missing (user parked this).
- ~~Toast UI restyle: dark disc behind bell, spacing~~ — symbolic fallback done,
  row highlight softened, reserved stack height. User still unhappy: **remove the
  fallback notification icon entirely** (icon only when the app provides one).
- ~~Panel tray icons left of the applet icons~~ — done & verified.
- ~~Panel tray icons slightly larger~~ — done & verified (15% bigger).
- ~~Tooltip switch when hovering tray icons~~ — deployed; user-verifying.
- **Per-icon show/hide config** — plumbing verified (journal shows the pages receive
  the list); UI moved to the *Panel icons* config tab; **await user verification**.

## Explicit user workflow rules

- Commit + tag a point release for every verified iteration; never skip versions.
- Real-shell testing only for notifications (plasmoidviewer can't own the bus name).
- User restarts plasmashell; assistant never restarts the user's session.
- Keep this worklog + targets updated in the working directory.
