/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Battery detail page.  Mirrors powerdevil's batterymonitor applet
    (applets/batterymonitor/PopupDialog.qml + BatteryItem.qml):

      - a list of every primary battery on the system (the stock applet's
        BatteryControlModel is a QAbstractListModel — we use it directly)
      - each row shows: battery icon, pretty name ("Battery", "Battery 2",
        "UPS"), charge state ("Charging"/"Discharging"/"Fully Charged"/
        "Not present"), percent, progress bar
      - a "Battery Health" line per battery (from the Capacity role —
        <50% is flagged as "should be replaced", matching the stock applet)
      - a charge-stop-threshold hint when the user has set one (e.g.
        "Battery is configured to charge up to approximately 80%.")
      - a "Keep Display Awake" switch at the top — the same call the stock
        applet's middle-click makes (InhibitionControl.inhibit/uninhibit)
      - a "Configure Power Management…" button (opens kcm_powerdevilprofilesconfig)

    All state comes from Backend.qml, which forwards from BatteryBackend.qml
    (which wraps BatteryControlModel + InhibitionControl — same modules the
    stock applet uses).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

ColumnLayout {
    id: page

    required property var backend

    spacing: Kirigami.Units.smallSpacing

    // --- "Keep Display Awake" toggle (the stock applet's middle-click) ---
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: keepAwakeRow.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.largeSpacing
        color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

        RowLayout {
            id: keepAwakeRow
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                isMask: true
                color: Kirigami.Theme.textColor
                source: "video-television-symbolic"
                fallback: "preferences-system-power-management"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents3.Label {
                    text: i18n("Keep Display Awake")
                    font.bold: true
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: page.backend.batteryInhibited
                        ? i18n("Suppressing sleep and screen locking")
                        : i18n("Allow automatic sleep and screen locking")
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
            PlasmaComponents3.Switch {
                checked: page.backend.batteryInhibited
                onClicked: page.backend.batteryToggleInhibited()
            }
        }
    }

    // --- Charge-stop-threshold hint (e.g. "charges up to ~80%") ---
    Rectangle {
        visible: page.backend.batteryChargeStopThreshold > 0
                && page.backend.batteryChargeStopThreshold < 100
        Layout.fillWidth: true
        implicitHeight: thresholdLabel.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.largeSpacing
        color: Qt.alpha(Kirigami.Theme.textColor, 0.06)

        PlasmaComponents3.Label {
            id: thresholdLabel
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            wrapMode: Text.Wrap
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: i18n("Battery is configured to charge up to approximately %1%.",
                       page.backend.batteryChargeStopThreshold)
        }
    }

    // --- Combined / cumulative summary line (when multiple batteries) ---
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        PlasmaComponents3.Label {
            text: i18n("Overall")
            font.bold: true
            Layout.fillWidth: true
        }
        PlasmaComponents3.Label {
            text: {
                const parts = []
                parts.push(i18n("%1%", page.backend.batteryPercent))
                if (page.backend.charging)
                    parts.push(i18n("Charging"))
                else if (page.backend.batteryPluggedIn)
                    parts.push(i18n("Plugged in"))
                if (page.backend.batteryRemainingMsec > 0)
                    parts.push(KCoreAddons.Format.formatDuration(
                        page.backend.batteryRemainingMsec,
                        KCoreAddons.FormatTypes.HideSeconds))
                return parts.join(" · ")
            }
            opacity: 0.7
        }
    }

    // --- Per-battery list (BatteryControlModel is a QAbstractListModel) ---
    // Uses the safe `index + model` pattern (no role-named required properties)
    // to avoid FINAL/reserved-name collisions — same convention as every other
    // M5/M6 page.
    PlasmaComponents3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: list
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: page.backend.batteriesModel

            delegate: PlasmaComponents3.ItemDelegate {
                id: batteryRow
                required property int index
                required property var model

                width: ListView.view.width

                contentItem: RowLayout {
                    spacing: Kirigami.Units.gridUnit

                    Kirigami.Icon {
                        isMask: true
                        color: Kirigami.Theme.textColor
                        // Use the same percent→icon thresholds as the panel
                        // pill (from BatteryIcon.qml), with a charging suffix
                        // when the AC adapter is connected and this battery
                        // is a power-supply (primary) battery.
                        source: {
                            const p = Math.max(0, batteryRow.model.Percent ?? 0)
                            let name
                            if (p >= 95) name = "battery-100"
                            else if (p >= 85) name = "battery-090"
                            else if (p >= 75) name = "battery-080"
                            else if (p >= 65) name = "battery-070"
                            else if (p >= 55) name = "battery-060"
                            else if (p >= 45) name = "battery-050"
                            else if (p >= 35) name = "battery-040"
                            else if (p >= 25) name = "battery-030"
                            else if (p >= 15) name = "battery-020"
                            else if (p > 5)   name = "battery-010"
                            else              name = "battery-000"
                            if (page.backend.batteryPluggedIn
                                && (batteryRow.model.IsPowerSupply ?? false))
                                name += "-charging"
                            return name
                        }
                        fallback: "battery"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        Layout.alignment: Qt.AlignTop
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: batteryRow.model.PrettyName ?? i18n("Battery")
                            }
                            PlasmaComponents3.Label {
                                visible: (batteryRow.model.PluggedIn ?? false)
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    const p = batteryRow.model.Percent ?? -1
                                    return p >= 0 ? i18n("%1%", p) : i18n("Unknown")
                                }
                            }
                        }

                        PlasmaComponents3.ProgressBar {
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            visible: (batteryRow.model.PluggedIn ?? false)
                                    && (batteryRow.model.Percent ?? -1) >= 0
                            value: batteryRow.model.Percent ?? 0
                        }

                        // Charge state label (Charging/Discharging/...).
                        // Same wording as powerdevil's BatteryItem.qml.
                        PlasmaComponents3.Label {
                            visible: text.length > 0
                            opacity: 0.75
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            text: {
                                const pluggedIn = batteryRow.model.PluggedIn ?? false
                                if (!pluggedIn) return i18nc("Battery is currently not present in the bay", "Not present")
                                // ChargeState is an int: 0=NoCharge,1=Charging,2=Discharging,3=FullyCharged
                                switch (batteryRow.model.ChargeState) {
                                case 1: return i18n("Charging")
                                case 2: return i18n("Discharging")
                                case 3: return i18n("Fully Charged")
                                default: return i18n("Not Charging")
                                }
                            }
                        }

                        // Battery health (Capacity role, 0..100).
                        // <50% is flagged as "should be replaced" — same rule
                        // as powerdevil's BatteryItem.qml isBroken check.
                        PlasmaComponents3.Label {
                            visible: (batteryRow.model.IsPowerSupply ?? false)
                                    && (batteryRow.model.Capacity ?? 0) > 0
                            opacity: 0.75
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: (batteryRow.model.Capacity ?? 100) < 50
                                ? Kirigami.Theme.negativeTextColor
                                : Kirigami.Theme.textColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            text: (batteryRow.model.Capacity ?? 100) < 50
                                ? i18n("This battery's health is at only %1% and it should be replaced. Contact the manufacturer.",
                                       batteryRow.model.Capacity)
                                : i18nc("Placeholder is battery health percentage", "Battery Health: %1%",
                                        batteryRow.model.Capacity)
                        }
                    }
                }
            }
        }
    }

    PlasmaComponents3.Button {
        text: i18n("Configure Power Management…")
        icon.name: "configure"
        Layout.alignment: Qt.AlignRight
        onClicked: page.backend.openPowerSettings()
    }
}
