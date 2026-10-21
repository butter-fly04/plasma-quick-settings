/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Power Mode detail page.  Mirrors powerdevil's batterymonitor applet
    (applets/batterymonitor/contents/ui/PowerProfileItem.qml):

      - the three profiles as a list of selectable rows
      - "Performance" is greyed out when the daemon has inhibited it
        (lap detected, high temperature) — exactly like the stock applet
        disables the right half of its slider
      - an inhibition hint explains *why* Performance is unavailable, with
        the same wording as PowerProfileItem.qml
      - profile holds (apps that requested a profile) are listed with their
        icon and reason
      - if power-profiles-daemon isn't installed, the page says so and points
        the user at their package manager — same as the stock applet

    All state comes from Backend.qml, which forwards it from
    PowerProfileBackend.qml (which is just a thin wrapper around powerdevil's
    PowerProfilesControl).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    // The three profiles in slider order (low → high).  Matches `profileData`
    // in powerdevil's PowerProfileItem.qml so the order, labels and the
    // "can-be-inhibited" flag agree with the stock applet.
    readonly property var profileData: [
        { profile: "power-saver", label: i18n("Power Save"),  icon: "battery-profile-powersave-symbolic",    canBeInhibited: false },
        { profile: "balanced",    label: i18n("Balanced"),    icon: "preferences-system-power-management",   canBeInhibited: false },
        { profile: "performance", label: i18n("Performance"), icon: "battery-profile-performance-symbolic",  canBeInhibited: true  }
    ]

    function inhibitionHint(reason) {
        switch (reason) {
        case "lap-detected":
            return i18n("Performance mode has been disabled to reduce heat generation because the computer has detected that it may be sitting on your lap.")
        case "high-operating-temperature":
            return i18n("Performance mode is unavailable because the computer is running too hot.")
        default:
            return i18n("Performance mode is unavailable.")
        }
    }
    function degradationHint(reason) {
        switch (reason) {
        case "lap-detected":
            return i18n("Performance may be lowered to reduce heat generation because the computer has detected that it may be sitting on your lap.")
        case "high-operating-temperature":
            return i18n("Performance may be reduced because the computer is running too hot.")
        default:
            return i18n("Performance may be reduced.")
        }
    }

    // Header: current profile name + a "configure" button
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label {
            text: page.backend.powerProfileAvailable
                ? i18n("Active profile: %1", page.backend.powerProfileLabel)
                : i18n("Power profiles unavailable")
            font.bold: true
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            PlasmaComponents3.ToolTip.text: i18n("Open Energy Settings")
            PlasmaComponents3.ToolTip.visible: hovered
            onClicked: page.backend.openPowerSettings()
        }
    }

    // --- not installed / not available ----------------------------
    Kirigami.PlaceholderMessage {
        visible: !page.backend.powerProfileAvailable
        Layout.fillWidth: true
        Layout.fillHeight: true
        icon.name: "speedometer"
        text: page.backend.powerProfileTlp
            ? i18n("The TLP service automatically controls power profiles")
            : i18n("Power profiles are not supported on your device.")
        explanation: page.backend.powerProfileTlp
            ? ""
            : i18n("Try installing the power-profiles-daemon package using your distribution's package manager and restarting the system.")
    }

    // --- profile list ---------------------------------------------
    ColumnLayout {
        visible: page.backend.powerProfileAvailable
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: page.profileData
            delegate: PlasmaComponents3.ItemDelegate {
                id: row
                required property var modelData
                required property int index

                Layout.fillWidth: true

                readonly property bool active: page.backend.powerProfile === modelData.profile
                // Performance may be inhibited; the other two are always available.
                readonly property bool disabled: modelData.canBeInhibited && page.backend.powerProfilePerformanceInhibited

                highlighted: active
                enabled: !disabled
                opacity: disabled ? 0.45 : 1.0
                onClicked: if (!disabled) page.backend.setPowerProfile(modelData.profile)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: row.modelData.icon
                        fallback: "speedometer"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        PlasmaComponents3.Label {
                            text: row.modelData.label
                            font.bold: row.active
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            visible: row.disabled
                            text: page.inhibitionHint(page.backend.powerProfileInhibitionReason)
                            color: Kirigami.Theme.negativeTextColor
                            opacity: 0.9
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                    // radio indicator on the right
                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        source: row.active ? "radiobutton-checked" : "radiobutton-unchecked"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        opacity: row.active ? 1 : 0.6
                    }
                }
            }
        }
    }

    // --- degradation hint (Performance is active but throttled) ---
    Rectangle {
        visible: page.backend.powerProfileAvailable
              && page.backend.powerProfile === "performance"
              && page.backend.powerProfileDegradationReason.length > 0
        Layout.fillWidth: true
        implicitHeight: degLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.smallSpacing
        color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

        PlasmaComponents3.Label {
            id: degLabel
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            text: page.degradationHint(page.backend.powerProfileDegradationReason)
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }

    // --- profile holds (apps that requested a specific profile) --
    // Same layout as PowerProfileItem.qml's inhibitionHoldersHint + Repeater:
    // a heading line ("1 application has requested activating Performance:")
    // followed by one row per hold with its icon and reason.
    ColumnLayout {
        visible: page.backend.powerProfileAvailable && page.backend.powerProfileHolds.length > 0
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.85
            text: {
                const holds = page.backend.powerProfileHolds
                if (holds.length === 0) return ""
                // The hold's "Profile" field says which profile the app asked for.
                const profileName = ({
                    "power-saver": i18n("Power Save"),
                    "balanced":    i18n("Balanced"),
                    "performance": i18n("Performance")
                })[holds[0].Profile] || holds[0].Profile
                return i18np("One application has requested activating %2:",
                             "%1 applications have requested activating %2:",
                             holds.length, profileName)
            }
        }

        Repeater {
            model: page.backend.powerProfileHolds
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    isMask: true
                    color: Kirigami.Theme.textColor
                    source: modelData.Icon || "application-x-executable"
                    fallback: "application-x-executable"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: modelData.Reason
                        ? i18nc("%1 is the app name, %2 is its reason",
                                "%1: %2", modelData.Name, modelData.Reason)
                        : modelData.Name
                }
            }
        }
    }

    Item { Layout.fillHeight: true }

    PlasmaComponents3.Button {
        text: i18n("Energy settings…")
        icon.name: "configure"
        Layout.alignment: Qt.AlignRight
        onClicked: page.backend.openPowerSettings()
    }
}
