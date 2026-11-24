/*
    SPDX-FileCopyrightText: 2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Quick Settings contributors

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL

    Adapted from plasma-workspace applets/notifications/components/JobItem.qml.
    Used for both the screen toast and the history row.  The stock component
    receives a ModelInterface from the notifications applet; this copy builds
    the same tiny interface from one NotificationManager.Notifications row.

    The stock applet's FileInfo/FileMenu helpers live in its private QML plugin
    and are not available here, so the file actions are reduced to the primary
    "Open" / "Open Containing Folder" button (plus Details, Pause and Cancel).
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import org.kde.notificationmanager as NotificationManager

ColumnLayout {
    id: jobItem

    // A JobType row from NotificationManager.Notifications.
    property var model

    signal suspendRequested()
    signal resumeRequested()
    signal killRequested()
    signal openRequested(url url)

    readonly property var jobDetails: model ? (model.jobDetails ?? null) : null
    readonly property int totalFiles: jobDetails ? (jobDetails.totalFiles || 0) : 0
    readonly property url destUrl: jobDetails ? jobDetails.effectiveDestUrl : ""

    // Subset of the stock applet's ModelInterface that the copied job widgets
    // use.  The signals keep the stock call sites unchanged.
    QtObject {
        id: modelInterface

        readonly property int jobState: jobItem.model && jobItem.model.jobState !== undefined
            ? jobItem.model.jobState
            : NotificationManager.Notifications.JobStateStopped
        readonly property int percentage: jobItem.model && jobItem.model.percentage !== undefined
            ? jobItem.model.percentage : 0
        readonly property int jobError: jobItem.model && jobItem.model.jobError !== undefined
            ? jobItem.model.jobError : 0
        readonly property bool suspendable: jobItem.model ? !!jobItem.model.suspendable : false
        readonly property bool killable: jobItem.model ? !!jobItem.model.killable : false
        readonly property var jobDetails: jobItem.jobDetails

        signal suspendJobClicked()
        signal resumeJobClicked()
        signal killJobClicked()
        signal openUrl(url url)
        signal fileActionInvoked(var action)

        onSuspendJobClicked: jobItem.suspendRequested()
        onResumeJobClicked: jobItem.resumeRequested()
        onKillJobClicked: jobItem.killRequested()
        onOpenUrl: (url) => jobItem.openRequested(url)
    }

    spacing: Kirigami.Units.smallSpacing

    NotificationJobSpeedChart {
        id: speedChart
        Layout.fillWidth: true
        modelInterface: modelInterface
        expanded: expandButton.checked
    }

    RowLayout {
        id: jobActionsRow
        Layout.fillWidth: true

        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Button {
            id: expandButton

            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth

            icon.name: checked ? "collapse-symbolic" : "expand-symbolic"
            text: i18nc("Hides/expands item details", "Details")
            checkable: jobItem.jobDetails && jobItem.jobDetails.hasDetails
            visible: checkable

            Accessible.onPressAction: if (checkable) toggle()
        }

        Item { Layout.fillWidth: true }

        PlasmaComponents3.Button {
            id: suspendButton

            readonly property bool paused: modelInterface.jobState === NotificationManager.Notifications.JobStateSuspended

            visible: modelInterface.suspendable

            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth

            icon.name: paused ? "media-playback-start-symbolic"
                              : "media-playback-pause-symbolic"
            text: paused ? i18nc("Resume paused job", "Resume")
                         : i18nc("Pause running job", "Pause")
            onClicked: paused ? modelInterface.resumeJobClicked()
                              : modelInterface.suspendJobClicked()
        }

        PlasmaComponents3.Button {
            id: killButton

            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth

            visible: modelInterface.killable

            icon.name: "dialog-cancel-symbolic"
            text: i18nc("Cancel running job", "Cancel")
            onClicked: modelInterface.killJobClicked()
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.preferredHeight: item ? (item as Item).implicitHeight : 0
        active: expandButton.checked
        // Loader doesn't reset its height when unloaded, just hide it altogether
        visible: active
        sourceComponent: NotificationJobDetails {
            modelInterface: modelInterface
        }
    }

    RowLayout {
        id: fileActionsRow
        Layout.fillWidth: true
        visible: jobItem.destUrl.toString() !== ""

        Item { Layout.fillWidth: true }

        PlasmaComponents3.Button {
            id: openButton

            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth

            text: jobItem.totalFiles === 1
                ? i18n("Open")
                : i18n("Open Containing Folder")
            icon.name: jobItem.totalFiles === 1 ? "" : "folder-open-symbolic"
            onClicked: modelInterface.openUrl(jobItem.destUrl)
        }
    }

    states: [
        State {
            when: modelInterface.jobState === NotificationManager.Notifications.JobStateSuspended
            PropertyChanges {
                speedChart.enabled: false
            }
        },
        State {
            when: modelInterface.jobState === NotificationManager.Notifications.JobStateStopped
            PropertyChanges {
                speedChart.visible: false
            }
            PropertyChanges {
                jobActionsRow.visible: false
            }
            PropertyChanges {
                expandButton.checked: false
            }
        }
    ]
}
