pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.State
import qs.components
import qs.services
import qs.utils

MaterialIcon {
    id: root

    required property color colour

    animate: true
    text: {
        if (PersistentState.doNotDisturb)
            return "notifications_off";
        if (Notifs.notClosed.length > 0)
            return "notifications_unread";
        return "notifications";
    }
    color: root.colour
    fontStyle: Tokens.font.icon.medium
    fill: 1

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                PersistentState.doNotDisturb = !PersistentState.doNotDisturb;
            } else {
                const vis = Visibilities.getForActive();
                vis.sidebar = !vis.sidebar;
            }
        }
    }
}
