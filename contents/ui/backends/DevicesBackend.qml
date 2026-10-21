/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Removable-device state, taken from Plasma itself instead of being re-implemented.

    plasma-workspace's devicenotifier applet (applets/devicenotifier/qml/main.qml)
    uses `plasma.applet.org.kde.plasma.devicenotifier.DeviceFilterControl`,
    which is a QSortFilterProxyModel around `DeviceControl` (a QAbstractListModel
    that watches Solid's device monitor).

    The roles it exposes (from devicecontrol.h) are:
        Udi             — Solid UDI (opaque string identifier)
        Description     — "SanDisk Extreme 64GB" etc.
        Type            — "Removable Storage", "Portable Media Player", ...
        Icon            — freedesktop icon name
        IsRemovable     — can be unplugged
        FreeSpaceText   — "12.3 GiB" or empty
        SizeText        — "58.6 GiB" or empty
        Mounted         — bool
        State           — string ("Mounted", "Unmounted", "Mounting", ...)
        Message         — informational message (e.g. "It is now safe to remove")
        Actions         — list of {icon, text, predicate} actions for this device

    We use the same model here, so the Quick Settings "Disks & Devices" page
    shows exactly what the stock applet shows: same filtering (only removable
    devices by default), same mount/unmount/eject actions, same free-space
    readout.  Mount/unmount go through Solid's StorageAccess the same way the
    stock applet does (DeviceControl invokes setupTeardown() for us).

    If the `plasma.applet.org.kde.plasma.devicenotifier` plugin isn't
    installed (a custom Plasma build) the Loader in Backend.qml reports the
    failure and the tile stays hidden.
*/
import QtQuick
import plasma.applet.org.kde.plasma.devicenotifier as DeviceNotifier

Item {
    id: root
    visible: false

    // Same `DeviceFilterControl` the stock applet uses.  The enum is
    // `DeviceFilterControl.All | Removable | Unremovable`; we default to
    // `Removable` to match the stock applet's default config
    // (removableDevices=true, allDevices=false).
    DeviceNotifier.DeviceFilterControl {
        id: filterModel
        filterType: DeviceNotifier.DeviceFilterControl.Removable
    }

    // ----------------------------------------------------- availability/state
    readonly property bool available: filterModel !== null
    // rowCount() is not a notifying property, so keep our own counter in
    // sync with the model's signals.
    property int count: 0
    function recount() { count = filterModel.rowCount() }
    Connections {
        target: filterModel
        function onRowsInserted() { root.recount() }
        function onRowsRemoved() { root.recount() }
        function onModelReset() { root.recount() }
        function onLayoutChanged() { root.recount() }
    }
    Component.onCompleted: recount()
    readonly property var model: filterModel

    // Exposed so the UI can read the enum without importing the namespace.
    readonly property int roleUdi: DeviceNotifier.DeviceFilterControl.Udi
    readonly property int roleDescription: DeviceNotifier.DeviceFilterControl.Description
    readonly property int roleType: DeviceNotifier.DeviceFilterControl.Type
    readonly property int roleIcon: DeviceNotifier.DeviceFilterControl.Icon
    readonly property int roleIsRemovable: DeviceNotifier.DeviceFilterControl.IsRemovable
    readonly property int roleFreeSpaceText: DeviceNotifier.DeviceFilterControl.FreeSpaceText
    readonly property int roleSizeText: DeviceNotifier.DeviceFilterControl.SizeText
    readonly property int roleMounted: DeviceNotifier.DeviceFilterControl.Mounted
    readonly property int roleState: DeviceNotifier.DeviceFilterControl.State
    readonly property int roleMessage: DeviceNotifier.DeviceFilterControl.Message
    readonly property int roleActions: DeviceNotifier.DeviceFilterControl.Actions
    readonly property int roleIsBusy: DeviceNotifier.DeviceFilterControl.IsBusy

    readonly property string subtitle: {
        if (count === 0) return i18n("No devices")
        return i18np("One device attached", "%1 devices attached", count)
    }

    // ---------------------------------------------------------- mutators
    // The stock devicenotifier applet triggers per-device Solid actions
    // through the model's `Actions` role (an `ActionsInterface` with
    // `actionTriggered(name)`, `defaultActionName`, `defaultActionIcon`,
    // `defaultActionText` — see plasma-workspace/applets/devicenotifier/
    // actionsinfo.h).  We follow the same pattern: the page asks for the
    // actions object on a row, then triggers a named action on it.  The
    // names ("mount", "unmount", "eject", "openWithFileManager") come from
    // the Solid predicate files in /usr/share/solid/actions/, so the same
    // call works whether the device is a USB stick, MTP player, or audio CD.
    function triggerAction(actionsObj, name) {
        if (actionsObj && typeof actionsObj.actionTriggered === "function")
            actionsObj.actionTriggered(name)
    }
    function triggerDefault(actionsObj) {
        if (actionsObj && actionsObj.defaultActionName)
            actionsObj.actionTriggered(actionsObj.defaultActionName)
    }
}
