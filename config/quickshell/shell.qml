import QtQuick
import Quickshell

Scope {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 34
        color: "#1c2528"

        Text {
            anchors {
                left: parent.left
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }
            color: "#e8efed"
            font.pixelSize: 13
            text: "Hyprland"
        }

        Text {
            id: clock
            anchors {
                right: parent.right
                rightMargin: 14
                verticalCenter: parent.verticalCenter
            }
            color: "#e8efed"
            font.pixelSize: 13
            text: Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")

            Timer {
                interval: 30000
                repeat: true
                running: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd dd MMM  hh:mm")
            }
        }
    }
}