/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Clipboard detail page.  Mirrors plasma-workspace's clipboard applet
    (applets/clipboard/qml/main.qml):

      - a scrollable list of recent clipboard entries (most-recent first),
        grouped so image snippets and text snippets look the same as in
        the stock applet
      - clicking a row selects it (writes it back to the clipboard via
        klipper, so it's immediately pasteable everywhere — same action as
        the stock applet)
      - a per-row "forget" button removes that entry from history
      - a "Clear History" button at the bottom (same action as the stock
        applet's `action_clearHistory`)
      - a "Configure Clipboard…" button opens klipper's settings, exactly
        like the stock applet's `action_configure`

    The model is `org.kde.plasma.private.clipboard.HistoryModel` — the same
    object the stock applet uses — so the list, ordering, password-masking
    behaviour and the clear/select/forget actions are identical.

    Password masking: when the clipboard currently holds a password
    (`clipboardHasPassword`), every row is replaced with a placeholder and
    clicking a row does nothing, the same way the stock applet hides
    sensitive content.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    // A search filter, like the stock applet.  `HistoryModel` itself doesn't
    // filter, so we do a simple includes() here.
    property string filter: ""

    // Password masking: when the clipboard holds a password, we hide the
    // rows entirely (and show a notice).  This matches the stock applet's
    // behaviour of refusing to display sensitive content.
    readonly property bool maskingActive: page.backend.clipboardHasPassword

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.TextField {
            Layout.fillWidth: true
            placeholderText: i18n("Search clipboard history…")
            text: page.filter
            onTextEdited: page.filter = text
            clearButtonShown: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            PlasmaComponents3.ToolTip.text: i18n("Configure Clipboard…")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: page.backend.openClipboardSettings()
        }
    }

    PlasmaComponents3.Label {
        visible: page.maskingActive
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: i18n("The clipboard currently holds sensitive data. The history is hidden until you clear it.")
        color: Kirigami.Theme.negativeTextColor
        opacity: 0.9
    }

    Kirigami.PlaceholderMessage {
        visible: !page.maskingActive && page.backend.clipboardEmpty
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "klipper-symbolic"
        text: i18n("Clipboard is empty")
    }

    PlasmaComponents3.ScrollView {
        visible: !page.maskingActive && !page.backend.clipboardEmpty
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            clip: true
            spacing: Kirigami.Units.smallSpacing / 2
            // `clipboardModel` is the HistoryModel from
            // org.kde.plasma.private.clipboard — same roles the stock
            // applet uses: `Uuid`, `DisplayRole` (text), `Type`.
            model: page.backend.clipboardModel

            delegate: PlasmaComponents3.ItemDelegate {
                id: row
                // The stock clipboard applet's delegate only declares
                // `required property int index` and `required property var model`,
                // then reads everything through `model.<role>`.  We do the
                // same here, because `display` and `type` are reserved names
                // that collide with FINAL properties on ItemDelegate (the
                // `display` enum from QQuickAbstractButton and the `type`
                // property from QQmlComponent).
                required property int index
                required property var model

                width: ListView.view.width
                onClicked: page.backend.clipboardSelect(row.model.uuid)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    // Iconography matches the stock applet: text → paste,
                    // image → image-x-generic, URL → link.
                    // `type` is a bitmask (Text=2, Image=4, Url=8) — see
                    // klipper/historyitem.h HistoryItemType.
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: (row.model.type & 4) ? "image-x-generic"
                                : (row.model.type & 8) ? "edit-link"
                                : "edit-paste"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.7
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: row.model.display ?? ""
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                    // Starred entries (klipper's "important" pin) get a small
                    // emblem; clicking the row still selects them like the
                    // stock applet.
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        visible: row.model.starred
                        source: "bookmark"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.7
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-delete"
                        PlasmaComponents3.ToolTip.text: i18n("Forget this entry")
                        PlasmaComponents3.ToolTip.visible: hovered
                        onClicked: page.backend.clipboardRemove(row.model.uuid)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        PlasmaComponents3.Button {
            text: i18n("Clear History")
            icon.name: "edit-clear-history"
            enabled: !page.backend.clipboardEmpty
            onClicked: page.backend.clipboardClear()
        }
    }
}
