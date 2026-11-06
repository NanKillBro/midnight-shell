import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.services
import qs.utils

Scope {
    id: root

    readonly property bool enabled: RuntimeState.gameMode
    property bool _autoEnabled: false

    function applyGameMode(): void {
        root.setDynamicConfs();
    }

    function evaluateAutoEnable(): void {
        const regexes = GlobalConfig.utilities.gameMode.autoEnableRegexes;
        if (!GlobalConfig.utilities.gameMode.autoEnable || regexes.length === 0) {
            if (_autoEnabled) {
                _autoEnabled = false;
                RuntimeState.gameMode = false;
            }
            return;
        }

        let isRunning = false;
        for (const toplevel of Hyprland.toplevels.values) {
            if (toplevel.lastIpcObject && Strings.testRegexList(regexes, toplevel.lastIpcObject.class)) {
                isRunning = true;
                break;
            }
        }

        if (_autoEnabled !== isRunning) {
            _autoEnabled = isRunning;
            RuntimeState.gameMode = isRunning;
        }
    }

    function setDynamicConfs(): void {
        const gameModeConfig = GlobalConfig.utilities.gameMode;

        // The options map provides the base set of Hyprland overrides; the
        // per-option toggles below take precedence over their respective keys.
        let options = Object.assign({}, gameModeConfig.options);

        if (gameModeConfig.disableHyprlandAnimations)
            options["animations:enabled"] = 0;
        else
            delete options["animations:enabled"];
        if (gameModeConfig.disableHyprlandShadows)
            options["decoration:shadow:enabled"] = 0;
        else
            delete options["decoration:shadow:enabled"];
        if (gameModeConfig.disableHyprlandBlur)
            options["decoration:blur:enabled"] = 0;
        else
            delete options["decoration:blur:enabled"];
        if (gameModeConfig.disableHyprlandGaps) {
            options["general:gaps_in"] = 0;
            options["general:gaps_out"] = 0;
            options["general:border_size"] = 1;
            options["decoration:rounding"] = 0;
        } else {
            delete options["general:gaps_in"];
            delete options["general:gaps_out"];
            delete options["general:border_size"];
            delete options["decoration:rounding"];
        }
        options["general:allow_tearing"] = 1;

        if (gameModeConfig.disableWindowTransparency) {
            options["decoration:active_opacity"] = 1;
            options["decoration:inactive_opacity"] = 1;
            options["decoration:fullscreen_opacity"] = 1;
        } else {
            delete options["decoration:active_opacity"];
            delete options["decoration:inactive_opacity"];
            delete options["decoration:fullscreen_opacity"];
        }

        Hypr.extras.applyOptions(options);

        if (gameModeConfig.disableWindowTransparency) {
            if (Hypr.usingLua) {
                Hypr.extras.batchMessage([`eval hl.window_rule({ match = { class = ".*" }, opaque = true })`]);
            } else {
                Hypr.extras.batchMessage([`keyword windowrulev2 opaque, class:.*`]);
            }
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: root.evaluateAutoEnable()
    }

    Connections {
        function onAutoEnableChanged(): void {
            root.evaluateAutoEnable();
        }

        function onAutoEnableRegexesChanged(): void {
            root.evaluateAutoEnable();
        }

        target: GlobalConfig.utilities.gameMode
    }

    Connections {
        function onGameModeChanged(): void {
            if (RuntimeState.gameMode) {
                root.setDynamicConfs();
                if (GlobalConfig.utilities.toasts.gameModeChanged)
                    Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Disabled Hyprland animations, blur, gaps and shadows"), "gamepad");
            } else {
                Hypr.extras.message("reload");
                if (GlobalConfig.utilities.toasts.gameModeChanged)
                    Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("Hyprland settings restored"), "gamepad");
            }
        }

        target: RuntimeState
    }

    Connections {
        function onConfigReloaded(): void {
            if (RuntimeState.gameMode)
                root.setDynamicConfs();
        }

        target: Hypr
    }

    IpcHandler {
        function isEnabled(): bool {
            return RuntimeState.gameMode;
        }

        function toggle(): void {
            RuntimeState.gameMode = !RuntimeState.gameMode;
        }

        function enable(): void {
            RuntimeState.gameMode = true;
        }

        function disable(): void {
            RuntimeState.gameMode = false;
        }

        target: "gameMode"
    }
}
