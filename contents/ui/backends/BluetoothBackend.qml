/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Bluetooth, taken from Plasma itself (BlueDevil's applet, src/applet/qml/main.qml,
    FullRepresentation.qml and DeviceItem.qml in Plasma 6.7).

    Three things the earlier hand-written version got wrong, and how Plasma does them:

    1. "Is there Bluetooth at all?"  Plasma asks rfkill, NOT the adapter list:
         BluezQt.Manager.rfkill.state !== BluezQt.Rfkill.Unknown
       (BlueDevil's own comment: "We cannot use the adapter count here because
       that can be zero when bluetooth is disabled even when there are physical
       devices.")  A disabled chip has no adapter, which is why it used to show
       "Unavailable" until something else switched it on.
    2. "Is it on?"  BluezQt.Manager.bluetoothOperational.
    3. Turning it on/off: unblock rfkill AND power every adapter (setEnabled below
       is BlueDevil's setBluetoothEnabled).

    The device list is BlueDevil's own model chain, so filtering (paired or connected,
    blocked hidden), sorting, the Connected/Available sections, and the shared
    "connecting / disconnecting" state are identical to the stock applet (and shared
    with it if it is also in your tray).
*/
import QtQuick
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.bluetooth as PlasmaBt

Item {
    id: root
    visible: false

    readonly property bool present: BluezQt.Manager.rfkill.state !== BluezQt.Rfkill.Unknown
    readonly property bool operational: BluezQt.Manager.bluetoothOperational
    readonly property int connectedCount: BluezQt.Manager.connectedDevices.length
    readonly property string connectedName: connectedCount > 0
        ? BluezQt.Manager.connectedDevices[0].name : ""
    readonly property bool busy: PlasmaBt.SharedDevicesStateProxyModel.connecting
        || PlasmaBt.SharedDevicesStateProxyModel.disconnecting

    // Rows have the roles the stock applet uses: Icon, DeviceFullName, Section,
    // Connected, Connecting, Disconnecting, ConnectionFailed, Battery, Device, Ubi...
    readonly property alias devicesModel: devices

    PlasmaBt.DevicesProxyModel {
        id: devices
        hideBlockedDevices: true
        sourceModel: PlasmaBt.SharedDevicesStateProxyModel
    }

    // BlueDevil's setBluetoothEnabled()
    function setEnabled(on: bool): void {
        BluezQt.Manager.bluetoothBlocked = !on
        BluezQt.Manager.adapters.forEach(adapter => {
            adapter.powered = on
        })
    }

    // BlueDevil's DeviceItem.toggleDevice()
    function toggleDevice(device, ubi: string, connected: bool, busy: bool): void {
        if (busy)
            return
        if (connected) {
            const call = device.disconnectFromDevice()
            PlasmaBt.SharedDevicesStateProxyModel.registerDisconnectingCallForDeviceUbi(call, ubi)
        } else {
            const call = device.connectToDevice()
            PlasmaBt.SharedDevicesStateProxyModel.registerConnectingCallForDeviceUbi(call, ubi)
        }
    }

    // BlueDevil's "Pair Device…" action
    function pairDevice(): void {
        PlasmaBt.LaunchApp.launchWizard()
    }
}
