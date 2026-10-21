/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Power Profile state, taken from Plasma itself instead of being re-implemented.

    PowerProfilesControl (org.kde.plasma.private.batterymonitor, in the powerdevil
    repo at applets/batterymonitor/plugin/powerprofilescontrol.cpp) is the same
    object the stock "Power & Battery" applet uses.  It talks to the
    power-profiles-daemon D-Bus service for us, so we get for free:

      - whether power-profiles-daemon is installed and the daemon is registered
      - the list of profiles the daemon advertises (usually
        power-saver / balanced / performance)
      - the currently active profile and the user-configured default
      - "Performance inhibited" reasons (lap detected, high temperature)
        and "Performance degraded" reasons (the same, but while it is active)
      - the list of applications that have an active profile *hold*
        (so a tile can show "an app has requested Performance")

    What we add on top is just the GNOME-style "tile" facade the rest of
    Quick Settings expects (one boolean active flag, one label, one setter),
    plus a friendly "cycle" used by the panel button when scrolled.
*/
import QtQuick
import org.kde.plasma.private.batterymonitor as BatteryMonitor

Item {
    id: root
    visible: false

    // The stock applet's control.  All the real work happens here.
    BatteryMonitor.PowerProfilesControl {
        id: control
    }

    // ----------------------------------------------------- availability/state
    // `isPowerProfileDaemonInstalled` is the same gate the stock applet uses
    // before showing the slider at all: it covers both "package not installed"
    // and "installed but the daemon isn't registered on the bus right now".
    readonly property bool available: control.isPowerProfileDaemonInstalled
    readonly property bool tlpInstalled: control.isTlpInstalled
    readonly property var profiles: control.profiles            // QStringList
    readonly property string activeProfile: control.activeProfile
    readonly property string configuredProfile: control.configuredProfile
    readonly property string inhibitionReason: control.inhibitionReason
    readonly property string degradationReason: control.degradationReason
    readonly property string profileError: control.profileError
    readonly property var profileHolds: control.profileHolds    // list of { Name, Icon, Profile, Reason }

    // Convenience: the three logical labels.  Matches `profileData` in the
    // stock applet's PowerProfileItem.qml.
    readonly property var profileLabels: ({
        "power-saver": i18n("Power Save"),
        "balanced":    i18n("Balanced"),
        "performance": i18n("Performance")
    })
    readonly property string activeProfileLabel: profileLabels[activeProfile] || activeProfile || i18n("Balanced")

    // "Performance" can be inhibited by the kernel (lap detected, too hot).
    // The stock applet disables the right half of its slider when this is set;
    // we use it to grey out the Performance row on the detail page.
    readonly property bool performanceInhibited: inhibitionReason.length > 0

    // ----------------------------------------------------------- mutators
    // The stock applet passes `isSilent` (whether to show an OSD) based on
    // whether the popup is open.  We mirror that here.
    function setProfile(profile) {
        if (!available || profile === activeProfile)
            return
        control.isSilent = false
        control.setProfile(profile)
    }

    // Cycle in the same order the stock applet's slider goes (low → high).
    // Used by scrolling the tile (which the panel doesn't do, but a future
    // keyboard shortcut might).  Skips Performance when it is inhibited.
    function cycleProfile() {
        if (!available)
            return
        const order = ["power-saver", "balanced", "performance"]
        const start = order.indexOf(activeProfile)
        for (let i = 1; i <= order.length; i++) {
            const next = order[(start + i) % order.length]
            if (next === "performance" && performanceInhibited)
                continue
            setProfile(next)
            return
        }
    }

    // --------------------------------------------------------- error sink
    // The stock applet pops up a Notification when setProfile() fails (e.g.
    // trying to enter Performance while it is inhibited).  Here we just surface
    // the string so the caller (Backend.qml) can decide what to do with it.
    //
    // PowerProfilesControl clears `profileError` itself after emitting the
    // change signal, so reading it once is enough.
    signal errorOccurred(string message)
    Connections {
        target: control
        function onProfileErrorChanged() {
            if (control.profileError.length > 0)
                root.errorOccurred(control.profileError)
        }
    }
}
