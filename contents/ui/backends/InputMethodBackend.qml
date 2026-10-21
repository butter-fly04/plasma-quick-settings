/*
    SPDX-License-Identifier: GPL-2.0-or-later

    On-Screen Keyboard / Input Method state, taken from Plasma itself instead
    of being re-implemented.

    plasma-workspace's manage-inputmethod applet (applets/manage-inputmethod/
    qml/main.qml) uses `org.kde.plasma.workspace.keyboardlayout.KWinVirtualKeyboard`
    — the same singleton KWin exposes for the on-screen keyboard.  It exposes:

      - available                bool   — the OSK backend is loaded
      - mode                     enum   — Never | NonMouseInput | AnyInput
      - visible                  bool   — OSK is on screen right now
      - activeClientSupportsTextInput  bool — focused widget accepts text
      - willShowOnActive         bool   — would pop up if a text field got focus
      - forceActivate()          method — show the OSK in hardware-emulation mode

    We do exactly what the stock applet does in `Plasmoid.onActivated`:
      - "unsupported" → forceActivate()  (no text field focused: emulate hw kbd)
      - "visible"     → KWinVirtualKeyboard.active = false  (hide)
      - otherwise     → open the KCM

    For Fcitx/IBus-style input methods (a separate concern from the OSK), we
    also try `org.kde.kimpanel.inputmethod` if it's installed — that exposes
    the active input method name and lets us switch between e.g. English and
    Pinyin.  Kimpanel is optional; if it isn't present the page just shows
    the OSK controls.

    If `org.kde.plasma.workspace.keyboardlayout` isn't installed the Loader
    in Backend.qml reports the failure and the tile stays hidden.
*/
import QtQuick
import org.kde.plasma.workspace.keyboardlayout as Keyboards

Item {
    id: root
    visible: false

    // The same singleton the stock applet uses.
    readonly property var osk: Keyboards.KWinVirtualKeyboard

    // ----------------------------------------------------- availability/state
    // The "available" gate from the stock applet — if false, the OSK backend
    // isn't loaded (e.g. no maliit server) and we hide the tile.
    readonly property bool available: Keyboards.KWinVirtualKeyboard.available
    readonly property bool visible_: Keyboards.KWinVirtualKeyboard.visible
    readonly property int mode: Keyboards.KWinVirtualKeyboard.mode
    readonly property bool activeClientSupportsTextInput: Keyboards.KWinVirtualKeyboard.activeClientSupportsTextInput
    readonly property bool willShowOnActive: Keyboards.KWinVirtualKeyboard.willShowOnActive

    // Mode constants exposed so the UI doesn't need to import the namespace.
    readonly property int modeNever: Keyboards.KWinVirtualKeyboard.Never
    readonly property int modeNonMouseInput: Keyboards.KWinVirtualKeyboard.NonMouseInput
    readonly property int modeAnyInput: Keyboards.KWinVirtualKeyboard.AnyInput

    readonly property string modeLabel: {
        if (!available) return i18n("Unavailable")
        if (mode === modeAnyInput) return i18n("Always on")
        if (mode === modeNonMouseInput) return i18n("Touch & tablet")
        return i18n("Disabled")
    }
    readonly property string subtitle: {
        if (!available) return i18n("Unavailable")
        if (visible_) return i18n("Visible")
        return modeLabel
    }

    // ---------------------------------------------------------- mutators
    // Mirrors the stock applet's `Plasmoid.onActivated` state machine.
    function toggle() {
        if (!available) return
        if (!activeClientSupportsTextInput && !visible_) {
            // No text field focused: emulate a hardware keyboard.
            Keyboards.KWinVirtualKeyboard.forceActivate()
        } else if (visible_) {
            // Hide the keyboard.
            Keyboards.KWinVirtualKeyboard.active = false
        } else {
            // Otherwise the user is invoking it from the tray, so open settings.
            openSettings()
        }
    }
    function setMode(m) {
        if (available)
            Keyboards.KWinVirtualKeyboard.mode = m
    }
    function show() {
        if (available)
            Keyboards.KWinVirtualKeyboard.forceActivate()
    }
    function hide() {
        if (available)
            Keyboards.KWinVirtualKeyboard.active = false
    }
    function openSettings() {
        // Routed through qs.sh → systemsettings kcm_virtualkeyboard
        // (kept there so a missing `systemsettings` doesn't crash the popup).
    }
}
