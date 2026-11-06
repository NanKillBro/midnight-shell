pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import Caelestia.State
import qs.services
import qs.modules.lock

Scope {
    id: root

    required property Lock lock
    readonly property bool hasPlayer: Players.list.some(p => p.isPlaying)
    readonly property bool isCharging: !UPower.onBattery
    readonly property bool enabled: {
        if (GlobalConfig.general.idle.inhibitWhenAudio && hasPlayer)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenCharging && isCharging)
            return false;
        return true;
    }
    readonly property bool keepAwake: PersistentState.inhibitIdle

    function classifyAction(action: var): var {
        let actions = [];
        if (typeof action === "string")
            actions = [action];
        else if (action && typeof action.length === "number")
            actions = Array.from(action);

        const kinds = {
            lock: false,
            sleep: false,
            screenOff: false
        };

        for (const a of actions) {
            if (typeof a !== "string")
                continue;

            const cmd = a.trim();
            if (cmd === "dpms off" || cmd === "dpms disable" || (cmd.startsWith("hl.dsp.dpms") && cmd.includes("disable")))
                kinds.screenOff = true;
            if (cmd.includes("lock"))
                kinds.lock = true;
            if (cmd.includes("suspend") || cmd.includes("hibernate") || cmd.includes("sleep"))
                kinds.sleep = true;
        }

        return kinds;
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (typeof action === "string")
            Hypr.dispatch(Hypr.usingLua && ["dpms off", "dpms on"].includes(action) ? `hl.dsp.dpms({ action = "${action === "dpms off" ? "disable" : "enable"}" })` : action);
        else if (!SessionManager.exec(action))
            Quickshell.execDetached(action);
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts.values

        IdleMonitor {
            required property var modelData
            readonly property var actionKinds: root.classifyAction(modelData.idleAction)

            enabled: {
                if (!root.enabled || !(modelData.enabled ?? true))
                    return false;
                if (root.keepAwake && (actionKinds.lock || actionKinds.sleep))
                    return false;
                if (modelData.inhibitWhenAudio && root.hasPlayer)
                    return false;
                if (modelData.inhibitWhenCharging && root.isCharging)
                    return false;
                return true;
            }
            timeout: modelData.timeout
            respectInhibitors: root.keepAwake && actionKinds.screenOff ? false : (modelData.respectInhibitors ?? true)
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
