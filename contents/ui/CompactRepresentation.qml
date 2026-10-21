/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The unified panel button: a cluster of status icons (like GNOME's top bar).
    Clicking anywhere on it opens the popup.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    required property PlasmoidItem plasmoidItem
    required property var backend

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int iconSize: Kirigami.Units.iconSizes.smallMedium

    // Diagnostic (visible with `plasmoidviewer` or the plasmashell journal):
    // if the panel icons are blank, this tells us whether the backend exists
    // and what size the panel actually gave this item.
    Component.onCompleted: console.log("[QuickSettings] compact ready:",
        "backend=" + (backend ? "ok" : "NULL"),
        "size=" + width + "x" + height,
        "vertical=" + vertical)

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            backend.toggleMute()
        } else {
            plasmoidItem.expanded = !plasmoidItem.expanded
        }
    }

    // Scroll over the panel button to change the volume (5% per notch).
    onWheel: wheel => {
        if (backend.audioAvailable)
            backend.nudgeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        wheel.accepted = true
    }

    Layout.minimumWidth: row.implicitWidth
    Layout.minimumHeight: row.implicitHeight
    Layout.preferredWidth: row.implicitWidth
    Layout.preferredHeight: row.implicitHeight

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.smallSpacing

        // Privacy indicators only take space while active (Milestone 6).
        // Each can be hidden via the "Panel Icons" config tab.
        Kirigami.Icon {
            isMask: true
            color: Kirigami.Theme.textColor
            visible: compact.backend.cameraInUse
                    && Plasmoid.configuration.showCameraIndicator
            source: "camera-web"
            fallback: "camera-video"
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
        }
        Kirigami.Icon {
            isMask: true
            color: Kirigami.Theme.textColor
            visible: compact.backend.microphoneInUse
                    && Plasmoid.configuration.showMicIndicator
            source: "microphone-sensitivity-high"
            fallback: "audio-input-microphone"
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
        }

        Kirigami.Icon {
            isMask: true
            color: Kirigami.Theme.textColor
            visible: Plasmoid.configuration.showNetworkIcon
            source: compact.backend.networkIcon
            fallback: "network-wireless"
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
        }
        Kirigami.Icon {
            isMask: true
            color: Kirigami.Theme.textColor
            visible: compact.backend.audioAvailable
                    && Plasmoid.configuration.showVolumeIcon
            source: compact.backend.volumeIcon
            fallback: "audio-volume-medium"
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
        }
        Kirigami.Icon {
            isMask: true
            color: Kirigami.Theme.textColor
            visible: compact.backend.hasBattery
                    && Plasmoid.configuration.showBatteryIcon
            source: compact.backend.batteryIcon
            fallback: "battery"
            Layout.preferredWidth: compact.iconSize
            Layout.preferredHeight: compact.iconSize
        }
        PlasmaComponents3.Label {
            visible: compact.backend.hasBattery && !compact.vertical
                    && Plasmoid.configuration.showBatteryIcon
                    && Plasmoid.configuration.showBatteryPercent
            text: compact.backend.batteryPercent + "%"
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
