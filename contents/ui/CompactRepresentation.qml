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
    // Per-app tray icons render slightly larger: like the stock tray they
    // carry meaningful color artwork, and a bit more pixels helps legibility.
    readonly property int trayIconSize: Math.round(compact.iconSize * 1.15)

    // Tray apps minus the ones hidden from the panel (still listed in the
    // popup).  Keyed by "service|path" so items moving around don't unhide.
    readonly property var panelSniItems: {
        const hidden = Plasmoid.configuration.hiddenPanelSni || []
        return (compact.backend.traySniItems || []).filter(s =>
            hidden.indexOf(s.service + "|" + s.path) === -1)
    }

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

        // Milestone 12: every tray app as its own clickable panel icon, like
        // the stock system tray — placed LEFT of the applet's own icons.
        // Rendered in real colours (no isMask) — tray app icons are
        // meaningful artwork, status indicators.  Left-click activates the
        // item, right-click opens its own context menu.
        Repeater {
            model: Plasmoid.configuration.showPanelTrayIcons
                ? compact.panelSniItems : 0

            delegate: Item {
                id: panelSni

                required property int index
                required property var modelData

                Layout.preferredWidth: compact.trayIconSize
                Layout.preferredHeight: compact.trayIconSize

                MouseArea {
                    id: panelSniArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    // While hovering a tray icon the applet tooltip is
                    // suppressed (main.qml binds toolTipMainText/SubText to
                    // empty) and only the icon's own tooltip shows.
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            const title = (panelSni.modelData.title || "").split("\n")[0]
                            compact.backend.setPanelSniHover(
                                title, panelSni.modelData.tooltip || "")
                        } else {
                            compact.backend.clearPanelSniHover()
                        }
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            // Own menu, like the stock tray on right-click;
                            // the icon item is the anchor so the menu opens
                            // next to this icon.
                            compact.backend.trayContextMenu(
                                panelSni.modelData.service,
                                panelSni.modelData.path, false, panelSni)
                        } else {
                            compact.backend.trayActivate(
                                panelSni.modelData.service,
                                panelSni.modelData.path)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Kirigami.Theme.textColor
                        opacity: panelSniArea.pressed ? 0.25 : (panelSniArea.containsMouse ? 0.12 : 0)
                    }

                    Kirigami.Icon {
                        anchors.fill: parent
                        anchors.margins: height * 0.08
                        source: panelSni.modelData.icon || "application-x-executable"
                        fallback: "application-x-executable"
                    }

                    PlasmaComponents3.ToolTip.text: panelSni.modelData.title || ""
                    PlasmaComponents3.ToolTip.visible: panelSniArea.containsMouse
                }
            }
        }

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
