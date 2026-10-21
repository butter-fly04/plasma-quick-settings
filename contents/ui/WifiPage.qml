/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Wi-Fi detail page: radio switch, rescan, list of visible networks.
      - active network     -> "Disconnect" button on its row
      - saved or open      -> click connects
      - new, password      -> click opens an inline password field
      - enterprise (802.1X)-> needs a login, so we point to Network settings
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var backend

    property string askSsid: ""     // network whose password row is open
    property string password: ""

    spacing: Kirigami.Units.smallSpacing

    // The list rebuilds its rows when it changes, so hold refreshes while the
    // user is typing. (Binding restores the old value when the page goes away.)
    Binding {
        target: page.backend
        property: "listsPaused"
        value: page.askSsid.length > 0
    }

    function activate(n) {
        if (n.active || backend.wifiBusySsid.length > 0)
            return
        backend.wifiError = ""
        if (n.saved || !n.secure) {
            askSsid = ""
            backend.connectWifi(n.ssid, n.saved)
        } else if (n.enterprise) {
            askSsid = ""
            backend.wifiError = i18n("This network needs a login. Set it up in Network settings.")
        } else {
            password = ""
            askSsid = askSsid === n.ssid ? "" : n.ssid
        }
    }

    function submit(n) {
        if (password.length === 0)
            return
        const pw = password
        password = ""
        askSsid = ""
        backend.connectWifi(n.ssid, false, pw)
    }

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents3.Switch {
            text: i18n("Wi-Fi")
            enabled: page.backend.wifiAvailable
            checked: page.backend.wifiEnabled
            onToggled: page.backend.setWifiEnabled(checked)
        }
        Item { Layout.fillWidth: true }
        PlasmaComponents3.BusyIndicator {
            visible: page.backend.wifiScanning
            running: visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }
        PlasmaComponents3.ToolButton {
            icon.name: "view-refresh"
            enabled: page.backend.wifiEnabled && !page.backend.wifiScanning
            PlasmaComponents3.ToolTip.text: i18n("Scan for networks")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: page.backend.scanWifi()
        }
    }

    PlasmaComponents3.Label {
        visible: page.backend.wifiError.length > 0
        text: page.backend.wifiError
        color: Kirigami.Theme.negativeTextColor
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    Kirigami.PlaceholderMessage {
        visible: !page.backend.wifiEnabled || page.backend.wifiNetworks.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: page.backend.wifiEnabled ? "network-wireless-disconnected" : "network-wireless-off"
        text: !page.backend.wifiAvailable ? i18n("No Wi-Fi adapter found")
            : !page.backend.wifiEnabled ? i18n("Wi-Fi is off")
            : page.backend.wifiScanning ? i18n("Looking for networks…")
            : i18n("No networks found")
    }

    PlasmaComponents3.ScrollView {
        visible: page.backend.wifiEnabled && page.backend.wifiNetworks.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            clip: true
            spacing: Kirigami.Units.smallSpacing / 2
            model: page.backend.wifiNetworks

            delegate: ColumnLayout {
                id: row

                required property var modelData

                readonly property bool asking: page.askSsid === modelData.ssid
                readonly property bool busy: page.backend.wifiBusySsid === modelData.ssid

                width: ListView.view.width
                spacing: 0

                PlasmaComponents3.ItemDelegate {
                    Layout.fillWidth: true
                    highlighted: row.modelData.active
                    onClicked: page.activate(row.modelData)

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            source: page.backend.signalIcon(row.modelData.signal)
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: row.modelData.ssid
                                font.bold: row.modelData.active
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                visible: text.length > 0
                                text: row.modelData.active ? i18n("Connected")
                                    : row.busy ? i18n("Connecting…")
                                    : row.modelData.saved ? i18n("Saved")
                                    : !row.modelData.secure ? i18n("Open network")
                                    : ""
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }
                        }
                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            visible: row.modelData.secure
                            source: "object-locked"
                            opacity: 0.7
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        PlasmaComponents3.BusyIndicator {
                            visible: row.busy
                            running: visible
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        PlasmaComponents3.ToolButton {
                            visible: row.modelData.active && !row.busy
                            text: i18n("Disconnect")
                            onClicked: page.backend.disconnectWifi()
                        }
                    }
                }

                // inline password entry
                RowLayout {
                    visible: row.asking
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: i18n("Password")
                        text: page.password
                        onTextEdited: page.password = text
                        onAccepted: if (page.password.length >= 8) page.submit(row.modelData)
                        onVisibleChanged: if (visible) forceActiveFocus()
                    }
                    PlasmaComponents3.Button {
                        text: i18n("Connect")
                        enabled: page.password.length >= 8
                        onClicked: page.submit(row.modelData)
                    }
                }
            }
        }
    }

    PlasmaComponents3.Button {
        text: i18n("Network settings…")
        icon.name: "configure"
        Layout.alignment: Qt.AlignRight
        onClicked: page.backend.openNetworkSettings()
    }
}
