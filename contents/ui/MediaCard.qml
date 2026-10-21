/*
    SPDX-License-Identifier: GPL-2.0-or-later

    GNOME-style media player card.  Sits at the top of the popup while any
    MPRIS2 player is active, and shows:

      - album art (or a fallback music emblem)
      - track title and artist
      - prev / play-pause / next transport buttons
      - a thin seek bar that fills as the track plays
      - the player's identity (e.g. "Spotify", "VLC") on the right

    All state comes from Backend.qml, which forwards from
    MediaPlayerBackend.qml — which in turn wraps plasma-workspace's
    `Mpris2Model` and `PlayerContainer`.  So this card has the same data and
    capability gates as the stock mediacontroller applet: it only enables
    "prev" when `canGoPrevious` is true, only shows "play" vs "pause" based
    on `playbackStatus`, etc.

    The card is invisible when no player is around (Backend.mediaAvailable is
    false), so the popup looks the same as before on systems without audio
    playback.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    required property var backend

    visible: backend.mediaAvailable
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.largeSpacing
    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)

    // A small position-tick timer (matches the stock mediacontroller applet,
    // which polls position once a second while expanded so the seek bar moves
    // smoothly without spamming D-Bus).
    property int displayPosition: backend.mediaPosition
    Timer {
        running: card.visible && backend.mediaPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            // Advance the local counter so the bar moves between server-side
            // updates; the actual position is re-synced whenever the backend
            // reports a change.  Positions are microseconds (stock applet:
            // "seekSlider.value += 1000000").
            card.displayPosition = Math.min(card.displayPosition + 1000000,
                                            Math.max(1, card.formatOptsLength()))
        }
    }
    // Reset the optimistic counter whenever the backend reports a new position.
    Connections {
        target: backend
        function onMediaPositionChanged() { card.displayPosition = backend.mediaPosition }
        function onMediaAvailableChanged() {
            if (backend.mediaAvailable) backend.mediaRefreshPosition()
        }
    }

    // Units note (this is where the "3371768:31:06" bug came from backend's
    // Mpris2Model reports are in MICROSECONDS — no x1000000 re-scaling).
    function formatOptsLength() { return backend.mediaLength }
    function clampedPosition() {
        const len = backend.mediaLength
        if (len > 0)
            return Math.max(0, Math.min(card.displayPosition, len))
        return Math.max(0, card.displayPosition)
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        // Top row: album art + track info + (small) player icon.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            // Album art, with a music-note fallback when the player doesn't
            // provide one.  48x48 matches the stock mediacontroller applet's
            // CompactRepresentation thumbnail.
            Item {
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large

                Kirigami.Icon {
                    isMask: true
                    color: Kirigami.Theme.textColor
                    anchors.fill: parent
                    source: backend.mediaAlbumArt.length > 0
                        ? backend.mediaAlbumArt
                        : "emblem-music-symbolic"
                    fallback: "emblem-music-symbolic"
                    visible: backend.mediaAlbumArt.length === 0
                }
                Image {
                    anchors.fill: parent
                    source: backend.mediaAlbumArt
                    fillMode: Image.PreserveAspectCrop
                    visible: backend.mediaAlbumArt.length > 0 && status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents3.Label {
                    text: backend.mediaTrack.length > 0 ? backend.mediaTrack : i18n("No track")
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: text.length > 0
                    text: backend.mediaArtist
                    opacity: 0.7
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: text.length > 0
                    text: backend.mediaAlbum
                    opacity: 0.55
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // The player's own icon (Spotify, VLC, ...).  Clicking it raises
            // the player window — same as the stock applet's "Open" action.
            PlasmaComponents3.ToolButton {
                icon.name: backend.mediaIcon
                enabled: backend.mediaCanRaise
                PlasmaComponents3.ToolTip.text: backend.mediaIdentity.length > 0
                    ? backend.mediaIdentity : i18n("Player")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: backend.mediaRaise()
            }
        }

        // Seek bar — appears only if the player reports a known length.
        // Dragging it seeks via PlayerContainer.setPosition().
        RowLayout {
            Layout.fillWidth: true
            visible: backend.mediaLength > 0
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                text: card.formatMicroseconds(card.displayPosition)
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            PlasmaComponents3.Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, backend.mediaLength)
                stepSize: Math.min(1000000, backend.mediaLength) // 1s microsecond steps
                value: card.clampedPosition()
                enabled: backend.mediaCanPause || backend.mediaCanPlay
                onMoved: backend.mediaSetPosition(value)
            }
            PlasmaComponents3.Label {
                text: card.formatMicroseconds(backend.mediaLength)
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        // Transport row.  Each button is gated by the matching canX capability,
        // exactly like the stock mediacontroller's contextual actions.
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.ToolButton {
                icon.name: Application.layoutDirection === Qt.RightToLeft
                    ? "media-skip-forward" : "media-skip-backward"
                enabled: backend.mediaCanGoPrevious
                PlasmaComponents3.ToolTip.text: i18n("Previous Track")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: backend.mediaPrevious()
            }
            PlasmaComponents3.ToolButton {
                icon.name: backend.mediaPlaying ? "media-playback-pause" : "media-playback-start"
                enabled: backend.mediaPlaying ? backend.mediaCanPause : backend.mediaCanPlay
                PlasmaComponents3.ToolTip.text: backend.mediaPlaying ? i18n("Pause") : i18n("Play")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: backend.mediaTogglePlay()
                // Big circle button — make it the visual centre.
                display: PlasmaComponents3.AbstractButton.IconOnly
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            PlasmaComponents3.ToolButton {
                icon.name: Application.layoutDirection === Qt.RightToLeft
                    ? "media-skip-backward" : "media-skip-forward"
                enabled: backend.mediaCanGoNext
                PlasmaComponents3.ToolTip.text: i18n("Next Track")
                PlasmaComponents3.ToolTip.visible: hovered
                onClicked: backend.mediaNext()
            }
        }
    }

    // Microseconds → track time, through the same KCoreAddons.Format.formatDuration
    // the stock mediacontroller uses (it takes milliseconds).  Hours are only
    // shown for tracks actually longer than one hour.
    function formatMicroseconds(microseconds) {
        const options = microseconds >= 3600 * 1000 * 1000 ? 0 : KCoreAddons.FormatTypes.FoldHours
        return KCoreAddons.Format.formatDuration(Math.max(0, microseconds) / 1000, options)
    }
}
