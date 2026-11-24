/*
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2026 Quick Settings contributors

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

    Adapted from plasma-workspace applets/notifications/components/JobDetails.qml.
    The file-manager context menu is left out (it comes from the stock applet's
    private QML plugin); the labels themselves are unchanged.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import org.kde.coreaddons as KCoreAddons


GridLayout {
    id: detailsGrid

    property var modelInterface

    readonly property var details: modelInterface && modelInterface.jobDetails
        ? modelInterface.jobDetails : null

    columns: 2
    rowSpacing: Math.round(Kirigami.Units.smallSpacing / 2)
    columnSpacing: Kirigami.Units.smallSpacing

    // once you use Layout.column/Layout.row *all* of the items in the Layout have to use them
    Repeater {
        model: [1, 2]

        PlasmaExtras.DescriptiveLabel {
            required property int index
            required property int modelData
            Layout.column: 0
            Layout.row: index
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            text: detailsGrid.details
                && detailsGrid.details["descriptionLabel" + modelData]
                && detailsGrid.details["descriptionValue" + modelData]
                ? i18nc("Row description, e.g. Source", "%1:", detailsGrid.details["descriptionLabel" + modelData]) : ""
            font: Kirigami.Theme.smallFont
            textFormat: Text.PlainText
            visible: text !== ""
        }
    }

    Repeater {
        model: [1, 2]

        PlasmaExtras.DescriptiveLabel {
            required property int index
            required property int modelData
            id: descriptionValueLabel
            Layout.column: 1
            Layout.row: index
            Layout.fillWidth: true
            font: Kirigami.Theme.smallFont
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            verticalAlignment: Text.AlignTop
            maximumLineCount: 5
            visible: text !== ""

            // Only let the label grow, never shrink, to avoid repeatedly resizing the dialog when copying many files
            onImplicitHeightChanged: {
                if (implicitHeight > Layout.preferredHeight) {
                    Layout.preferredHeight = implicitHeight;
                }
            }

            Component.onCompleted: bindText()
            function bindText() {
                text = Qt.binding(function() {
                    return detailsGrid.details
                        ? detailsGrid.details["descriptionValue" + modelData] || "" : "";
                });
            }
        }
    }

    Repeater {
        model: ["Bytes", "Files", "Directories", "Items"]

        PlasmaExtras.DescriptiveLabel {
            required property int index
            required property string modelData
            Layout.column: 1
            Layout.row: 2 + index
            Layout.fillWidth: true
            text: {
                if (!detailsGrid.details) {
                    return "";
                }

                let processed = detailsGrid.details["processed" + modelData];
                let total = detailsGrid.details["total" + modelData];

                if (processed > 0 || total > 1) {
                    // Format numbers to not display as exponential
                    // NOTE We use i18np to pick the correct plural but we don't want to show the number
                    // but our own, so we don't use the %1 placeholder!
                    const processedAsString = processed.toLocaleString(Qt.locale(), 'f', 0);
                    const totalAsString = total.toLocaleString(Qt.locale(), 'f', 0);

                    if (processed > 0 && total > 0 && processed <= total) {
                        switch(modelData) {
                        case "Bytes":
                            return i18nc("How many bytes have been copied", "%2 of %1",
                                KCoreAddons.Format.formatByteSize(total),
                                KCoreAddons.Format.formatByteSize(processed))
                        case "Files":
                            return i18ncp("How many files have been copied", "%3 of %2 file", "%3 of %2 files",
                                          total, totalAsString, processedAsString);
                        case "Directories":
                            return i18ncp("How many dirs have been copied", "%3 of %2 folder", "%3 of %2 folders",
                                         total, totalAsString, processedAsString);
                        case "Items":
                            return i18ncp("How many items (that includes files and dirs) have been copied", "%3 of %2 item", "%3 of %2 items",
                                         total, totalAsString, processedAsString);
                        }
                    } else {
                        const displayValue = processed ? processedAsString : totalAsString;
                        switch(modelData) {
                        case "Bytes":
                            return KCoreAddons.Format.formatByteSize(processed || total)
                        case "Files":
                            return i18np("%1 file", "%1 files", displayValue);
                        case "Directories":
                            return i18np("%1 folder", "%1 folders", displayValue);
                        case "Items":
                            return i18np("%1 item", "%1 items", displayValue);
                        }
                    }
                }

                return "";
            }
            font: Kirigami.Theme.smallFont
            textFormat: Text.PlainText
            visible: text !== ""
        }
    }

    PlasmaExtras.DescriptiveLabel {
        Layout.column: 1
        Layout.row: 2 + 4
        Layout.fillWidth: true
        text: detailsGrid.details && detailsGrid.details.speed > 0
            ? i18nc("Bytes per second", "%1/s", KCoreAddons.Format.formatByteSize(detailsGrid.details.speed))
            : ""
        font: Kirigami.Theme.smallFont
        textFormat: Text.PlainText
        visible: text !== "" && !(detailsGrid.modelInterface.percentage > 0 && detailsGrid.details.elapsedTime > 0) // SpeedChart should be visible then
    }
}
