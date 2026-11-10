pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard.dash

StyledRect {
    id: root

    required property ScreenState screenState

    implicitWidth: Tokens.sizes.bar.clockCalendarWidth
    implicitHeight: calendar.implicitHeight

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    Calendar {
        id: calendar

        anchors.left: parent.left
        anchors.right: parent.right
        screenState: root.screenState
    }
}
