/*
    SPDX-License-Identifier: GPL-2.0-or-later

    GNOME-style pill toggle: [icon  Title / subtitle  |>]
    The arrow part only exists when `expandable` is true and opens a detail page.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: tile

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool expandable: false
    // False for features that aren't connected to the system yet: the tile is
    // dimmed and ignores clicks, so it never shows made-up state as real.
    property bool wired: true

    signal toggled()
    signal expanded()

    enabled: wired
    opacity: wired ? 1 : 0.45

    implicitHeight: Kirigami.Units.gridUnit * 3
    implicitWidth: Kirigami.Units.gridUnit * 10

    readonly property color fillColor: active
        ? Kirigami.Theme.highlightColor
        : Qt.alpha(Kirigami.Theme.textColor, 0.1)
    readonly property color contentColor: active
        ? Kirigami.Theme.highlightedTextColor
        : Kirigami.Theme.textColor

    // Main pill
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: tile.fillColor
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    }

    // Left part: toggles the feature
    MouseArea {
        id: mainArea
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            right: tile.expandable ? arrowArea.left : parent.right
        }
        hoverEnabled: true
        onClicked: tile.toggled()

        Rectangle {
            anchors.fill: parent
            radius: pill.radius
            color: tile.contentColor
            opacity: mainArea.pressed ? 0.18 : (mainArea.containsMouse ? 0.08 : 0)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                isMask: true
                source: tile.icon
                color: tile.contentColor
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: tile.title
                    color: tile.contentColor
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: tile.subtitle.length > 0
                    text: tile.subtitle
                    color: tile.contentColor
                    opacity: 0.8
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    // Right part: opens the detail page
    MouseArea {
        id: arrowArea
        visible: tile.expandable
        width: Kirigami.Units.gridUnit * 2.5
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        hoverEnabled: true
        onClicked: tile.expanded()

        Rectangle {
            anchors.fill: parent
            radius: pill.radius
            color: tile.contentColor
            opacity: arrowArea.pressed ? 0.25 : (arrowArea.containsMouse ? 0.15 : 0.08)
        }
        Kirigami.Icon {
            isMask: true
            anchors.centerIn: parent
            source: "go-next"
            color: tile.contentColor
            width: Kirigami.Units.iconSizes.small
            height: width
        }
    }
}
