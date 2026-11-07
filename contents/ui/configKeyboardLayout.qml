/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Config tab: keyboard layout indicator.

    Mirrors the stock keyboard-layout applet's settings: the same three
    display styles (layout name / flag / flag with name badge) plus a
    show/hide switch for each of this applet's two placements (panel icon
    and popup pill).

    `cfg_<key>` properties are auto-bound to the "General" group in
    contents/config/main.xml by the Plasma config framework.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property bool cfg_showKeyboardLayoutPanel
    property bool cfg_showKeyboardLayoutPill
    property int cfg_keyboardLayoutDisplayStyle

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Keyboard layout")
            text: i18n("Show in the panel")
            checked: cfg_showKeyboardLayoutPanel
            onToggled: cfg_showKeyboardLayoutPanel = checked
        }
        QQC2.CheckBox {
            text: i18n("Show as a pill in the popup")
            checked: cfg_showKeyboardLayoutPill
            onToggled: cfg_showKeyboardLayoutPill = checked
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Display style:")
            model: [
                i18n("Layout name"),
                i18n("Flag"),
                i18n("Flag with layout name")
            ]
            currentIndex: cfg_keyboardLayoutDisplayStyle
            onActivated: cfg_keyboardLayoutDisplayStyle = currentIndex
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.8
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: i18n("Clicking the indicator opens the list of layouts, in both the panel and the popup. Scrolling switches layouts.")
        }
    }
}
