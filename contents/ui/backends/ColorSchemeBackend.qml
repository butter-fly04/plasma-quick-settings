/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Color scheme state (the "Dark Style" tile), using Plasma's own
    `plasma-apply-colorscheme` tool.

    Plasma 6.7 added a Dark Mode toggle to the system tray.  It works by:

      - reading the current scheme name from
            `~/.config/kdeglobals [General] ColorScheme`
      - finding a "light" and "dark" pair from the schemes installed under
            `/usr/share/color-schemes/` and `~/.local/share/color-schemes/`
        (Breeze Light and Breeze Dark by default)
      - calling `plasma-apply-colorscheme <name>` to switch

    We do exactly that here.  All shell access lives in `../scripts/qs.sh`
    (commands: `colorscheme current`, `colorscheme list`, `colorscheme set <name>`)
    so a system without `plasma-apply-colorscheme` just disables the tile.

    Pairing strategy (same as the stock tray toggle):
      - "is the current scheme dark?" = the scheme file's
        `[ColorEffects:Inactive]` or `[General] ColorScheme` name contains
        the substring "Dark" (case-insensitive).  We don't introspect the
        actual palette — that's what Plasma does, and it's good enough.
      - The "light partner" of a dark scheme is the same name with "Dark"
        stripped; the "dark partner" of a light scheme is the same name with
        " Dark" appended.  If the resulting name isn't in the installed list,
        we fall back to Breeze / Breeze Dark (always shipped with Plasma).
*/
import QtQuick

Item {
    id: root
    visible: false

    // ----------------------------------------------------- availability/state
    property bool available: false          // plasma-apply-colorscheme exists
    property string currentScheme: ""       // e.g. "Breeze Dark"
    property var schemes: []                // [{name: "Breeze", dark: false}, ...]
    property string error: ""

    // True when the active scheme is one we recognise as dark.  The UI binds
    // the "Dark Style" tile's `active` flag to this.
    readonly property bool darkActive: isDarkName(currentScheme)

    // The pair we'll switch to when the user toggles.  Empty if no partner
    // could be found (and the UI disables the toggle in that case).
    readonly property string lightPartner: partnerOf(currentScheme, false)
    readonly property string darkPartner: partnerOf(currentScheme, true)
    readonly property string partner: darkActive ? lightPartner : darkPartner

    readonly property string subtitle: {
        if (!available) return i18n("Unavailable")
        if (darkActive) return i18n("Dark")
        return i18n("Light")
    }

    // ---------------------------------------------------------- helpers
    function isDarkName(name) {
        return /(^|\s)dark(\s|$)/i.test(name || "")
    }

    // Given the current scheme, find the name of its dark or light partner.
    function partnerOf(name, wantDark) {
        if (!name) return wantDark ? "Breeze Dark" : "Breeze"
        const dark = isDarkName(name)
        if (dark === wantDark) return name  // already in the wanted state

        let candidate
        if (dark) {
            // Strip "Dark" — try "Foo Dark" → "Foo", then "FooDark" → "Foo"
            candidate = name.replace(/\s*Dark\s*$/i, "")
        } else {
            candidate = name + " Dark"
        }
        // Confirm the candidate exists; otherwise fall back to Breeze pair.
        for (const s of schemes) {
            if (s.name === candidate)
                return candidate
        }
        return wantDark ? "Breeze Dark" : "Breeze"
    }

    // ---------------------------------------------------------- mutators
    function toggle() {
        if (!available || partner.length === 0 || partner === currentScheme)
            return
        // Optimistic UI; Backend.qml will refresh from disk.
        currentScheme = partner
    }
}
