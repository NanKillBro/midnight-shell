import QtQuick
import Quickshell

FontLoader {
    readonly property bool hasSystemFont: Qt.fontFamilies().indexOf("Google Sans Flex") !== -1 || Qt.fontFamilies().indexOf("GoogleSansFlex") !== -1
    source: hasSystemFont ? "" : Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
}

