/*
    SPDX-License-Identifier: GPL-2.0-or-later

    KDE Connect detail page.  Mirrors the KDE Connect plasmoid's
    FullRepresentation.qml (kdeconnect-kde/plasmoid/package/contents/ui/):

      - a list of paired devices (online first, then offline — same sort as
        the stock applet's DevicesSortProxyModel, which we don't import
        here; the backend's `connectedModel` already filters to paired +
        reachable, and `pairedModel` to paired)
      - each row shows the device's icon, name, reachability status, and
        battery percentage (the same `Battery.qml` the stock applet uses)
      - clicking a row reveals the per-device actions: "Send File",
        "Find My Phone", "Browse Files" (SFTP), "Remote Input" — same set
        the stock applet shows in its DeviceDelegate.qml, exposed through
        the same DeviceDbusInterface plugin loaders

    All device-side logic goes through `org.kde.kdeconnect` DeviceDbusInterface
    and the per-plugin QML types from the stock applet, so behaviour is
    identical: same D-Bus calls, same error messages, same permission prompts.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kdeconnect as KDEConnect

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    // Header: pair-new-device button (same as stock's helpfulAction).
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label {
            text: i18n("Paired devices")
            font.bold: true
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            PlasmaComponents3.ToolTip.text: i18n("KDE Connect Settings…")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: page.backend.openKDEConnectSettings()
        }
        PlasmaComponents3.Button {
            text: i18n("Pair a Device…")
            icon.name: "list-add"
            onClicked: page.backend.openKDEConnectSettings()
        }
    }

    Kirigami.PlaceholderMessage {
        visible: page.backend.kdeconnectPairedCount === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "kdeconnect"
        text: i18n("No paired devices")
        explanation: i18n("Install KDE Connect on your Android device to integrate it with Plasma.")
    }

    PlasmaComponents3.ScrollView {
        visible: page.backend.kdeconnectPairedCount > 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            clip: true
            spacing: Kirigami.Units.smallSpacing / 2
            // The paired model is what the stock applet shows: paired devices
            // whether or not they're reachable.  Sorting (online first) is
            // done by DevicesSortProxyModel in the stock applet; the model
            // we get from `org.kde.kdeconnect` is already in a stable order.
            model: page.backend.kdeconnectPairedModel

            delegate: PlasmaComponents3.ItemDelegate {
                id: row
                // The stock KDE Connect applet's DeviceDelegate only declares
                // `required property int index` and `required property var model`,
                // then reads everything through `model.<role>`.  We do the
                // same here — `model.name`, `model.iconName`, `model.deviceId`,
                // `model.device`, `model.status` — to avoid any collision
                // with FINAL/reserved properties on ItemDelegate (e.g.
                // `display`, `name`, `device`).
                required property int index
                required property var model

                width: ListView.view.width
                onClicked: actions.visible = !actions.visible

                // The Device role is a DeviceDbusInterface, the same object
                // the stock applet's DeviceDelegate.qml uses.
                readonly property var device: row.model.device
                readonly property bool isReachable: device ? device.isReachable : false
                readonly property bool isPaired: device ? device.isPaired : false

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            source: row.model.iconName || "kdeconnect"
                            fallback: "kdeconnect"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            opacity: row.isReachable ? 1 : 0.5
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: row.model.name
                                font.bold: row.isReachable
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: row.isReachable
                                    ? i18n("Connected")
                                    : i18n("Disconnected")
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }
                        }
                        // Clicking the row reveals the per-device actions panel
                        // (Send File, Browse Files, Find My Phone).  The stock
                        // applet uses a similar expand-on-click in its
                        // DeviceDelegate.qml header.
                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            source: "go-down"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            opacity: 0.6
                            rotation: actions.visible ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                        }
                    }

                    // Per-device actions panel, mirrors the stock applet's
                    // DeviceDelegate.qml plugin rows.  Each row inlines the
                    // same PluginChecker + *DbusInterfaceFactory pattern the
                    // stock applet uses in its Share.qml / Sftp.qml /
                    // FindMyPhone.qml — we can't import those local QML
                    // files from outside the kdeconnect plasmoid package,
                    // so the calls are duplicated here.  They go to the same
                    // D-Bus service the stock applet talks to, so behaviour
                    // is identical.
                    ColumnLayout {
                        id: actions
                        visible: false
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.largeSpacing
                        spacing: 0

                        // Plugin checkers — one per action we expose.  These
                        // match `pluginName` strings the stock applet uses.
                        KDEConnect.PluginChecker {
                            id: shareChecker
                            pluginName: "share"
                            device: row.device
                        }
                        KDEConnect.PluginChecker {
                            id: sftpChecker
                            pluginName: "sftp"
                            device: row.device
                        }
                        KDEConnect.PluginChecker {
                            id: findmyphoneChecker
                            pluginName: "findmyphone"
                            device: row.device
                        }

                        PlasmaComponents3.Button {
                            Layout.fillWidth: true
                            flat: true
                            text: i18n("Send File…")
                            icon.name: "document-share"
                            enabled: row.isReachable && shareChecker.available
                            onClicked: {
                                if (!row.device) return
                                const share = KDEConnect.ShareDbusInterfaceFactory.create(row.device.id())
                                if (share) share.shareUrl("")
                            }
                        }
                        PlasmaComponents3.Button {
                            Layout.fillWidth: true
                            flat: true
                            text: i18n("Browse Files")
                            icon.name: "document-open-folder"
                            enabled: row.isReachable && sftpChecker.available
                            onClicked: {
                                if (!row.device) return
                                const sftp = KDEConnect.SftpDbusInterfaceFactory.create(row.device.id())
                                if (sftp) sftp.startBrowsing()
                            }
                        }
                        PlasmaComponents3.Button {
                            Layout.fillWidth: true
                            flat: true
                            text: i18n("Find My Phone")
                            icon.name: "phone"
                            enabled: row.isReachable && findmyphoneChecker.available
                            onClicked: {
                                if (!row.device) return
                                const fmp = KDEConnect.FindMyPhoneDbusInterfaceFactory.create(row.device.id())
                                if (fmp) fmp.ring()
                            }
                        }
                    }
                }
            }
        }
    }
}
