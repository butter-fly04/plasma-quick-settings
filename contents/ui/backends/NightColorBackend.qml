/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Night Color (a.k.a. Night Light) state, taken from KWin itself.

    There is no separate Plasma applet for Night Color in Plasma 6 — it is part
    of KWin and exposes itself on the session bus:

        service  : org.kde.KWin
        path     : /org/kde/KWin/NightLight
        interface: org.kde.KWin.NightLight

        properties (via org.freedesktop.DBus.Properties):
            running    bool   — Night Color is actively adjusting temperature
            available  bool   — the system supports it
            enabled    bool   — it is enabled in the config (Active=true)
        methods:
            reconfigure()      — re-read kwinrc and apply

    We toggle by writing `~/.config/kwinrc [NightColor] Active=true|false`
    and calling `reconfigure()`.  This is the same path Plasma's own Night
    Color KCM uses, so the result is identical to toggling from System
    Settings.

    All the D-Bus calls go through `../scripts/qs.sh` (run via the executable
    engine in Backend.qml, the existing pattern) so a missing `busctl` or a
    KWin build without Night Color just leaves this feature disabled instead
    of crashing the plasmoid.  The actual command plumbing lives in Backend.qml
    alongside brightness and Wi-Fi.
*/
import QtQuick

Item {
    id: root
    visible: false

    // ----------------------------------------------------- availability/state
    property bool available: false
    property bool enabled: false       // [NightColor] Active in kwinrc (after reconfigure)
    property bool running: false       // KWin is currently shifting the temperature
    property string error: ""

    // Convenience for the tile's subtitle.
    readonly property string subtitle: {
        if (!available) return i18n("Unavailable")
        if (!enabled) return i18n("Off")
        if (running) return i18n("On")
        return i18n("Enabled")
    }

    // ---------------------------------------------------------- mutators
    // The actual work is done by Backend.qml running `qs.sh nightcolor on|off`,
    // which writes kwinrc and calls reconfigure().  Backend.qml then refreshes
    // `enabled` / `running` here.  This indirection lets us reuse the existing
    // executable-engine plumbing (one wrapper, one place that needs to change
    // if the engine ever goes away) instead of opening a second D-Bus channel.
    function setEnabled(on) {
        // Optimistic UI: flip now so the tile feels instant, then let the
        // poll correct us if KWin disagrees.
        enabled = on
    }
}
