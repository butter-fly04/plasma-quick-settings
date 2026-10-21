/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Battery state, taken from Plasma itself instead of being re-implemented.

    BatteryControlModel (org.kde.plasma.private.battery, plasma-workspace
    components/batterycontrol) is what the stock "Power & Battery" applet uses.
    It already does the hard parts:
      - several batteries are combined: one battery reports its own percentage,
        two or more report total energy / total full energy (so a dual-battery
        laptop shows ONE combined figure, like the stock applet);
      - peripherals (mice, headsets, phones) are excluded from the figure;
      - charge state and "plugged in" are derived across all batteries.

    The icon choice below is copied from Plasma's own BatteryIcon.qml
    (org.kde.plasma.workspace.components, SPDX LGPL-2.0-or-later,
    (C) 2011 Viranch Mehta, (C) 2013 Kai Uwe Broulik) so the thresholds and the
    "-charging" rule match the stock applet exactly.

    M7 additions: the model itself is a QAbstractListModel of every primary
    battery on the system, so we can also expose a per-battery list (with
    health/capacity, charge state, and pretty name) for the new Battery detail
    page.  We also expose `chargeStopThreshold` (the "charge up to ~80%" feature
    some laptops support) and `inhibited`/`toggleInhibited` for the "Keep
    Display Awake" toggle (the same call the stock batterymonitor applet's
    middle-click makes through InhibitionControl).

    "Keep display awake" requires powerdevil's InhibitionControl, which lives
    in `org.kde.plasma.private.batterymonitor` — same module as
    PowerProfilesControl.  We instantiate it the same way the stock applet
    does in main.qml.
*/
import QtQuick
import org.kde.plasma.private.battery as PlasmaBattery
import org.kde.plasma.private.batterymonitor as BatteryMonitor

Item {
    id: root
    visible: false

    PlasmaBattery.BatteryControlModel {
        id: control
    }

    // Same InhibitionControl the stock batterymonitor applet uses for its
    // "suppress sleep and screen locking" middle-click action.
    BatteryMonitor.InhibitionControl {
        id: inhibitionControl
    }

    // Same gate the stock applet uses before showing a figure at all
    // ("battery is not present in the bay" when hasInternalBatteries && !hasCumulative).
    readonly property bool present: control.hasCumulative
    readonly property int percent: control.percent
    readonly property bool pluggedIn: control.pluggedIn
    readonly property bool charging: control.state === PlasmaBattery.BatteryControlModel.Charging
    readonly property bool fullyCharged: control.pluggedIn
        && control.state === PlasmaBattery.BatteryControlModel.FullyCharged
    // Remaining time (smoothed, like the stock applet's tooltip).
    readonly property int remainingMsec: control.smoothedRemainingMsec
    // Charge-stop threshold — 0 means "not set", otherwise 1..100 means the
    // user has configured the battery to stop charging at ~threshold%.
    // Used by the stock applet's InhibitionHint on each BatteryItem.
    readonly property int chargeStopThreshold: control.chargeStopThreshold

    // Inhibition state — `isManuallyInhibited` is true when the user has
    // requested "suppress sleep and screen locking" via middle-click in the
    // stock applet.  We expose the same state plus a toggle so the battery
    // detail page can show a "Keep Display Awake" switch.
    readonly property bool inhibited: inhibitionControl.isManuallyInhibited
    readonly property bool inhibitError: inhibitionControl.isManuallyInhibitedError
    function toggleInhibited() {
        // Same wording as the stock applet's onInhibitionChangeRequested.
        if (inhibitionControl.isManuallyInhibited) {
            inhibitionControl.uninhibit()
        } else {
            inhibitionControl.isSilent = true
            inhibitionControl.inhibit(i18n("The Quick Settings plasmoid has enabled suppressing sleep and screen locking"))
        }
    }

    // The model itself — a QAbstractListModel of every primary battery.
    // Roles (from batterycontrol.h BatteryRoles enum):
    //   PrettyName (Qt::DisplayRole), Percent, Capacity, Energy, PluggedIn,
    //   IsPowerSupply, ChargeState, Type
    // We expose the model so the detail page can use it as a ListView model
    // directly (with `required property int index` + `required property var model`).
    readonly property var batteriesModel: control

    // From BatteryIcon.qml: note "-charging" follows *plugged in*, not "is charging".
    readonly property string iconName: {
        if (!present)
            return "battery-missing"
        const p = percent
        let name
        if (p >= 95) name = "battery-100"
        else if (p >= 85) name = "battery-090"
        else if (p >= 75) name = "battery-080"
        else if (p >= 65) name = "battery-070"
        else if (p >= 55) name = "battery-060"
        else if (p >= 45) name = "battery-050"
        else if (p >= 35) name = "battery-040"
        else if (p >= 25) name = "battery-030"
        else if (p >= 15) name = "battery-020"
        else if (p > 5) name = "battery-010"
        else name = "battery-000"
        if (pluggedIn)
            name += "-charging"
        return name
    }
}
