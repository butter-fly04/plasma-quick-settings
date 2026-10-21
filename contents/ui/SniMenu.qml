/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A StatusNotifierItem's own context menu, rendered as a NATIVE menu.

    Per the StatusNotifierItem spec the HOST (the tray widget that
    represents the icon) owns the menu: the item serves a
    com.canonical.dbusmenu tree at the object path in its `Menu` property,
    and the host displays it and reports clicks with Event(id, "clicked",
    …).  That is why qs.sh traymenu (a bare ContextMenu(0,0) call) does
    nothing: the method is a no-op stub on most items, the actual rendering
    is on us.

    qs.sh traymenulayout returns the whole tree in one GetLayout(-1) call
    as single-line JSON; commit() rebuilds it as a PlasmaExtras.Menu — the
    light wrapper libplasma provides around a plain QMenu.  That is the
    same mechanism kickoff uses for its own menus, and it is what stacks
    correctly above an applet popup: a QQC2 menu opens its own OS window
    that plasma's keep-above applet dialog paints over.

    Because PlasmaExtras.Menu *is* native, submenus nest through
    visualParent: giving a Menu the QAction of an item attach-points that
    QMenu as the item's submenu (libplasma additionally pins those popup
    windows to their parents, see QMenuProxy::rebuildMenu()).  Clicks go
    back through qs.sh traymenuclick — the same wire traffic plasma's own
    DBusMenuImporter produces.
