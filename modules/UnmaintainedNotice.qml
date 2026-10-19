pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

// End of life notice shown on shell start: MiDnight is unmaintained, work has moved
// to Kiite (https://kiite-org.github.io/site/). Agreeing without the "don't remind"
// checkbox only dismisses for the current session; disagreeing kills the shell so
// the notice is shown again on the next start.
Scope {
    id: root

    readonly property bool shouldShow: started && !sessionDismissed && !noticeStore.adapter.agreed

    property bool started: false
    property bool sessionDismissed: false
    property bool dontRemind: false

    FileView {
        id: noticeStore

        path: `${Paths.state}/unmaintained.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: noticeAdapter

            property bool agreed: false
        }
    }

    Process {
        id: killProc

        command: ["caelestia", "shell", "-k"]
    }

    function agree(): void {
        if (root.dontRemind) {
            noticeAdapter.agreed = true;
            noticeStore.writeAdapter();
        }
        root.sessionDismissed = true;
    }

    function disagree(): void {
        killProc.running = true;
    }

    // Small delay so the notice doesn't race the rest of the shell's startup
    Timer {
        running: true
        interval: 750
        onTriggered: root.started = true
    }

    Component.onCompleted: CUtils.mkdirp(Paths.state) // must exist before the state persists

    StyledWindow {
        id: win

        readonly property real centerScale: Math.max(0.8, Math.min(1, height / 1440))

        name: "unmaintained"
        visible: root.shouldShow

        screen: Quickshell.screens[0]

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        MouseArea {
            // Swallow clicks outside the card, the notice can only be dismissed by agreeing
            anchors.fill: parent
        }

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.m3scrim
        }

        StyledRect {
            id: card

            anchors.centerIn: parent
            width: Math.min(parent.width * 0.85, 520 * win.centerScale)

            scale: 0
            Component.onCompleted: scale = Qt.binding(() => root.shouldShow ? 1 : 0)

            radius: Tokens.rounding.extraLarge
            color: Colours.palette.m3surfaceContainerHigh

            implicitHeight: content.implicitHeight + Tokens.padding.extraLarge * 2

            focus: true
            Keys.onEscapePressed: root.disagree()
            Keys.onReturnPressed: root.agree()
            onVisibleChanged: {
                if (visible)
                    forceActiveFocus();
            }

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                z: -1
                level: 3
            }

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.large

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "campaign"
                    fill: 1
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(win.centerScale * 1.5).weight(Font.Medium).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("MiDnight is no longer maintained")
                    font: Tokens.font.title.builders.medium.scale(win.centerScale).weight(Font.Medium).build()
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Development of MiDnight has been discontinued. The author has moved on to a new project, Kiite, which you can find at:")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    textFormat: Text.StyledText
                    text: "<a href=\"https://kiite-org.github.io/site/\">kiite-org.github.io/site</a>"
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3primary
                    horizontalAlignment: Text.AlignHCenter
                    onLinkActivated: Qt.openUrlExternally("https://kiite-org.github.io/site/")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Please do not recommend MiDnight to other Caelestia users. If they ask for alternatives, point them to maintained projects instead.")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.small
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.medium

                    StyledSwitch {
                        id: dontRemindSwitch

                        cLayer: 2
                        onToggled: root.dontRemind = checked
                    }

                    StyledText {
                        text: Tr.tr("Don't remind me again")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dontRemindSwitch.checked = !dontRemindSwitch.checked
                        }
                    }
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.medium
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.medium

                    TextButton {
                        text: Tr.trCtx("Disagree & quit", "button")
                        type: TextButton.Tonal
                        onClicked: root.disagree()
                    }

                    TextButton {
                        text: Tr.trCtx("I agree", "button")
                        type: TextButton.Filled
                        onClicked: root.agree()
                    }
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.Emphasized
                    duration: 400
                }
            }
        }
    }
}
