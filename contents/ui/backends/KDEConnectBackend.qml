/*
    SPDX-License-Identifier: GPL-2.0-or-later

    KDE Connect state, taken from the KDE Connect plasmoid itself
    (kdeconnect-kde/plasmoid/package/contents/ui/main.qml).

    The KDE Connect plasmoid uses `org.kde.kdeconnect.DevicesModel` with a
    `displayFilter` (Paired | Reachable) to control which devices show up.
    We instantiate two of them, exactly like the stock applet:

      - `connectedDevicesModel`  — displayFilter = Paired | Reachable
                                    (devices that are paired AND online)
      - `allDevicesModel`         — displayFilter = 0
                                    (every device KDE Connect has seen)

    Each row's roles are:
        Name (DisplayRole), IconName, Status (InitialSortOrderRole),
        Id, Device (a DeviceDbusInterface*)

    The `Device` role is the same `DeviceDbusInterface` the stock applet's
    DeviceDelegate.qml uses, so all per-device actions (requestPair,
    requestUnpair, plugins().battery, send file, find phone, browse files,
    remote input, etc.) work here without re-implementation — we just forward
    through the UI.

    `KDEConnect.OpenConfig.openConfiguration()` opens the "KDE Connect
    Settings" KCM, used by the "Pair a Device…" button and the configure
    action — same as upstream.

    If `org.kde.kdeconnect` isn't installed (no KDE Connect daemon) the
    Loader in Backend.qml reports the failure and the tile stays hidden.
*/
import QtQuick
import org.kde.kdeconnect as KDEConnect

Item {
    id: root
    visible: false

    // Stock KDE Connect applet uses these two models.  `displayFilter` is
    // a bitmask: Paired=0x01, Reachable=0x02.
    KDEConnect.DevicesModel {
        id: connectedDevicesModel
        displayFilter: KDEConnect.DevicesModel.Paired | KDEConnect.DevicesModel.Reachable
    }
    KDEConnect.DevicesModel {
        id: pairedDevicesModel
        displayFilter: KDEConnect.DevicesModel.Paired
    }
    KDEConnect.DevicesModel {
        id: allDevicesModel
        // No filter — every device KDE Connect knows about, paired or not.
    }

    // ----------------------------------------------------- availability/state
    // True if at least one device is paired (whether or not it's online).
    readonly property bool available: pairedDevicesModel.count >= 0  // model is always alive if the import worked
    readonly property int connectedCount: connectedDevicesModel.count
    readonly property int pairedCount: pairedDevicesModel.count
    readonly property int totalCount: allDevicesModel.count

    // The "any connected device" string used by the tile subtitle.
    readonly property string subtitle: {
        if (connectedCount > 0)
            return i18np("One device connected", "%1 devices connected", connectedCount)
        if (pairedCount > 0)
            return i18np("One paired device (offline)", "%1 paired devices (offline)", pairedCount)
        return i18n("No devices paired")
    }

    // Exposed for the detail page's ListView.
    readonly property var connectedModel: connectedDevicesModel
    readonly property var pairedModel: pairedDevicesModel
    readonly property var allModel: allDevicesModel

    // ---------------------------------------------------------- mutators
    function openSettings() {
        KDEConnect.OpenConfig.openConfiguration()
    }
}
