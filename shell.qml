pragma ComponentBehavior: Bound

//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQml
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.utils
import qs.services
import qs.daemons
import "modules"
import "modules/drawers"
import "modules/background"
import "modules/shimeji"
import "modules/areapicker"
import "modules/lock"
import QtQuick
import "modules/polkit"
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    settings.watchFiles: true

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}

    Background {}
    DesktopLyricsOverlay {}
    BadAppleOverlay {}

    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }
    PolkitModule {}
    UnmaintainedNotice {}

    Variants {
        model: Quickshell.screens.filter(s => (GlobalConfig.shimeji?.enabled ?? false) && (GlobalConfig.shimeji?.path?.length ?? 0) > 0 && !Strings.testRegexList(GlobalConfig.shimeji?.excludedScreens ?? [], s.name))

        Shimeji {
            shimejiCount: GlobalConfig.shimeji?.count ?? 1
        }
    }

    Shortcuts {}
    BatteryMonitor {}
    GameMode {}
    IdleInhibit {}
    IdleMonitors {
        lock: lock
    }
    BluetoothReconnect {}

    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily
        Notifs;
        Players;
        Brightness;

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;

        Qt.callLater(() => {
            Weather.reload();
            PastafarianCalendar.reload();
        });
    }

    // Force service initialization
    property var _arpcInit: DiscordRPC
    property var _pipInit: PipManager
    property var _systemTrayInit: SystemTray
}
