/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Airplane mode state, using the same rfkill-based logic Plasma's own
    airplane-mode indicator uses internally.

    In Plasma 6 there is no separate "airplane mode" applet in the public
    repos — the airplane-mode icon in the tray is a StatusNotifierItem
    published by a kded helper that watches `/sys/class/rfkill/`.  We bypass
    the SNI and talk to the same kernel interface directly:

        rfkill list            — show every radio and its soft/hard block state
        rfkill block all       — soft-block every radio (Wi-Fi, BT, WWAN, ...)
        rfkill unblock all     — release the soft block

    "Airplane mode on" therefore means "every soft-blockable radio is
    soft-blocked".  Hard blocks (the physical switch on some laptops) are
    reported but cannot be toggled from software, so we keep the tile
    read-only in that case.

    Shell access lives in `../scripts/qs.sh` (commands: `airplane status`,
    `airplane on`, `airplane off`), run via the executable engine in
    Backend.qml — same pattern as Wi-Fi.  The existing Wi-Fi and Bluetooth
    backends poll their own state, so when we block or unblock radios here
    they pick up the change on the next poll and update their tiles too.
*/
import QtQuick

Item {
    id: root
    visible: false

    // ----------------------------------------------------- availability/state
    property bool available: false       // rfkill exists and there is at least one radio
    property bool active: false          // every soft-blockable radio is soft-blocked
    property bool hardBlocked: false     // a physical switch is killing the radio(s)
    property string error: ""

    readonly property string subtitle: {
        if (!available) return i18n("Unavailable")
        if (hardBlocked) return i18n("Hardware off")
        return active ? i18n("On") : i18n("Off")
    }

    // ---------------------------------------------------------- mutators
    function setActive(on) {
        // Optimistic UI; Backend.qml refreshes from `rfkill list` afterwards.
        active = on && !hardBlocked
    }
}
