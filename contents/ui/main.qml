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
    // tooltip is suppressed entirely (both fields empty) so only the
    // tray icon's own tooltip window shows.
    readonly property bool hoverTrayIcon: qsBackend.panelHoverSni !== ""
    toolTipMainText: hoverTrayIcon ? "" : i18n("Quick Settings")
    toolTipSubText: hoverTrayIcon ? "" : qsBackend.summary

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
