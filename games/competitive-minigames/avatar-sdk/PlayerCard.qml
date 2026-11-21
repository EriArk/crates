// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Rectangle {
    id:root
    property var descriptor: ({})
    property string label:"PLAYER"
    property string detail:""
    property bool current:false
    property color accent:"#8eddb4"
    property bool brickStyle:false
    property bool compact:false
    property real unit:height/48
    radius:brickStyle?0:compact?height/2:10;color:brickStyle?"#bac69d":"#edf1e9"
    border.width:current?3:1;border.color:brickStyle?"#34432c":current?accent:"#d2ddd4"
    Rectangle {x:root.compact?2:5;y:x;width:parent.height-2*x;height:width;radius:root.brickStyle?0:10;color:root.brickStyle?"#adb991":Qt.lighter(root.accent,1.22)
        AvatarPortrait {anchors.fill:parent;descriptor:root.descriptor;brickStyle:root.brickStyle}
    }
    Column {visible:!root.compact;x:root.height+2;anchors.verticalCenter:parent.verticalCenter;spacing:2
        Text {text:root.label;font.pixelSize:16*root.unit;font.bold:true;color:root.brickStyle?"#34432c":"#29473d";font.family:root.brickStyle?(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono"):Qt.application.font.family}
        Text {text:root.detail;font.family:root.brickStyle?(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono"):Qt.application.font.family;font.pixelSize:12*root.unit;color:root.brickStyle?"#34432c":"#65766a"}
    }
    Rectangle {visible:root.current;anchors.right:parent.right;anchors.rightMargin:7;anchors.verticalCenter:parent.verticalCenter;width:5;height:5;radius:root.brickStyle?0:3;color:root.brickStyle?"#34432c":root.accent}
}
