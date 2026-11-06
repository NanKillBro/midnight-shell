pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.State

import qs.services
import qs.utils

Singleton {
    id: root

    // QML Settings is broken here (quickshell app identifiers unset → status 1);
    // FileView + JsonAdapter persists reliably.
    FileView {
        id: pauserStore

        path: `${Paths.state}/wallpaper/pauser.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: pauserAdapter

            property bool manualPause: false
            property bool pauseOnBattery: false
            property bool pauseOnWindowOverlap: true
            property string hwDecoder: "none"
        }
    }

    // The python CLI reads this file before the Qt application starts in order to
    // inject QT_FFMPEG_DECODING_HW_DEVICE_TYPES; kept in sync by setHwDecoder().
    FileView {
        id: hwDecoderStore

        path: `${Paths.cache}/hwDecoder.txt`
        printErrors: false
    }

    Process {
        id: restartShellProc
    }

    property alias manualPause: pauserAdapter.manualPause
    property alias pauseOnBattery: pauserAdapter.pauseOnBattery
    property alias pauseOnWindowOverlap: pauserAdapter.pauseOnWindowOverlap
    property alias hwDecoder: pauserAdapter.hwDecoder
    property bool paused: false
    property string pauseReason: "None"

    // Non-visual singleton: read the global config directly (the screen-bound
    // attached Config has no screen here and only warns).
    readonly property bool cfgVideoPaused: GlobalConfig.background.videoWallpaperPaused
    readonly property bool cfgTransparency: GlobalConfig.utilities.toasts.transparency

    function persist(): void {
        pauserStore.writeAdapter();
    }

    // Setting the decoder must restart the shell: the CLI injects the env var only
    // at process start. Called from the UI; file-load driven changes never land here,
    // so a restart can not be triggered from loading pauser.json.
    function setHwDecoder(v: string): void {
        if (v === pauserAdapter.hwDecoder)
            return;

        pauserAdapter.hwDecoder = v;
        root.persist();
        hwDecoderStore.setText(v);
        restartShellProc.command = ["sh", "-c", "nohup sh -c 'sleep 1 && caelestia shell -d' >/dev/null 2>&1 & sleep 0.5 && caelestia shell -k"];
        restartShellProc.running = true;
    }

    function recalculate() {
        let newPaused = false;
        let reason = "None";

        // Rule #0 — Manual / Config / State Pause (the quick toggle writes PersistentState.wallpaperPlaying)
        if (!PersistentState.wallpaperPlaying || root.cfgVideoPaused || manualPause) {
            newPaused = true;
            reason = !PersistentState.wallpaperPlaying ? "Wallpaper playing toggle" : "Manual / Config Pause";
        } else if (pauseOnBattery && UPower.onBattery) {
            newPaused = true;
            reason = "Battery";
        } else if (pauseOnWindowOverlap) {
            const monitor = Hyprland.focusedMonitor;
            const ws = monitor && monitor.activeWorkspace ? monitor.activeWorkspace : Hyprland.focusedWorkspace;

            if (ws) {
                // Strictly filter global toplevels to ONLY the focused workspace
                const toplevels = ws.toplevels.values;

                // Rule #3 — 2+ visible windows
                if (toplevels.length >= 2) {
                    newPaused = true;
                    reason = "2+ windows (" + toplevels.length + " total)";
                } else {
                    // Rule #2 — 70% of monitor area
                    if (monitor) {
                        const screen = Quickshell.screens.find(s => s.name === monitor.name);
                        if (screen) {
                            const screenArea = screen.width * screen.height;
                            if (screenArea > 0) {
                                const threshold = screenArea * 0.7;
                                for (const t of toplevels) {
                                    const size = t.lastIpcObject?.size;
                                    if (size && size.length >= 2 && size[0] * size[1] >= threshold) {
                                        newPaused = true;
                                        reason = "70% area rule by: " + (t.lastIpcObject?.title ?? "Unknown") + " (" + size[0] + "x" + size[1] + ")";
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        paused = newPaused;
        root.pauseReason = reason;
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.recalculate();
        }
        function onFocusedMonitorChanged() {
            root.recalculate();
        }
        function onRawEvent(event) {
            const n = event.name;
            if (n.startsWith("workspace") || n.startsWith("activewindow") || n.startsWith("createworkspace") || n.startsWith("destroyworkspace") || ["fullscreen", "changefloatingmode", "minimize", "movewindow", "openwindow", "closewindow", "moveworkspace", "focusedmon"].includes(n)) {
                recalcTimer.restart();
            }
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            recalcTimer.restart();
        }
    }

    Connections {
        target: PersistentState
        function onWallpaperPlayingChanged() {
            recalcTimer.restart();
        }
    }

    Timer {
        id: recalcTimer
        interval: 50
        onTriggered: root.recalculate()
    }

    // Startup timer to ensure we catch the asynchronously loaded Hyprland and Quickshell state
    Timer {
        id: startupTimer
        interval: 1000
        repeat: true
        running: true
        property int attempts: 0
        onTriggered: {
            root.recalculate();
            attempts++;
            if (attempts >= 5) {
                running = false;
            }
        }
    }

    onManualPauseChanged: {
        pauserStore.writeAdapter();
        recalculate();
    }

    onPauseOnBatteryChanged: {
        pauserStore.writeAdapter();
        recalculate();
    }

    onPauseOnWindowOverlapChanged: {
        pauserStore.writeAdapter();
        recalculate();
    }

    Component.onCompleted: {
        CUtils.mkdirp(Paths.state + "/wallpaper"); // must exist before the pauser state persists
        CUtils.mkdirp(Paths.cache); // must exist before hwDecoder.txt persists
        recalculate();
    }
}
