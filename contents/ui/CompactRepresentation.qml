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

                // Same size as the unified icons and no internal padding:
                // the icon fills the whole tile (the user asked for "as big
                // as possible", the artwork becomes the entire glyph).
                Layout.preferredWidth: compact.iconSize
                Layout.preferredHeight: compact.iconSize

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
                        // Like the stock tray: right-click always opens the
                        // item's own menu, and a left-click does the same for
                        // menu-only items (ItemIsMenu) — those have no
                        // Activate action to call.
                        if (mouse.button === Qt.RightButton
                                || panelSni.modelData.isMenu) {
                            compact.backend.trayContextMenu(
                                panelSni.modelData.service,
                                panelSni.modelData.path, false, panelSni)
                        } else {
                            compact.backend.trayActivate(
                                panelSni.modelData.service,
                                panelSni.modelData.path, panelSni)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Kirigami.Theme.textColor
                        opacity: panelSniArea.pressed ? 0.15 : 0
                    }

                    // The stock tray icon "bounces": the glyph shrinks to
                    // 80 % while the button is held (AbstractItem.qml) and
                    // springs back on release.  Scaling only the icon (not
                    // the hover background) matches that.
                    Item {
                        id: iconHolder
                        anchors.fill: parent
                        scale: panelSniArea.pressed ? 0.8 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: panelSniArea.pressed
                                    ? Easing.OutCubic : Easing.InCubic
                            }
                        }

                        Kirigami.Icon {
                            anchors.fill: parent
                            source: panelSni.modelData.icon || "application-x-executable"
                            fallback: "application-x-executable"
                        }
                    }

                    // The applet-level tooltip (positioned by the shell,
                    // correctly above the panel) shows the tray icon's
                    // title/tooltip while hovering; no per-icon ToolTip
                    // window (its placement anchored wrong next to panels).
                    // See main.qml: toolTipMainText/SubText swap while
                    // panelHoverSni is set.
                }
            }
        }

        // Keyboard layout, rendered like a separate system-tray icon: the
        // stock keyboard-layout applet's flag/name face, clickable to pick a
        // layout and scrollable to switch.  Config: Keyboard Layout tab.
        KeyboardLayoutIndicator {
            id: panelKeyboardLayout
            visible: Plasmoid.configuration.showKeyboardLayoutPanel
                && panelKeyboardLayout.hasLayouts
            displayStyle: Plasmoid.configuration.keyboardLayoutDisplayStyle
            iconSize: compact.iconSize

            // Only one tooltip: while hovered, the applet-level tooltip (which
            // the panel positions above it) shows the full layout name instead
            // of the Quick Settings summary.  The indicator's own tooltip is
            // pill-only for that reason.
            onHoveredChanged: compact.backend.setPanelKeyboardLayoutHover(
                hovered ? layoutNames.longName : "")
            onLayoutNamesChanged: {
                if (hovered)
                    compact.backend.setPanelKeyboardLayoutHover(layoutNames.longName)
            }
            onVisibleChanged: {
                if (!visible)
                    compact.backend.setPanelKeyboardLayoutHover("")
            }
            Component.onDestruction: {
                if (compact.backend)
                    compact.backend.setPanelKeyboardLayoutHover("")
            }
        }

        // Small visual gap between the tray icon cluster and the
        // applet's own unified icons (the grid already separated them,
        // so this is just the little bit more the user asked for).
        Item {
            Layout.preferredWidth: compact.vertical
                ? 0 : Kirigami.Units.smallSpacing
            Layout.preferredHeight: compact.vertical
                ? Kirigami.Units.smallSpacing : 0
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
        // Battery: NOT rendered as a mask.  The stock applet's icon
        // (components/workspace/BatteryIcon.qml) uses Kirigami.Icon
        // directly, which keeps the Breeze "-charging" variant's coloured
        // interior (ColorScheme-PositiveText, blue/green in the default
        // themes) visible — the white-on-white mask made charging and
        // discharging look identical.
        Kirigami.Icon {
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
