/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Icon + slider + percentage (volume, microphone, brightness).
    Clicking the icon emits iconClicked() (used for mute).

    GNOME-style device picker: when `devices` is not empty a small chevron
    appears at the right edge of the row; expanding it lists the available
    output/input devices and marks the current default, and clicking a row
    switches it (devicePicked → Backend.setDefaultSink/setDefaultSource).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: row

    property string icon: ""
    property real value: 0      // 0..1
    property bool dimmed: false

    // [{name, active, description}] — empty shows a "no devices" hint.
    property var devices: []
    // Whether the row carries a device-picker arrow at all (volume & mic;
    // brightness has no devices).
    property bool picker: false
    property bool expanded: false
    // "audio-card" for outputs, "audio-input-microphone" for inputs.
    property string deviceIcon: "audio-card"

    signal moved(real value)
    signal iconClicked()
    // The list is refreshed on demand (not live-polled) when the picker opens.
    signal devicesRequested()
    signal devicePicked(string name)

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        PlasmaComponents3.ToolButton {
            icon.name: row.icon
            flat: true
            opacity: row.dimmed ? 0.6 : 1
            onClicked: row.iconClicked()
        }

        PlasmaComponents3.Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.01
            value: row.value
            onMoved: row.moved(value)
        }

        PlasmaComponents3.Label {
            text: i18n("%1%", Math.round(row.value * 100))
            horizontalAlignment: Text.AlignRight
            opacity: row.dimmed ? 0.6 : 0.8
            Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        }

        // Device-picker arrow at the right edge, using the same go-next
        // glyph the tiles' right edges use (the dedicated expand/collapse
        // theme icons render broken here).  It points right when closed,
        // like the pills above, and rotates 90° to point down when open.
        // Only on picker rows — the brightness slider has no devices.
        Item {
            id: pickerArrow
            visible: row.picker
            enabled: row.picker
            opacity: row.dimmed ? 0.6 : 1
            Layout.preferredWidth: arrowIcon.width
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            Layout.maximumWidth: Kirigami.Units.iconSizes.smallMedium

            rotation: row.expanded ? 90 : 0
            Behavior on rotation {
                RotationAnimation {
                    duration: Kirigami.Units.shortDuration
                }
            }

            Kirigami.Icon {
                id: arrowIcon
                isMask: true
                color: Kirigami.Theme.textColor
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                source: "go-next"
                fallback: "go-next"
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    row.expanded = !row.expanded
                    if (row.expanded)
                        row.devicesRequested()
                }
            }
        }
    }

    // Inline device list, expands under the slider row with a drop
    // animation (height + fade; the clip Item keeps the content inside
    // its shrinking bounds while the column sorts itself out).
    Item {
        id: devicesClip
        visible: row.picker
        clip: true
        Layout.fillWidth: true
        implicitHeight: row.expanded ? devicesColumn.implicitHeight : 0
        Behavior on implicitHeight {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: devicesColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
            opacity: row.expanded ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            PlasmaComponents3.Label {
                visible: row.devices.length === 0
                text: i18n("No devices found")
                opacity: 0.6
                leftPadding: Kirigami.Units.gridUnit * 2
            }

            Repeater {
                model: row.devices

                delegate: PlasmaComponents3.ItemDelegate {
                    id: deviceRow

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    horizontalPadding: Kirigami.Units.smallSpacing
                    leftPadding: Kirigami.Units.gridUnit * 2
                    // Already the default sink/source.
                    opacity: deviceRow.modelData.active ? 1 : 0.75

                    onClicked: row.devicePicked(deviceRow.modelData.name)

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            source: row.deviceIcon
                            fallback: row.deviceIcon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        PlasmaComponents3.Label {
                            text: deviceRow.modelData.description
                            elide: Text.ElideRight
                            opacity: deviceRow.modelData.active ? 1 : 0.7
                            font.bold: deviceRow.modelData.active
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            visible: deviceRow.modelData.active
                            text: i18n("Default")
                            opacity: 0.7
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            visible: deviceRow.modelData.active
                            source: "emblem-default"
                            fallback: "dialog-ok-apply"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                    }
                }
            }
        }
    }
}
