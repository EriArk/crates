// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Rectangle {
    id:root
    property var descriptor: ({})
    property string label:"PLAYER"
    property string detail:""
    property bool current:false
    property color accent:"#8eddb4"
    property real unit:height/48
    radius:14;color:current?"#fffdf4":"#edf1e9"
    border.width:current?2:1;border.color:current?accent:"#d2ddd4"
    Rectangle {x:5;y:5;width:parent.height-10;height:width;radius:12;color:Qt.lighter(root.accent,1.22)
        AvatarPortrait {anchors.fill:parent;descriptor:root.descriptor}
    }
    Column {x:root.height+2;anchors.verticalCenter:parent.verticalCenter;spacing:2
        Text {text:root.label;font.pixelSize:11*root.unit;font.bold:true;color:"#29473d"}
        Text {text:root.detail;font.pixelSize:10*root.unit;color:"#65766a"}
    }
    Rectangle {visible:root.current;anchors.right:parent.right;anchors.rightMargin:7;anchors.verticalCenter:parent.verticalCenter;width:5;height:5;radius:3;color:root.accent}
}
