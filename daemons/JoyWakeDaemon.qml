import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Services

Scope {
    id: root

    readonly property bool inhibiting: GlobalConfig.general.idle.inhibitWhenJoystick && JoyWake.active

    Binding {
        target: JoyWake
        property: "running"
        value: GlobalConfig.general.idle.inhibitWhenJoystick
    }

    Binding {
        target: JoyWake
        property: "holdTimeout"
        value: GlobalConfig.general.idle.joystickTimeout
    }

    IdleInhibitor {
        enabled: root.inhibiting
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    IpcHandler {
        target: "joyWake"

        function isActive(): bool {
            return JoyWake.active;
        }

        function isRunning(): bool {
            return JoyWake.running;
        }

        function devices(): string {
            return JoyWake.devices.join(", ");
        }

        function lastError(): string {
            return JoyWake.lastError;
        }
    }
}
