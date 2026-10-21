/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Clipboard state, taken from Plasma itself instead of being re-implemented.

    plasma-workspace's clipboard applet (applets/clipboard/qml/main.qml) uses
    `org.kde.plasma.private.clipboard` with two QML types:

      - `HistoryModel` — wraps klipper's KDE D-Bus service
        (org.kde.klipper.klipper /klipper).  It exposes the clipboard history
        as a list (rows of `Uuid` + `Display` text + `Type`), plus
        `sourceCount`, `currentText`, `clipboardHasPassword`,
        `selectionHasPassword`.  The methods we use are:
            .clearHistory()
            .select(QVariant uuid)        — copy a row back to the clipboard
            .forget(QString uuid)         — delete one entry

      - `KlipperInterface` — a thin wrapper used by the stock applet for its
        "Configure Clipboard…" action.  We use it the same way.

    We instantiate the same model here so the Quick Settings clipboard page
    behaves exactly like the stock applet: same ordering (most recent first),
    same password masking, same action of clicking a row to copy it back to
    the clipboard.  Klipper writes to the actual X/Wayland clipboard
    selection, so anything you "select" here is then pasteable everywhere.

    If `org.kde.plasma.private.clipboard` isn't installed (a stripped-down
    Plasma build) the Loader in Backend.qml reports the failure and the
    clipboard tile stays hidden.
*/
import QtQuick
import org.kde.plasma.private.clipboard as Private

Item {
    id: root
    visible: false

    Private.KlipperInterface {
        id: klipper
    }

    Private.HistoryModel {
        id: historyModel
    }

    // ----------------------------------------------------- availability/state
    readonly property bool available: historyModel !== null
    readonly property bool empty: historyModel.sourceCount === 0
    readonly property int count: historyModel.sourceCount
    readonly property string currentText: historyModel.currentText
    // historyModel.sourceModel (Klipper's QMimeData-backed internal model)
    // is briefly null during construction, so every read has to tolerate
    // that — a plain `sourceModel.clipboardHasPassword` binding throws
    // "TypeError: Cannot read property 'clipboardHasPassword' of null"
    // into the journal on every popup open.
    readonly property bool clipboardHasPassword: historyModel.sourceModel?.clipboardHasPassword ?? false
    readonly property bool selectionHasPassword: historyModel.sourceModel?.selectionHasPassword ?? false
    // The model the UI iterates over (a `QAbstractListModel` with the roles
    // `Uuid`, `DisplayRole` (text), `Type`; see ClipboardPage.qml).
    readonly property alias model: historyModel

    // ---------------------------------------------------------- mutators
    // `moveToTop(uuid)` is klipper's "select" — it copies the entry back to
    // the clipboard (which also moves it to the top of the history).  This
    // is the same call the stock applet makes when you click a row.
    function select(uuid) {
        historyModel.moveToTop(uuid)
    }
    function remove(uuid) {
        historyModel.remove(uuid)
    }
    function clearHistory() {
        historyModel.clearHistory()
    }
    function configure() {
        klipper.configure()
    }
}
