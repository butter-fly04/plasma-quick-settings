/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Keyboard layout indicator, ported from plasma-desktop's Keyboard Layout
    applet (applets/keyboardlayout/qml/main.qml).

    The layout state comes from the exact same module the stock applet uses
    (`org.kde.plasma.workspace.keyboardlayout.KeyboardLayout`, wrapped by
    `org.kde.plasma.workspace.components.KeyboardLayoutSwitcher`), so no
    layout logic is re-implemented here:

      - displayStyle 0 = layout name, 1 = flag, 2 = flag with name badge
        (the stock applet's General config page)
      - the flag artwork is KCMKeyboard.Flags.getIcon(), like stock
      - wheel cycles previous/next layout (stock KeyboardLayoutSwitcher)
      - clicking opens the layout list (the stock applet's context-menu
        actions), in both the panel and the popup

    `pill: true` draws the popup variant (rounded background, adaptive
    width); the default is a bare square icon for the panel, sized to the
    same icon size as the other panel glyphs.
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.workspace.keyboardlayout
import org.kde.plasma.workspace.components as WorkspaceComponents
import org.kde.plasma.private.kcm_keyboard as KCMKeyboard
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: root

    // Stock applet displayStyle: 0 = name, 1 = flag, 2 = flag + badge.
    property int displayStyle: 0
    // Rounded "pill" background (popup) instead of a bare panel icon.
    property bool pill: false
    property real iconSize: Kirigami.Units.iconSizes.smallMedium

    readonly property var layoutNames: {
        const list = keyboardLayout.layoutsList
        if (!list || list.length === 0) {
            return { shortName: "", displayName: "", longName: "" }
        }
        const index = Math.max(0, Math.min(keyboardLayout.layout, list.length - 1))
        return list[index]
    }
    readonly property bool hasLayouts: keyboardLayout.layoutsList.length > 0

    implicitWidth: pill
        ? face.contentWidth + Kirigami.Units.largeSpacing * 2
        : iconSize
    implicitHeight: pill
        ? Math.max(Kirigami.Units.gridUnit * 2.2, iconSize)
        : iconSize

    // Same object the stock applet instantiates; connects to org.kde.keyboard.
    KeyboardLayout {
        id: keyboardLayout
    }

    // Pill background / panel hover highlight.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.pill ? Qt.alpha(Kirigami.Theme.textColor, 0.1)
                         : Kirigami.Theme.textColor
        opacity: root.pill ? 1 : (mouse.containsMouse ? 0.12 : 0)
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        // Both buttons open the layout list, like a menu-only tray entry.
        // Right-click must be accepted explicitly or it falls through to
        // the panel's/applet's own context menu.
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: root.openMenu()

        // Stock KeyboardLayoutSwitcher wheel handling.
        onWheel: wheel => {
            wheelDelta += (wheel.inverted ? -1 : 1)
                * (wheel.angleDelta.y ? wheel.angleDelta.y : wheel.angleDelta.x)
            while (wheelDelta >= 120) {
                wheelDelta -= 120
                keyboardLayout.switchToPreviousLayout()
            }
            while (wheelDelta <= -120) {
                wheelDelta += 120
                keyboardLayout.switchToNextLayout()
            }
            wheel.accepted = true
        }
    }
    property int wheelDelta: 0

    // Hovered state, also used by CompactRepresentation to hand the layout
    // name to the shell-positioned applet tooltip.
    readonly property bool hovered: mouse.containsMouse

    // Open the layout list as a NATIVE menu.  A QQC2 menu (and a menu
    // parented to this item) is an own OS window that the panel/applet
    // popup paints over, and inside a panel it gets constrained to the
    // panel window, which collapsed it to a sliver.  PlasmaExtras.Menu
    // wraps libplasma's QMenuProxy around a plain QMenu — the same thing
    // SniMenu.qml uses — so it stacks above the popup and dismisses on
    // an outside click like every other Plasma menu.
    function openMenu() {
        closeMenu()

        const layouts = keyboardLayout.layoutsList
        if (!layouts || layouts.length === 0)
            return

        const proxy = layoutMenuComponent.createObject(root, {
            visualParent: root,
            placement: root.menuPlacement
        })
        layoutMenu = proxy

        for (let i = 0; i < layouts.length; ++i) {
            const layout = layouts[i]
            const item = layoutMenuItemComponent.createObject(root, {
                layoutIndex: i,
                currentLayout: i === keyboardLayout.layout,
                text: layout.longName
            })
            item.icon = KCMKeyboard.Flags.getIcon(layout.shortName)
            layoutMenuItems.push(item)
            proxy.addMenuItem(item)
        }

        proxy.openRelative()
    }

    function closeMenu() {
        const proxy = layoutMenu
        layoutMenu = null
        if (proxy) {
            if (proxy.status !== PlasmaExtras.Menu.Closed)
                proxy.close()
            proxy.destroy()
        }
        for (const item of layoutMenuItems)
            item.destroy()
        layoutMenuItems = []
    }

    // Panel icons sit flush against one screen edge; dock the menu on the
    // screen-facing side so it isn't clipped by the panel.
    readonly property int menuPlacement: {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.TopEdge:
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
        case PlasmaCore.Types.LeftEdge:
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup
        case PlasmaCore.Types.RightEdge:
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup
        case PlasmaCore.Types.BottomEdge:
        default:
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        }
    }

    property var layoutMenu: null
    property var layoutMenuItems: []

    Component {
        id: layoutMenuComponent
        PlasmaExtras.Menu {}
    }

    Component {
        id: layoutMenuItemComponent
        PlasmaExtras.MenuItem {
            required property int layoutIndex
            required property bool currentLayout

            checkable: true
            checked: currentLayout
            onClicked: keyboardLayout.layout = layoutIndex
        }
    }

    // Whichever way the native menu goes away (selection, Escape, click
    // outside it), release the proxy and its QMenuItem objects.
    Connections {
        target: root.layoutMenu
        function onStatusChanged() {
            if (root.layoutMenu
                    && root.layoutMenu.status === PlasmaExtras.Menu.Closed)
                Qt.callLater(root.closeMenu)
        }
    }

    // The flag / label / badge face.  In the panel it is a square exactly
    // like the stock applet; in the pill it grows to fit the layout name.
    Item {
        id: face
        anchors.centerIn: parent
        width: contentWidth
        height: root.iconSize

        readonly property real contentWidth: {
            if (!root.pill) {
                return root.iconSize
            }
            if (countryCode.visible) {
                return Math.min(countryCode.implicitWidth,
                                root.iconSize * 5)
            }
            return root.iconSize
        }

        Kirigami.Icon {
            id: flag
            anchors.fill: parent
            visible: valid
                && (root.displayStyle === 1 || root.displayStyle === 2)
            source: KCMKeyboard.Flags.getIcon(root.layoutNames.shortName)
        }

        PlasmaComponents3.Label {
            id: countryCode
            anchors.centerIn: parent
            width: root.pill ? face.contentWidth : face.height
            height: root.pill ? implicitHeight : face.height
            font.pointSize: root.pill
                ? Kirigami.Theme.defaultFont.pointSize
                : face.height
            fontSizeMode: root.pill ? Text.FixedSize : Text.Fit
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.layoutNames.displayName || root.layoutNames.shortName
            textFormat: Text.PlainText
            elide: root.pill ? Text.ElideRight : Text.ElideNone
            visible: root.displayStyle === 0 || !flag.valid
        }

        // Stock style 2: the layout name as a badge over the flag.
        WorkspaceComponents.BadgeOverlay {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            visible: !countryCode.visible && root.displayStyle === 2
            horizontalPadding: Kirigami.Units.smallSpacing
            text: countryCode.text
            icon: flag
        }
    }

    // In the panel, CompactRepresentation feeds this name into the
    // shell-positioned applet tooltip (one tooltip, like the tray icons).
    // In the popup there is no applet tooltip, so the pill shows its own.
    PlasmaComponents3.ToolTip.text: root.layoutNames.longName
    PlasmaComponents3.ToolTip.visible: root.pill && root.hovered && root.hasLayouts
}
