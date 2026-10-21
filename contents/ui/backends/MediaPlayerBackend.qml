/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Media player state, taken from Plasma itself instead of being re-implemented.

    plasma-workspace's mediacontroller applet uses `org.kde.plasma.private.mpris`
    which is the public-ish QML binding for plasma-workspace/libkmpris.  We
    instantiate the same `Mpris2Model` here so the Quick Settings media card
    has *exactly* the same data and behaviour as the stock media controller
    applet:

      - `currentPlayer` follows the same "most recently active" rule
      - `playbackStatus` is the same enum (Unknown/Stopped/Playing/Paused)
      - All `canGoNext/canGoPrevious/canPlay/canPause/canStop/canControl/
        canRaise/canQuit` capability gates match
      - `Previous()`, `Next()`, `Play()`, `Pause()`, `PlayPause()`, `Stop()`,
        `Quit()`, `Raise()`, `Seek(offset)`, `setVolume(v)`, `setPosition(p)`
        go straight to the MPRIS2 D-Bus interface via PlayerContainer, so
        players don't see any difference vs. the stock applet

    The card UI is in MediaCard.qml; this Item just exposes the model and
    forwarding methods.  If `org.kde.plasma.private.mpris` is not installed
    (e.g. plasma-workspace was built without it) the Loader in Backend.qml
    reports the failure and the UI hides the card.
*/
import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: root
    visible: false

    // The stock mediacontroller applet's model.  `currentPlayer` is a
    // PlayerContainer (or null), whose properties are exactly the
    // org.mpris.MediaPlayer2.Player interface.
    Mpris.Mpris2Model {
        id: mpris2Model
    }

    // ----------------------------------------------------- availability/state
    // True when there is at least one player that has been (or is) playing.
    // The stock applet sets Plasmoid.status = ActiveStatus on this condition,
    // so we use the same gate before showing the card at all.
    readonly property bool hasPlayer: currentPlayer !== null
    readonly property var currentPlayer: mpris2Model.currentPlayer

    // Convenience accessors — same names as mediacontroller/main.qml.
    readonly property string track: currentPlayer ? currentPlayer.track : ""
    readonly property string artist: currentPlayer ? currentPlayer.artist : ""
    readonly property string album: currentPlayer ? currentPlayer.album : ""
    readonly property string albumArt: currentPlayer ? currentPlayer.artUrl : ""
    readonly property string identity: currentPlayer ? currentPlayer.identity : ""
    readonly property string iconName: currentPlayer ? currentPlayer.iconName : "emblem-music-symbolic"
    readonly property bool canControl: currentPlayer ? currentPlayer.canControl : false
    readonly property bool canGoPrevious: currentPlayer ? currentPlayer.canGoPrevious : false
    readonly property bool canGoNext: currentPlayer ? currentPlayer.canGoNext : false
    readonly property bool canPlay: currentPlayer ? currentPlayer.canPlay : false
    readonly property bool canPause: currentPlayer ? currentPlayer.canPause : false
    readonly property bool canStop: currentPlayer ? currentPlayer.canStop : false
    readonly property bool canSeek: currentPlayer ? currentPlayer.canSeek : false
    readonly property bool canRaise: currentPlayer ? currentPlayer.canRaise : false
    readonly property bool canQuit: currentPlayer ? currentPlayer.canQuit : false
    readonly property int playbackStatus: currentPlayer ? currentPlayer.playbackStatus : 0
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property int shuffle: currentPlayer ? currentPlayer.shuffle : 0
    readonly property int loopStatus: currentPlayer ? currentPlayer.loopStatus : 0
    readonly property real volume: currentPlayer ? currentPlayer.volume : 0.0
    readonly property real rate: currentPlayer ? currentPlayer.rate : 1.0
    readonly property int position: currentPlayer ? currentPlayer.position : 0
    readonly property real length: currentPlayer ? currentPlayer.length : 0

    // The list of all players, for the picker in the card (if you want to
    // switch from e.g. Spotify to VLC).  Mirrors the stock applet's source model.
    readonly property var players: mpris2Model

    // ---------------------------------------------------------- mutators
    // All of these match the stock mediacontroller's functions exactly —
    // they just forward to PlayerContainer, which sends the MPRIS2 D-Bus call.
    function previous() { if (currentPlayer) currentPlayer.Previous() }
    function next()     { if (currentPlayer) currentPlayer.Next() }
    function play()     { if (currentPlayer) currentPlayer.Play() }
    function pause()    { if (currentPlayer) currentPlayer.Pause() }
    function togglePlaying() {
        if (!currentPlayer) return
        if (isPlaying) currentPlayer.Pause()
        else           currentPlayer.Play()
    }
    function stop()     { if (currentPlayer) currentPlayer.Stop() }
    function quit()     { if (currentPlayer) currentPlayer.Quit() }
    function raise()    { if (currentPlayer) currentPlayer.Raise() }
    function seek(offsetMicroseconds) {
        if (currentPlayer) currentPlayer.Seek(offsetMicroseconds)
    }
    function setPosition(microseconds) {
        if (currentPlayer) currentPlayer.setPosition(microseconds)
    }
    function setVolume(v) {
        if (currentPlayer) currentPlayer.setVolume(v, /*showOSD=*/false)
    }
    // Called when the popup opens so the position label is fresh (same as the
    // stock applet's onExpandedChanged handler).
    function refreshPosition() {
        if (currentPlayer) currentPlayer.updatePosition()
    }
}
