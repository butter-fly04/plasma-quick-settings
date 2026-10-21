/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Input Method / On-Screen Keyboard detail page.  Mirrors plasma-workspace's
    manage-inputmethod applet (applets/manage-inputmethod/qml/main.qml):

      - a three-way mode picker (Disabled / Touch & Tablet / Touch, Tablet,
        Mouse, and Touchpad) — exactly the same PlasmaCore.ActionGroup the
        stock applet sets up as contextual actions
      - a "Show now" / "Hide" button (the stock applet's `Plasmoid.onActivated`
        state machine)
      - a "Configure On-Screen Keyboards…" button that opens
        `kcm_virtualkeyboard` (same KCMLauncher call the stock applet uses)

    The state comes from `org.kde.plasma.workspace.keyboardlayout.KWinVirtualKeyboard`,
    which is the same singleton the stock applet reads.  Toggling here has
    the same effect as clicking the tray icon.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    Kirigami.PlaceholderMessage {
        visible: !page.backend.inputMethodAvailable
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "input-keyboard-virtual-off-symbolic"
        text: i18n("On-Screen Keyboard unavailable")
        explanation: i18n("No on-screen keyboard backend is installed. Install maliit-keyboard or a compatible input method.")
    }

    // Active state + show/hide button
    Rectangle {
        visible: page.backend.inputMethodAvailable
        Layout.fillWidth: true
        implicitHeight: stateRow.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.largeSpacing
        color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

        RowLayout {
            id: stateRow
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                isMask: true
                color: Kirigami.Theme.textColor
                source: page.backend.inputMethodVisible
                    ? "input-keyboard-virtual-hide-symbolic"
                    : "input-keyboard-virtual-off-symbolic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents3.Label {
                    text: page.backend.inputMethodVisible
                        ? i18n("On-Screen Keyboard is visible")
                        : i18n("On-Screen Keyboard")
                    font.bold: true
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: page.backend.inputMethodModeLabel
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                }
            }
            PlasmaComponents3.Button {
                text: page.backend.inputMethodVisible
                    ? i18n("Hide")
                    : i18n("Show now")
                icon.name: page.backend.inputMethodVisible
                    ? "input-keyboard-virtual-hide-symbolic"
                    : "input-keyboard-virtual-show-symbolic"
                onClicked: page.backend.inputMethodToggle()
            }
        }
    }

    // Mode picker — mirrors the stock applet's contextualActions.
    PlasmaComponents3.Label {
        visible: page.backend.inputMethodAvailable
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        text: i18n("Automatic display")
        font.bold: true
    }
    ColumnLayout {
        visible: page.backend.inputMethodAvailable
        Layout.fillWidth: true
        spacing: 0

        // Three radio-button rows, same labels/icons as the stock applet.
        Repeater {
            model: [
                { value: page.backend.inputMethodModeNever, label: i18n("Disabled"), icon: "edit-none-symbolic" },
                { value: page.backend.inputMethodModeNonMouseInput, label: i18n("Touch and Tablet"), icon: "input-touchscreen-symbolic" },
                { value: page.backend.inputMethodModeAnyInput, label: i18n("Touch, Tablet, Mouse, and Touchpad"), icon: "input-mouse-symbolic" }
            ]
            delegate: PlasmaComponents3.ItemDelegate {
                required property var modelData
                Layout.fillWidth: true
                checked: page.backend.inputMethodMode === modelData.value
                onClicked: page.backend.inputMethodSetMode(modelData.value)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: modelData.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: modelData.label
                    }
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: page.backend.inputMethodMode === modelData.value
                            ? "radiobutton-checked" : "radiobutton-unchecked"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                }
            }
        }
    }

    Item { Layout.fillHeight: true }

    PlasmaComponents3.Button {
        visible: page.backend.inputMethodAvailable
        text: i18n("Configure On-Screen Keyboards…")
        icon.name: "settings-configure"
        Layout.alignment: Qt.AlignRight
        onClicked: page.backend.openInputMethodSettings()
    }
}
