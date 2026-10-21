/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Disks & Devices detail page.  Mirrors plasma-workspace's devicenotifier
    applet (applets/devicenotifier/qml/FullRepresentation.qml):

      - a list of attached removable devices (USB sticks, SD cards, MTP
        players) — the same `DeviceFilterControl` model the stock applet
        uses, filtered to "Removable" by default
      - each row shows the device's icon, description, mount state, and
        free space (matching the stock applet's DeviceItem.qml)
      - clicking a mounted device opens it in the file manager
      - the mount/unmount/eject buttons go through Solid's StorageAccess
        exactly the way the stock applet does it (the model handles the
        D-Bus call for us)
      - a "Safely Remove All" button appears when more than one device is
        mounted, just like the stock applet's heading button

    The roles we read (Udi, Description, Icon, Mounted, FreeSpaceText,
    SizeText, State, Message) come straight from `DeviceControl` (see
    devicecontrol.h); the role numbers are forwarded from Backend.qml so
    this file doesn't need to import the devicenotifier plugin itself.

    If `plasma.applet.org.kde.plasma.devicenotifier` is missing the backend
    Loader fails and the tile stays hidden; the page never gets instantiated.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label {
            text: i18n("Attached devices")
            font.bold: true
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            PlasmaComponents3.ToolTip.text: i18n("Removable Devices settings…")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: page.backend.openDevicesSettings()
        }
    }

    Kirigami.PlaceholderMessage {
        visible: page.backend.devicesCount === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "drive-removable-media-symbolic"
        text: i18n("No removable devices attached")
    }

    // Device list.  We use a plain ListView (not wrapped in a ScrollView)
    // because the parent ColumnLayout already provides scrolling context via
    // the popup's own ScrollView, and wrapping a ListView in a ScrollView
    // in Plasma 6 can leave an empty gap at the top (the ScrollView reserves
    // space for a header that doesn't exist).  The ListView's
    // Layout.fillHeight lets it take all available vertical space; when
    // there are few items, they sit at the top and the bottom button stays
    // at the bottom (no empty gap above the list).
    PlasmaComponents3.ScrollView {
        id: devScroll
        visible: page.backend.devicesCount > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

    ListView {
        clip: true
        spacing: Kirigami.Units.smallSpacing / 2
        model: page.backend.devicesModel

        delegate: PlasmaComponents3.ItemDelegate {
            id: row
            // The stock devicenotifier applet's DeviceItem only declares
            // `required property int index` and `required property var model`,
            // then reads everything through `model.<role>`.  We do the
            // same, because several role names (`type`, `state`, `icon`,
            // `display`) collide with FINAL properties on ItemDelegate /
            // QQuickItem.  Reading through `model.*` sidesteps every
            // collision at once.
            required property int index
            required property var model

            width: ListView.view.width
            // The stock applet's default action is "Mount" when unmounted
            // and "Open in File Manager" when mounted (see actionsinfo.h
            // defaultActionName).  Clicking the row triggers it.
            onClicked: if (row.model.deviceActions) page.backend.deviceTriggerDefault(row.model.deviceActions)

                // Convenience aliases so the body below stays readable.
                // Role names are prefixed with `device` (see DeviceControl::roleNames
                // in plasma-workspace/applets/devicenotifier/devicecontrol.cpp):
                // deviceUdi, deviceDescription, deviceType, deviceIcon, deviceIsBusy,
                // deviceIsRemovable, deviceFreeSpaceText, deviceSizeText, deviceMounted,
                // deviceState, deviceMessage, deviceActions.
                readonly property bool isBusy: row.model.deviceIsBusy ?? false
                readonly property bool mounted: row.model.deviceMounted ?? false
                readonly property var actions: row.model.deviceActions
                readonly property string udi: row.model.deviceUdi ?? ""

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: (row.model.deviceIcon ?? "") || "drive-removable-media"
                        fallback: "drive-removable-media"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        opacity: row.isBusy ? 0.4 : 1
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        PlasmaComponents3.Label {
                            text: {
                                const desc = row.model.deviceDescription ?? ""
                                const t = row.model.deviceType ?? ""
                                return desc.length > 0 ? desc : t
                            }
                            font.bold: row.mounted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            visible: text.length > 0
                            text: {
                                const parts = []
                                const deviceState = row.model.deviceState ?? ""
                                if (deviceState.length > 0) parts.push(deviceState)
                                const free = row.model.deviceFreeSpaceText ?? ""
                                const size = row.model.deviceSizeText ?? ""
                                if (free.length > 0)
                                    parts.push(i18n("%1 free of %2", free, size))
                                else if (size.length > 0)
                                    parts.push(size)
                                const msg = row.model.deviceMessage ?? ""
                                if (msg.length > 0) parts.push(msg)
                                return parts.join(" · ")
                            }
                            opacity: 0.7
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    PlasmaComponents3.BusyIndicator {
                        visible: row.isBusy
                        running: visible
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    // The eject/mount button triggers the Solid action whose
                    // name the stock applet uses for the same button:
                    //   - mounted  → "unmount"  (Solid StorageAccess teardown)
                    //   - unmounted → "mount"   (Solid StorageAccess setup)
                    PlasmaComponents3.ToolButton {
                        visible: !row.isBusy
                        icon.name: row.mounted ? "media-eject" : "media-mount"
                        PlasmaComponents3.ToolTip.text: row.mounted
                            ? i18n("Safely remove")
                            : i18n("Mount")
                        PlasmaComponents3.ToolTip.visible: hovered
                        onClicked: page.backend.deviceTriggerAction(row.actions, row.mounted ? "unmount" : "mount")
                    }
                }
            }
    }
    }

    PlasmaComponents3.Button {
        text: i18n("Safely Remove All")
        icon.name: "media-eject"
        Layout.alignment: Qt.AlignRight
        visible: page.backend.devicesCount > 1
        // The stock applet's "Remove All" button calls the model's
        // `unmountAllRemovables()` (see devicefiltercontrol.h).  We forward
        // through the backend so the same D-Bus path is taken.
        onClicked: {
            if (page.backend.devicesModel)
                page.backend.devicesModel.unmountAllRemovables()
        }
    }
}
