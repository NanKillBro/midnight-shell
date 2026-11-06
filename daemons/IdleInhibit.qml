import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.State

Scope {
    id: root

    Connections {
        function onInhibitIdleChanged(): void {
            if (PersistentState.inhibitIdle)
                PersistentState.inhibitingIdleSince = new Date().getTime();
        }

        target: PersistentState
    }

    IdleInhibitor {
        enabled: PersistentState.inhibitIdle
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return PersistentState.inhibitIdle;
        }

        function toggle(): void {
            PersistentState.inhibitIdle = !PersistentState.inhibitIdle;
        }

        function enable(): void {
            PersistentState.inhibitIdle = true;
        }

        function disable(): void {
            PersistentState.inhibitIdle = false;
        }

        target: "idleInhibitor"
    }
}
