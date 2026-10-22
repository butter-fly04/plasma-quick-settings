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

    toolTipMainText: i18n("Quick Settings")
    toolTipSubText: qsBackend.summary

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
