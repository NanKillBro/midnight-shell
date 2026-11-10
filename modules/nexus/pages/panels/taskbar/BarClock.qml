pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Clock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Background")
            configNode: root.targetConfig.bar.clock
            propertyName: "background"
            checked: root.targetConfig.bar.clock.background
            onToggled: {
                root.targetConfig.bar.clock.background = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show date")
            configNode: root.targetConfig.bar.clock
            propertyName: "showDate"
            checked: root.targetConfig.bar.clock.showDate
            onToggled: {
                root.targetConfig.bar.clock.showDate = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show icon")
            configNode: root.targetConfig.bar.clock
            propertyName: "showIcon"
            checked: root.targetConfig.bar.clock.showIcon
            onToggled: {
                root.targetConfig.bar.clock.showIcon = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show seconds")
            configNode: root.targetConfig.bar.clock
            propertyName: "showSeconds"
            checked: root.targetConfig.bar.clock.showSeconds
            onToggled: {
                root.targetConfig.bar.clock.showSeconds = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a calendar when hovering the clock")
            configNode: root.targetConfig.bar.popouts
            propertyName: "clock"
            checked: root.targetConfig.bar.popouts.clock
            onToggled: {
                root.targetConfig.bar.popouts.clock = checked;
                root.targetConfig.save();
            }
        }
    }
}
