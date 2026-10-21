/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Tray & Background Apps detail page.

    The stock plasma-workspace systemtray is a ContainmentItem and can't be
    embedded in another applet's popup.  This page mirrors its
    ExpandedRepresentation.qml by talking to the same D-Bus services the
    systemtray's private models wrap:

      - StatusNotifier items come from `org.kde.StatusNotifierWatcher` at
        `/StatusNotifierWatcher` on the session bus.  Clicking a row calls
        the item's `Activate(0, 0)` method, the same call the stock tray
        makes on a left-click.
      - Background apps come from `org.freedesktop.background.Monitor` at
        `/org/freedesktop/background/monitor`.  Clicking a row calls
        `OpenApp(app_id)` (bring the app to the front); the "Stop" button
        calls `StopApp(instance)` (terminate the background instance).

    All D-Bus calls go through `qs.sh` (run via the executable engine in
    Backend.qml).  If `busctl` is missing, or no SNI watcher is registered
    (no system tray running), the page shows the same placeholder messages
    the stock tray would.

    The SNI and Background Apps lists are rendered with ListView (not
    Repeater) so delegates get proper sizing inside the layout.  Each
    delegate uses the `index + modelData` pattern (no role-named required
    properties) to avoid FINAL/reserved-name collisions on ItemDelegate.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    readonly property bool hasSni: backend.traySniItems.length > 0
    readonly property bool hasBg: backend.trayBackgroundApps.length > 0

    Kirigami.PlaceholderMessage {
        visible: !page.backend.trayAvailable && !page.hasSni && !page.hasBg
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "network-disconnect"
        text: i18n("Tray unavailable")
        explanation: i18n("No StatusNotifier watcher is registered. Is the system tray applet running?")
    }

    Kirigami.PlaceholderMessage {
        visible: page.backend.trayAvailable && !page.hasSni && !page.hasBg
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "view-list-details"
        text: i18n("Nothing in the tray")
        explanation: i18n("StatusNotifier items and background apps will appear here.")
    }

    // One scroll area holding both sections.  Repeaters (not ListViews) so
    // nothing depends on ListView implicit sizing inside a layout.
    PlasmaComponents3.ScrollView {
        id: scroll
        visible: page.hasSni || page.hasBg
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing / 2

            // ---------------------------------------------- StatusNotifier items
            PlasmaComponents3.Label {
                visible: page.hasSni
                text: i18n("Tray icons")
                font.bold: true
                Layout.fillWidth: true
            }

            Repeater {
                model: page.backend.traySniItems

                delegate: PlasmaComponents3.ItemDelegate {
                    id: sniRow
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true

                    onClicked: page.backend.trayActivate(modelData.service, modelData.path)

                    // Right-click opens the app's OWN context menu directly
                    // (pin/unpin rides along as a footer entry of that menu,
                    // see SniMenu.withPinEntry) — no intermediate menu, like
                    // the stock tray.  Left-clicks fall through to onClicked.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.backend.trayContextMenu(
                            sniRow.modelData.service, sniRow.modelData.path, true, sniRow)
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            source: sniRow.modelData.icon || "application-x-executable"
                            fallback: "application-x-executable"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: sniRow.modelData.title || sniRow.modelData.service
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                visible: text.length > 0 && text !== sniRow.modelData.title
                                text: sniRow.modelData.tooltip || ""
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        PlasmaComponents3.ToolButton {
                            visible: !sniRow.modelData.isMenu
                            icon.name: "application-menu"
                            PlasmaComponents3.ToolTip.text: i18n("Open context menu")
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: page.backend.trayContextMenu(
                                sniRow.modelData.service, sniRow.modelData.path, false, sniRow)
                        }
                    }
                }
            }

            // ------------------------------------------------- Background apps
            PlasmaComponents3.Label {
                visible: page.hasBg
                text: i18n("Background apps")
                font.bold: true
                Layout.fillWidth: true
                Layout.topMargin: page.hasSni ? Kirigami.Units.largeSpacing : 0
            }

            Repeater {
                model: page.backend.trayBackgroundApps

                delegate: PlasmaComponents3.ItemDelegate {
                    id: bgRow
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true

                    onClicked: page.backend.trayOpenApp(bgRow.modelData.appId)

                    PlasmaComponents3.Menu {
                        id: bgContextMenu
                        PlasmaComponents3.MenuItem {
                            icon.name: "document-open"
                            text: i18n("Open")
                            onTriggered: page.backend.trayOpenApp(bgRow.modelData.appId)
                        }
                        PlasmaComponents3.MenuItem {
                            icon.name: "process-stop"
                            text: i18n("Stop")
                            onTriggered: page.backend.trayStopApp(bgRow.modelData.instance)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bgContextMenu.popup()
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            isMask: true
                            color: Kirigami.Theme.textColor
                            source: bgRow.modelData.appId || "application-x-executable"
                            fallback: "application-x-executable"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            PlasmaComponents3.Label {
                                text: bgRow.modelData.name || bgRow.modelData.appId
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                visible: (bgRow.modelData.message ?? "").length > 0
                                text: bgRow.modelData.message ?? ""
                                opacity: 0.7
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        PlasmaComponents3.ToolButton {
                            icon.name: "process-stop"
                            PlasmaComponents3.ToolTip.text: i18n("Stop this background app")
                            PlasmaComponents3.ToolTip.visible: hovered
                            onClicked: page.backend.trayStopApp(bgRow.modelData.instance)
                        }
                    }
                }
            }
        }
    }
}
