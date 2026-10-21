import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960; height: 540; minimumWidth: 640; minimumHeight: 400
    visible: true; title: "Session Timer"; color: "#e9e5d8"
    property int focusIndex: 0
    function activate(index) {
        if (index === 0) { if (timer.ready) timer.activate(); else timer.connectHost() }
        else if (index === 1) timer.reset()
        else if (index === 2) timer.toggleMode()
        else if (index === 3) timer.cycleReminder()
        else if (index === 4) window.showMinimized()
        else window.close()
    }
    Item {
        anchors.fill: parent; focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_Down) window.focusIndex = (window.focusIndex+1)%6
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Up) window.focusIndex = (window.focusIndex+5)%6
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) window.activate(window.focusIndex)
            else if (event.key === Qt.Key_Escape) window.showMinimized()
            else return
            event.accepted = true
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: 14; radius: 26
            color: "#faf8ee"; border.color: "#bec7bb"; border.width: 2
            Rectangle { x: 0; y: 0; width: parent.width; height: 8; radius: 4; color: "#79ada0" }
            Text { x: 30; y: 25; text: "Session Timer"; font.pixelSize: 27; font.bold: true; color: "#284c44" }
            Text { anchors.right: parent.right; anchors.rightMargin: 30; y: 32; text: "AbyssTail · Crates"; color: "#748579"; font.pixelSize: 13 }
            Text {
                x: 30; y: 66; width: parent.width-60
                text: timer.connection; color: "#67776e"; font.pixelSize: 14
                elide: Text.ElideRight; textFormat: Text.PlainText
            }
            Rectangle {
                id: clockCard
                x: 30; y: 102; width: parent.width-60; height: parent.height-258
                radius: 22; color: timer.breakDue ? "#f5dfac" : "#e0ebe1"
                border.color: timer.breakDue ? "#ceaa58" : "#c0d3c3"
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: 13; text: timer.state; color: "#486557"; font.pixelSize: 16 }
                Text {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: 8
                    width: parent.width-30; horizontalAlignment: Text.AlignHCenter
                    text: timer.time; font.pixelSize: Math.min(84,clockCard.height*.4)
                    font.bold: true; fontSizeMode: Text.Fit; minimumPixelSize: 30; color: "#244c40"
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                    text: timer.breakDue ? "Take a moment to stretch and rest your eyes." : (timer.followGame ? "Counts while the game is running and not minimized" : "Start and pause whenever you choose")
                    color: "#61796b"; font.pixelSize: 13 }
            }
            Row {
                x: 30; anchors.top: clockCard.bottom; anchors.topMargin: 16; spacing: 10
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: (clockCard.width-30)/4; height: 64; radius: 13
                        color: index === 0 ? "#b8d6bb" : index === 3 ? "#f2dfb7" : "#ede9db"
                        border.width: window.focusIndex === index ? 3 : 1
                        border.color: window.focusIndex === index ? "#bf842d" : "#c6c8b7"
                        opacity: timer.ready || index === 0 ? 1 : .5
                        Text {
                            anchors.fill: parent; anchors.margins: 6; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: index === 0 ? (timer.ready ? timer.action : "Connect") : index === 1 ? "Reset timer" : index === 2 ? (timer.followGame ? "Mode\nGame session" : "Mode\nManual") : "Break reminder\n"+timer.reminder
                            font.pixelSize: 14; color: "#2e5045"; wrapMode: Text.Wrap; textFormat: Text.PlainText
                        }
                        MouseArea { anchors.fill: parent; onClicked: { window.focusIndex=index; window.activate(index) } }
                    }
                }
            }
            Row {
                anchors.left: parent.left; anchors.leftMargin: 30; anchors.bottom: parent.bottom; anchors.bottomMargin: 17; spacing: 12
                Repeater {
                    model: ["Back to TrainerOS", "Close timer"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: index === 0 ? 180 : 120; height: 36; radius: 10
                        color: "#f7f4e9"; border.width: window.focusIndex === index+4 ? 3 : 1
                        border.color: window.focusIndex === index+4 ? "#bf842d" : "#d0d3c5"
                        Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 13; color: "#466257" }
                        MouseArea { anchors.fill: parent; onClicked: { window.focusIndex=index+4; window.activate(index+4) } }
                    }
                }
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 30; anchors.bottom: parent.bottom; anchors.bottomMargin: 27
                text: "Timer continues when this window is minimized"; color: "#748579"; font.pixelSize: 12; visible: parent.width>780 }
        }
    }
}
