/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notification screen toasts (Milestone 12).

    This system ships plasma-workspace without the stock "Notifications"
    applet, so nothing shows pop-up notifications (the daemon queues them;
    no applet owns the toast windows).  This component provides them:

      - a PlasmaCore.Dialog in the top-right screen corner (the stock
        default corner), stacking the toast rows of the currently shown
        notifications from Backend.notifToastModel
      - each row has the app icon + name, summary/body, relative time,
        the notification's action buttons, and a close button; clicking
        the row body invokes the default action (same as the stock popup)

    The stock applet makes one window per toast and stacks them with a
    private C++ PopupPositioner; we stack rows inside one window instead —
    same look, no repositioning engine needed.  Rows disappear whenever
    the model drops them: the daemon's own timeouts expire notifications
    (showExpired:false), and any action invokes with InvokeBehavior.Close.

    Toasts respect Do Not Disturb (only critical remain, per stock
    Globals.qml urgencies logic) and the pop-up app blacklist: see
    backends/NotificationPopupBackend.qml.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

PlasmaCore.Dialog {
    id: toastDialog

    required property var backend

    // Because this dialog is re-parented to nothing special, location is
    // handled manually in position(); Floating means "arbitrary x/y, don't
    // snap to a panel edge".
    location: PlasmaCore.Types.Floating
    // The stock toasts live in KWin's dedicated notification layer (always
    // on top, never focused).  WindowStaysOnTopHint approximates that layer
    // without a KWin dependency; DoesNotAcceptFocus avoids keyboard grabs.
    flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint

    // Rely on the count only: gating visibility on the ling geometry is a
    // deadlock — an invisible dialog never runs layout polish, so the height
    // gate could never open (first toast never shows).  Instead the mainItem
    // below reserves a nonzero height so the very first show is never the
    // "trying to show an empty dialog" refusal.
    visible: Plasmoid.configuration.showNotificationPopups
        && backend.notifToastCount > 0
    onVisibleChanged: {
        if (visible) position()
    }

    // Toast width ~ the stock popup's default (350px-ish); the height
    // follows the stacked content.
    readonly property int toastWidth: Kirigami.Units.gridUnit * 20

    function position() {
        // Screen reflects the toast window's screen; the fallbacks keep
        // unhosted contexts (plasmoidviewer) from collapsing x/y to 0.
        const availW = Screen.desktopAvailableWidth || Screen.width || 1920
        const availH = Screen.desktopAvailableHeight || Screen.height || 1080
        x = availW - width - sideMargin
        y = (Screen.height - availH) + sideMargin
    }
    onWidthChanged: if (visible) position()
    onHeightChanged: if (visible) position()

    readonly property int sideMargin: Kirigami.Units.gridUnit / 2

    // Reserved minimum height for the stack: nonzero whenever the toast
    // becomes visible, so the dialog never refuses the first show; the
    // layout then grows/shrinks it with the stacked rows.
    readonly property real stackHeight:
        Math.max(Kirigami.Units.gridUnit * 3, notifList.contentHeight
            + 2 * Kirigami.Units.smallSpacing)

    // Main item is a plain (non-Layout) Item with explicit size: PlasmaCore.Dialog
    // sizes its window from the mainItem's width/height — layouts keep
    // overriding their own explicit width during implicit-size settling and
    // then the window ends up wider/narrower than the content (the user's
    // report: text/labels not filling the popup horizontally, floating
    // labels overlapping the app icon).
    mainItem: Item {
        id: toastContent
        width: toastDialog.toastWidth
        height: toastDialog.stackHeight

        // Rows of the currently-shown notifications.  The view itself
        // never scrolls: the daemon expires rows over time, and the
        // popup limit (12) keeps the stack bounded.  Height follows the
        // content so the dialog window sizes to the stack.
        ListView {
            id: notifList
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            interactive: false
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: toastDialog.backend.notifToastModel

            delegate: Rectangle {
                id: toastRow

                required property int index
                required property var model

                // True when no app-provided icon exists and the symbolic
                // bell fallback is used (needs isMask coloring).
                readonly property bool isFallbackIcon:
                    !(model.iconName ?? "") && !(model.applicationIconName ?? "")

                width: notifList.width
                height: rowLayout.implicitHeight
                    + 2 * Kirigami.Units.smallSpacing
                radius: Kirigami.Units.cornerRadius

                // Each notification is its own boxed card: a subtle fill
                // slightly lighter than the dialog background; hover
                // brightens it.
                color: toastRowArea.containsMouse
                    ? Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
                    : Qt.alpha(Kirigami.Theme.backgroundColor, 0.6)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.10)

                MouseArea {
                    id: toastRowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: toastRow.model.hasDefaultAction
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (toastRow.model.hasDefaultAction)
                            toastDialog.backend.notifToastInvokeDefault(toastRow.index)
                    }
                }

                RowLayout {
                    id: rowLayout
                    x: Kirigami.Units.smallSpacing
                    y: Kirigami.Units.smallSpacing
                    width: toastRow.width - 2 * Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.largeSpacing

                    // Notification icon: the notification's own image/icon
                    // or the app icon; NO icon at all when neither provides
                    // one (the default bell artwork reads badly).
                    Kirigami.Icon {
                        visible: !toastRow.isFallbackIcon
                        source: (toastRow.model.iconName ?? "")
                            || (toastRow.model.applicationIconName ?? "")
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.alignment: Qt.AlignTop
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing / 2
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            // App name + relative time on top — same two
                            // lines the stock popup shows.  The app name
                            // stretches, so time + close sit at the
                            // card's right edge.
                            PlasmaComponents3.Label {
                                text: toastRow.model.applicationName ?? ""
                                font.bold: true
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                opacity: 0.85
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Label {
                                text: {
                                    const created = toastRow.model.created
                                    if (!created) return ""
                                    try {
                                        return KCoreAddons.Format.formatRelativeDateTime(created, Locale.ShortFormat)
                                    } catch (e) { return "" }
                                }
                                opacity: 0.6
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                            // Explicit close (the X). _visible always: any
                            // notification can be closed.
                            PlasmaComponents3.ToolButton {
                                icon.name: "window-close"
                                PlasmaComponents3.ToolTip.text: i18n("Close notification")
                                PlasmaComponents3.ToolTip.visible: hovered
                                onClicked: toastDialog.backend.notifToastClose(toastRow.index)
                            }
                        }

                        PlasmaComponents3.Label {
                            visible: (toastRow.model.display ?? "").length > 0
                            text: toastRow.model.display ?? ""
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            visible: (toastRow.model.body ?? "").length > 0
                            text: toastRow.model.body ?? ""
                            opacity: 0.85
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            Layout.fillWidth: true
                        }

                        // Notification action buttons (replies/accept/reject),
                        // styled like the stock popup's footer buttons.
                        RowLayout {
                            visible: (toastRow.model.actionLabels ?? []).length > 0
                            spacing: Kirigami.Units.smallSpacing
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing / 2

                            Repeater {
                                model: toastRow.model.actionLabels ?? []
                                delegate: PlasmaComponents3.Button {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    onClicked: {
                                        const names = toastRow.model.actionNames ?? []
                                        if (index < names.length) {
                                            toastDialog.backend.notifToastInvokeAction(
                                                toastRow.index, names[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
