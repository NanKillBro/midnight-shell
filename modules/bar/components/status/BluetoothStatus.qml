pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.utils

Item {
    id: root

    required property color colour

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    GridLayout {
        id: layout

        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium / 2
        rowSpacing: Tokens.spacing.medium / 2

        // Bluetooth icon
        MaterialIcon {
            animate: true
            text: {
                if (!Bluetooth.defaultAdapter?.enabled)
                    return "bluetooth_disabled";
                if (Bluetooth.devices.values.some(d => d.connected))
                    return "bluetooth_connected";
                return "bluetooth";
            }
            color: root.colour
        }

        // Connected bluetooth devices
        Repeater {
            model: ScriptModel {
                values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
            }

            MaterialIcon {
                id: device

                required property BluetoothDevice modelData

                animate: true
                text: Icons.getBluetoothIcon(modelData?.icon)
                color: root.colour
                fill: 1

                SequentialAnimation on opacity {
                    running: device.modelData?.state !== BluetoothDeviceState.Connected
                    alwaysRunToEnd: true
                    loops: Animation.Infinite

                    Anim {
                        from: 1
                        to: 0
                        duration: Tokens.anim.durations.large
                        easing: Tokens.anim.standardAccel
                    }
                    Anim {
                        from: 0
                        to: 1
                        duration: Tokens.anim.durations.large
                        easing: Tokens.anim.standardDecel
                    }
                }
            }
        }
    }
}
