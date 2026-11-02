/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Live StatusNotifier list.

    The stock system tray does not poll: `StatusNotifierItemHost` keeps a
    QObject per tray item on the session bus and the applet renders a model
    that is updated by D-Bus signals.  `StatusNotifierModel` is that model,
    and plasma-workspace exports it to QML for plasma-mobile
    (`QML_ELEMENT`, documented "exported to QML for plasma-mobile"), so we
    can instantiate it from this applet too.  Every NewIcon / NewTitle /
    NewStatus / NewToolTip signal (and item add/remove) reaches the model
    immediately, which makes the panel icons and the Tray page update at
    exactly the same instant the stock tray does — no polling, no
    subprocesses, no cache file.

    The rest of the plasmoid consumes plain arrays of
    `{title, icon, tooltip, isMenu, service, path}` objects (the shape the
    old `qs.sh traypoll` parser produced), so this bridge flattens the
    model back into that shape:

      - a hidden Repeater creates one zero-sized delegate per model row;
      - each delegate's bindings track the roles it needs, so a
        `dataChanged` for that row re-evaluates them;
      - on any change the delegate writes its current values into `rows`
        (keyed by DataEngineSource) and asks for one rebuild, which emits
        a fresh sorted `sniItems` array.

    `DataEngineSource` is "service/path" (the string the watcher stores).
    The service is everything before the first "/", the path everything
    from that "/".  Click actions still go through qs.sh, which needs the
    two parts separately.

    Only instantiated from TrayBackend.qml behind a Loader: if this private
    module is missing (non-Plasma system, future rename), the Loader fails
    and the old qs.sh polling path takes over.

    NOTE: never read the model's `effectiveStatus` role from here.  Its
    C++ implementation dereferences the optional SystemTraySettings, which
    is null for the default-constructed model exported to QML (the stock
    applet always passes settings).  `status` is safe; `effectiveStatus`
    crashes.  This bridge only uses Title / ToolTipTitle /
    ToolTipSubTitle / Icon / IconName / ItemIsMenu / Status /
    DataEngineSource.
*/
import QtQuick
import org.kde.plasma.private.systemtray as SystemTrayPrivate

Item {
    id: bridge
    visible: false

    // True once the C++ model object exists (the QML module loaded).
    property bool ready: false
    // Flattened, index-sorted rows — the shape the rest of the applet uses.
    property var sniItems: []

    readonly property int count: sniItems.length

    // DataEngineSource -> row.  A JS object (not a QML list property) so
    // writing one key does not rebuild everything by itself; rebuild() is
    // batched through Qt.callLater instead.
    property var rows: ({})
    property bool rebuildQueued: false

    function queueRebuild() {
        if (rebuildQueued)
            return
        rebuildQueued = true
        Qt.callLater(rebuild)
    }

    function rebuild() {
        rebuildQueued = false
        const list = []
        for (const key in rows)
            list.push(rows[key])
        list.sort((a, b) => a.index - b.index)
        sniItems = list
    }

    function upsert(row) {
        const source = row.source
        if (source.length === 0)
            return
        const sep = source.indexOf("/")
        if (sep <= 0)
            return
        rows[source] = {
            index: row.index,
            title: row.itemTitle || row.source,
            icon: row.iconSource,
            tooltip: row.itemTooltip,
            isMenu: row.itemIsMenu,
            service: source.slice(0, sep),
            path: source.slice(sep)
        }
        queueRebuild()
    }

    function remove(source) {
        if (rows[source] === undefined)
            return
        delete rows[source]
        queueRebuild()
    }

    SystemTrayPrivate.StatusNotifierModel {
        id: sniModel
        // Rows appear/disappear through these; the delegates below react to
        // per-row role changes on their own.
        onRowsInserted: bridge.queueRebuild()
        onRowsRemoved: bridge.queueRebuild()
        onModelReset: bridge.queueRebuild()
        onLayoutChanged: bridge.queueRebuild()
        Component.onCompleted: bridge.ready = true
    }

    Repeater {
        model: sniModel

        delegate: Item {
            id: row

            required property int index
            required property var model

            width: 0
            height: 0

            readonly property string source: model.DataEngineSource || ""
            readonly property string itemTitle: model.Title || model.ToolTipTitle || ""
            readonly property string itemTooltip: model.ToolTipTitle || model.ToolTipSubTitle || ""
            // Theme icons come as IconName (string); pixmap-only items
            // (IBus, Live Captions) expose a QIcon in Icon.  Kirigami.Icon
            // accepts both, exactly like the stock delegate.
            readonly property var iconSource: model.Icon !== undefined && model.Icon !== null
                ? model.Icon : (model.IconName || "")
            readonly property bool itemIsMenu: model.ItemIsMenu === true

            // Captured in sync() so onDestruction never has to touch the
            // model again (the row may already be gone by then).
            property string rowKey: ""

            function sync() {
                rowKey = source
                bridge.upsert(row)
            }

            Component.onCompleted: sync()
            Component.onDestruction: bridge.remove(rowKey)
            onIndexChanged: sync()
            onSourceChanged: sync()
            onItemTitleChanged: sync()
            onItemTooltipChanged: sync()
            onIconSourceChanged: sync()
            onItemIsMenuChanged: sync()
        }
    }
}
