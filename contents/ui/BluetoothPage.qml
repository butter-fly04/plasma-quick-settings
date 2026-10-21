/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Bluetooth detail page. Mirrors BlueDevil's own applet (Plasma 6.7):
      - header switch (enable = unblock + power adapters)
      - paired/connected devices in "Connected" / "Available" sections
      - clicking a device connects or disconnects it
      - same placeholders: no adapters / disabled (with Enable) / nothing paired (with Pair)
    The model, sorting, sections and busy state all come from BlueDevil's models.
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

        PlasmaComponents3.Switch {
            text: i18n("Bluetooth")
            enabled: page.backend.bluetoothAvailable
            checked: page.backend.bluetoothEnabled
            onToggled: page.backend.setBluetoothEnabled(checked)
        }
        Item { Layout.fillWidth: true }
        PlasmaComponents3.ToolButton {
            visible: page.backend.bluetoothEnabled
            icon.name: "list-add"
            text: i18n("Pair Device…")
            display: PlasmaComponents3.AbstractButton.IconOnly
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: page.backend.pairBtDevice()
        }
    }

    // Placeholder states, same wording and logic as BlueDevil.
    ColumnLayout {
        visible: !page.backend.bluetoothAvailable || !page.backend.bluetoothEnabled || list.count === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.largeSpacing

        Item { Layout.fillHeight: true }
        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            icon.name: page.backend.bluetoothEnabled ? "network-bluetooth-activated" : "network-bluetooth"
            text: !page.backend.bluetoothAvailable ? i18n("No Bluetooth adapters available")
                : !page.backend.bluetoothEnabled ? i18n("Bluetooth is disabled")
                : i18n("No devices paired")
        }
        PlasmaComponents3.Button {
            visible: page.backend.bluetoothAvailable
            text: page.backend.bluetoothEnabled ? i18n("Pair Device…") : i18n("Enable")
            icon.name: page.backend.bluetoothEnabled ? "list-add" : "preferences-system-bluetooth"
            Layout.alignment: Qt.AlignHCenter
            onClicked: page.backend.bluetoothEnabled
                ? page.backend.pairBtDevice()
                : page.backend.setBluetoothEnabled(true)
        }
        Item { Layout.fillHeight: true }
    }

    PlasmaComponents3.ScrollView {
        visible: page.backend.bluetoothEnabled && list.count > 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            clip: true
            spacing: Kirigami.Units.smallSpacing / 2
            model: page.backend.bluetoothEnabled ? page.backend.btModel : null

            section.property: "Section"
            section.delegate: PlasmaComponents3.Label {
                required property string section
                width: list.width
                text: section
                font.bold: true
                opacity: 0.7
                topPadding: Kirigami.Units.smallSpacing
            }

            delegate: PlasmaComponents3.ItemDelegate {
                id: row

                required property int index
                required property var model

                readonly property bool busy: model.Connecting || model.Disconnecting

                // BlueDevil's infoText(), minus the device-type word (that needs
                // the bluez-qt enum, which the UI deliberately doesn't import).
                function infoText(): string {
                    if (model.Connecting)
                        return i18n("Connecting")
                    if (model.Disconnecting)
                        return i18n("Disconnecting")
                    const labels = []
                    if (model.ConnectionFailed)
                        labels.push(i18n("Connection failed"))
                    if (model.Battery)
                        labels.push(i18n("%1% Battery", model.Battery.percentage))
                    if (model.Connected)
                        labels.push(i18n("Connected"))
                    return labels.join(" · ")
                }

                width: ListView.view.width
                highlighted: model.Connected
                onClicked: page.backend.toggleBtDevice(model.Device, model.Ubi, model.Connected, busy)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: row.model.Icon
                        fallback: "preferences-system-bluetooth"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        PlasmaComponents3.Label {
                            text: row.model.DeviceFullName
                            font.bold: row.model.Connected
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            visible: text.length > 0
                            text: row.infoText()
                            opacity: 0.7
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    PlasmaComponents3.BusyIndicator {
                        visible: row.busy
                        running: visible
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                }
            }
        }
    }

    PlasmaComponents3.Button {
        text: i18n("Bluetooth settings…")
        icon.name: "configure"
        Layout.alignment: Qt.AlignRight
        onClicked: page.backend.openBluetoothSettings()
    }
}