*/
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: menu

    required property var backend

    // Filled in by openFor(): the SNI's bus service, the object path that
    // serves its dbusmenu tree, and the item's own object path (the place
    // where pinning is tracked).
    property string service: ""
    property string menuPath: ""
    property string itemPath: ""

    // When true (tray page rows), a footer entry to pin/unpin the icon is
    // appended below the app's own entries.
    property bool withPinEntry: false

    // Where the menu is docked: opening left of the anchor Item (normally
    // the row or arrow block that was clicked) keeps the menu clear of the
    // applet popup, the same horizontal hint the stock tray uses.
    property Item anchorItem: null

    // Every QMenuProxy/QMenuItem built for the current tree; destroyed on
    // rebuild.  QMenuItem is a bare QObject, so the proxies and entries
    // live under this invisible Item.
    property var objects: []
    property var rootProxy: null
    property int builtCount: 0

    Component {
        id: entryComp
        PlasmaExtras.MenuItem {
            required property int nodeId
            required property bool toggleable
            onClicked: {
                if (toggleable)
                    checked = !checked
                if (nodeId === -1)
                    menu.togglePin()
                else
                    menu.activateEntry(nodeId)
            }
        }
    }
    Component {
        id: sepComp
        PlasmaExtras.MenuItem {
            separator: true
        }
    }
    Component {
        id: submenuComp
        PlasmaExtras.Menu {}
    }
    Component {
        id: rootComp
        // LeftPosedTopAlignedPopup: dock at the LEFT edge of the anchor,
        // top aligned with it, away from the applet popup.
        PlasmaExtras.Menu {
            placement: PlasmaExtras.Menu.LeftPosedTopAlignedPopup
        }
    }

    // busctl --json wraps every gvariant as {"type": "s", "data": 42};
    // we only care about the value.
    function plainProps(raw) {
        const p = {}
        for (const key in raw || {}) {
            const wrapped = raw[key]
            p[key] = (wrapped !== null && typeof wrapped === "object" && wrapped.data !== undefined)
                ? wrapped.data : (typeof wrapped === "string" ? wrapped : undefined)
        }
        return p
    }

    // Recursively add a DBusMenu node as an entry of targetProxy.  Nodes
    // arrive from busctl --json=short as {"type": "(…)", "data": [id,
    // {prop: {type, data}}, children[]]}.
    function buildNode(node, targetProxy) {
        if (!Array.isArray(node) || node.length < 3)
            return
        const nodeId = node[0]
        const p = plainProps(node[1])
        if (p.visible === false)
            return

        if (p.type === "separator") {
            const sep = sepComp.createObject(null)
            objects.push(sep)
            targetProxy.addMenuItem(sep)
            builtCount++
            return
        }

        const label = (p.label || "").replace(/_([^_])/g, "$1")
        const isMenu = p["children-display"] === "submenu"
        const toggleType = p["toggle-type"] || ""

        const item = entryComp.createObject(null, {
            nodeId: nodeId,
            toggleable: toggleType === "checkmark",
            text: label,
            enabled: p.enabled !== false,
            checkable: toggleType === "checkmark",
            checked: p["toggle-state"] === 1
        })
        if (p["icon-name"])
            item.icon = p["icon-name"]
        objects.push(item)

        if (isMenu) {
            // attaching the new proxy to the item's action turns it into
            // that item's native submenu
            const sub = submenuComp.createObject(menu, {visualParent: item.action})
            objects.push(sub)
            for (const child of node[2] || [])
                buildNode(child.data, sub)
        }

        targetProxy.addMenuItem(item)
        builtCount++
    }

    function activateEntry(nodeId) {
        // The caller already flipped checkmarks locally; the app's answer
        // (via ItemsPropertiesUpdated / a fresh GetLayout) corrects it
        // anyway.  Qt's own DBusMenuImporter does exactly the same.
        backend.trayMenuClick(menu.service, menu.menuPath, nodeId)
    }

    function togglePin() {
        if (backend.isSniPinned(menu.service, menu.itemPath))
            backend.unpinSni(menu.service, menu.itemPath)
        else
            backend.pinSni(menu.service, menu.itemPath)
    }

    // Close and destroy the previous popup (if any) and every QML object
    // we ever created for it.
    function teardown() {
        if (rootProxy) {
            if (rootProxy.status !== PlasmaExtras.Menu.Closed)
                rootProxy.close()
            const r = rootProxy
            rootProxy = null
            r.destroy()
        }
        for (const obj of objects)
            obj.destroy()
        objects = []
        builtCount = 0
    }

    function openFor(sniService, sniItemPath) {
        if (!sniService || !sniItemPath)
            return
        teardown()
        service = sniService
        itemPath = sniItemPath
        menuPath = ""
        backend.fetchTrayMenuLayout(sniService, sniItemPath, out => {
            let status = ""
            for (const line of out.split("\n")) {
                if (line.startsWith("menu_status="))
                    status = line.slice("menu_status=".length)
                else if (line.startsWith("menu_path="))
                    menuPath = line.slice("menu_path=".length)
                else if (line.startsWith("menujson=") && status === "ok")
                    commit(JSON.parse(line.slice("menujson=".length)))
            }
            if (status !== "ok")
                console.warn("[QuickSettings] tray menu status:", status, "for", sniService)
        })
    }

    function commit(reply) {
        if (!menuPath || !Array.isArray(reply?.data) || reply.data.length < 2) {
            console.warn("[QuickSettings] tray menu lookup failed for", service)
            return
        }
        // reply = {type: "u(ia{sv}av)", data: [revision, [rootId, props, children]]}
        // The root node (id 0) is NOT an entry: per the DBusMenu protocol
        // its children are the menu's top-level items.
        builtCount = 0
        const root = reply.data[1]
        rootProxy = rootComp.createObject(menu, {visualParent: anchorItem ?? null})
        for (const child of root[2] || [])
            buildNode(child.data, rootProxy)

        if (withPinEntry && builtCount > 0) {
            const sep = sepComp.createObject(null)
            objects.push(sep)
            rootProxy.addMenuItem(sep)
            builtCount++
            const pinned = backend.isSniPinned(service, itemPath)
            const pinItem = entryComp.createObject(null, {
                nodeId: -1,
                toggleable: false,
                text: pinned ? i18n("Unpin from Quick Settings") : i18n("Pin to Quick Settings"),
                enabled: true,
                checkable: false
            })
            pinItem.icon = pinned ? "edit-delete" : "window-pin"
            objects.push(pinItem)
            rootProxy.addMenuItem(pinItem)
            builtCount++
        }

        if (builtCount > 0)
            rootProxy.open()
        else
            console.warn("[QuickSettings] tray menu empty for", service)
    }

    // Whichever way the menu goes away (selection, Escape, focus loss),
    // release everything.  Status is a QMenuProxy signal.
    Connections {
        target: menu.rootProxy
        function onStatusChanged() {
            if (menu.rootProxy && menu.rootProxy.status === PlasmaExtras.Menu.Closed)
                Qt.callLater(menu.teardown)
        }
    }
}
