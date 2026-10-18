pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property int refCount: 0
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0 // Might get too large for int

        reloadableId: "recorder"
    }

    Process {
        id: checkProc

        running: true
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => {
            const running = code === 0;

            // All CLI invocations are detached: an attached child inherits the
            // shell's stdin pipe (which made slurp hang invisibly forever) and
            // `caelestia record` blocks on its toasts / region selection, which
            // would serialize every later command behind it.
            if (running && root.needsStop) {
                Quickshell.execDetached(["caelestia", "record"]);
                props.running = false;
                props.paused = false;
                Audio.playVideoStop();
            } else if (running && root.needsPause) {
                Quickshell.execDetached(["caelestia", "record", "-p"]);
                props.paused = !props.paused;
            } else if (!running && root.needsStart) {
                Quickshell.execDetached(["caelestia", "record", ...root.startArgs]);
                props.running = true;
                props.paused = false;
                props.elapsed = 0;
                Audio.playVideoRecord();
            } else if (running !== props.running) {
                // The recording was started/stopped outside the shell (e.g. via
                // keybind), or a region selection is pending/was cancelled
                props.running = running;
                props.paused = false;
                props.elapsed = 0;
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    // Only poll while something is showing the state, i.e. the utilities drawer is open
    Timer {
        interval: 1000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true

        onTriggered: checkProc.running = true
    }

    Connections {
        enabled: props.running && !props.paused
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        target: Time // qmllint disable incompatible-type
    }
}
