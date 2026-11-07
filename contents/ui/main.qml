/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // One icon cluster in the panel; the popup is the full representation.
    preferredRepresentation: compactRepresentation

    // While the mouse is over one of the per-app tray icons the applet
    // tooltip takes the tray icon's title/tooltip (shell-positioned above
    // the panel instead of a per-icon popup window).  The same applies to
    // the keyboard-layout indicator, where it shows the layout's full name.
    readonly property bool hoverTrayIcon: qsBackend.panelHoverSni !== ""
    readonly property bool hoverKeyboardLayout: qsBackend.panelHoverKeyboardLayout !== ""
    toolTipMainText: hoverTrayIcon
        ? qsBackend.panelHoverSni
        : hoverKeyboardLayout
            ? qsBackend.panelHoverKeyboardLayout
            : i18n("Quick Settings")
    toolTipSubText: hoverTrayIcon
        ? qsBackend.panelHoverSniTooltip
        : hoverKeyboardLayout
            ? ""
            : qsBackend.summary

    Backend {
        id: qsBackend
        popupOpen: root.expanded
    }

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
        backend: qsBackend
    }

    fullRepresentation: FullRepresentation {
        plasmoidItem: root
        backend: qsBackend
    }

    // Milestone 12: screen toasts.  Instantiated at the applet top level (not
    // inside the popup) so they show while the popup is closed too.
    NotificationToast {
        backend: qsBackend
    }
}
