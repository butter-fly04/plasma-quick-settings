/*
    SPDX-License-Identifier: GPL-2.0-or-later

    SNI-as-pill: render a chosen StatusNotifierItem as a QuickTile-style pill
    in the main grid (instead of forcing the user to open the Tray page to
    reach it).

    The user picks which SNIs to pin via the config page (Plasmoid.configuration.
    pinnedSnis is a string list of "service|path" pairs); Backend.qml matches
    those against the live SNI list and exposes `pinnedSniItems` (a list of
    the resolved SNI objects).  Each SniTile is bound to one such object.

    Click the pill's main area → SNI Activate(0, 0) (same call the stock tray
    makes on a left-click).
    Click the pill's right arrow → SNI ContextMenu(0, 0) (same call the stock
    tray makes on a right-click).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: tile

    // A single SNI object, injected by the Repeater as in the stock Tray
    // page: the delegate declares `required property var modelData` itself
    // (same pattern as TrayPage.qml's rows — TrayPage.qml's header comment
    // explains why).  Binding it from outside as `sni: modelData` left the
    // property undefined in the deployed applet: pills rendered empty (no
    // icon, no title) and their menu arrows did nothing.
    required property int index
    required property var modelData

    // Fields of the SNI object from Backend.pillSniItems:
    //   title, icon, tooltip, isMenu, service, path
    readonly property var sni: modelData
    required property var backend

    signal activated()
    signal menuRequested()

    // The pill shows one line: titles can be multiline ("IBus Panel\n…"),
    // the pill only has room for the first line.
    readonly property string pillTitle: (sni.title || sni.service || "").split("\n")[0]
    readonly property string pillTooltip: sni.tooltip || ""

    implicitHeight: Kirigami.Units.gridUnit * 3
    implicitWidth: Kirigami.Units.gridUnit * 10

    readonly property color fillColor: Qt.alpha(Kirigami.Theme.textColor, 0.1)
    readonly property color contentColor: Kirigami.Theme.textColor

    // Main pill background.
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: tile.fillColor
    }

    // Left part: clicking it activates the SNI.
    MouseArea {
        id: mainArea
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            right: arrowArea.left
        }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Menu-only items have no Activate action: fall back to the
            // right-click action (open the item's menu), like the stock
            // tray's `ItemIsMenu ? openContextMenu : activate`.
            if (tile.sni.isMenu) {
                tile.menuRequested()
                tile.backend.trayContextMenu(tile.sni.service, tile.sni.path,
                                             false, tile)
                return
            }
            tile.activated()
            tile.backend.trayActivate(tile.sni.service, tile.sni.path, tile)
        }

        Rectangle {
            anchors.fill: parent
            radius: pill.radius
            color: tile.contentColor
            opacity: mainArea.pressed ? 0.18 : (mainArea.containsMouse ? 0.08 : 0)
        }

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // Same press-bounce the stock tray has.
            scale: mainArea.pressed ? 0.92 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: mainArea.pressed ? Easing.OutCubic : Easing.InCubic
                }
            }

            Kirigami.Icon {
                isMask: true
                source: tile.sni.icon || "application-x-executable"
                fallback: "application-x-executable"
                color: tile.contentColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: tile.pillTitle
                    color: tile.contentColor
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: tile.pillTooltip.length > 0 && tile.pillTooltip !== tile.pillTitle
                    text: tile.pillTooltip
                    color: tile.contentColor
                    opacity: 0.8
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    // Right part: opens the SNI's context menu (only shown for SNIs that
    // have one — i.e. ItemIsMenu is false).
    MouseArea {
        id: arrowArea
        visible: !tile.sni.isMenu
        width: visible ? Kirigami.Units.gridUnit * 2.5 : 0
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            tile.menuRequested()
            tile.backend.trayContextMenu(tile.sni.service, tile.sni.path, false, arrowArea)
        }

        Rectangle {
            anchors.fill: parent
            radius: pill.radius
            color: tile.contentColor
            opacity: arrowArea.pressed ? 0.25 : (arrowArea.containsMouse ? 0.15 : 0.08)
        }
        Kirigami.Icon {
            isMask: true
            anchors.centerIn: parent
            source: "application-menu"
            color: tile.contentColor
            width: Kirigami.Units.iconSizes.small
            height: width
        }
    }
}
