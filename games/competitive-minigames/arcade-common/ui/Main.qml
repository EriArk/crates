// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960; height: 640; minimumWidth: 640; minimumHeight: 480
    visible: true; title: game.title; color: "#f4f0e6"
    property bool asking: false
    property int selected: 0
    property var sceneData: game.scene
    property bool menu: game.phase === "menu"
    property bool waiting: game.phase === "waiting"
    property bool puzzle: game.primaryAction.length > 0
    property bool secondary: game.secondaryAction.length > 0
    property bool modal: menu || waiting || game.phase === "result" || game.phase === "paused" || asking
    Connections {target:game;function onChanged(){if(game.phase==="menu")window.asking=false}}
    function back() {
        game.neutral()
        if (asking) { asking=false; game.pause(false) }
        else if (menu) Qt.quit()
        else if (game.phase === "paused") game.pause(false)
        else { asking=true; game.pause(true) }
    }
    function primary() {
        if (asking) { asking=false; game.leave() }
        else if (menu) { if(selected===2)game.join(); else game.local(selected===1) }
        else if (waiting) game.lobby()
        else if (game.phase === "paused") game.pause(false)
        else if (game.phase === "result") game.rematch()
    }
    Item {
        anchors.fill: parent; focus: true
        Keys.onPressed: function(event) {
            if(event.key===Qt.Key_Escape){if(!event.isAutoRepeat)window.back();event.accepted=true;return}
            if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter||event.key===Qt.Key_Space){
                if(!event.isAutoRepeat){if(modal)window.primary();else game.action(game.couch&&event.key!==Qt.Key_Space?1:0,0)}event.accepted=true;return
            }
            if(menu&&(event.key===Qt.Key_Up||event.key===Qt.Key_Down||event.key===Qt.Key_Left||event.key===Qt.Key_Right)){
                selected=(selected+(event.key===Qt.Key_Up||event.key===Qt.Key_Left?2:1))%3;event.accepted=true;return
            }
            if(modal)return
            if([Qt.Key_F,Qt.Key_G,Qt.Key_Shift].indexOf(event.key)>=0){
                if(!event.isAutoRepeat)game.action(event.key===Qt.Key_Shift&&game.couch?1:0,event.key===Qt.Key_F?0:1)
                event.accepted=true;return
            }
            var arrows=[Qt.Key_Up,Qt.Key_Right,Qt.Key_Down,Qt.Key_Left]
            var wasd=[Qt.Key_W,Qt.Key_D,Qt.Key_S,Qt.Key_A]
            var d=arrows.indexOf(event.key)
            if(d>=0){game.control(game.couch?1:0,d);event.accepted=true;return}
            d=wasd.indexOf(event.key)
            if(d>=0){game.control(0,d);event.accepted=true}
        }
        Keys.onReleased: function(event) {
            if(event.isAutoRepeat)return
            if([Qt.Key_Up,Qt.Key_Right,Qt.Key_Down,Qt.Key_Left].indexOf(event.key)>=0){game.control(game.couch?1:0,-1);event.accepted=true}
            if([Qt.Key_W,Qt.Key_D,Qt.Key_S,Qt.Key_A].indexOf(event.key)>=0){game.control(0,-1);event.accepted=true}
        }
    }
    component Button: Rectangle {
        property string label
        property bool highlighted: false
        property color tint: "#dce9dd"
        signal activated()
        signal held(bool down)
        radius: 12; color: touch.pressed?Qt.darker(tint,1.08):tint
        border.width: highlighted?3:1; border.color: highlighted?"#34594e":"#c5cec0"
        opacity: enabled?1:0.55
        Text {anchors.centerIn:parent;text:parent.label;color:"#29473d";font.pixelSize:parent.width<65?12:15;font.bold:true}
        TapHandler {
            id:touch
            onPressedChanged:parent.held(pressed)
            onTapped:parent.activated()
        }
    }
    Rectangle {
        width:parent.width;height:76;color:"#fcf9f1"
        Text {x:20;y:13;text:game.title;font.pixelSize:24;font.bold:true;color:"#2e4c40"}
        Text {x:21;y:45;text:game.online?"FRIEND MATCH · YOU ARE "+(game.seat===0?"MINT":"CORAL"):game.couch?"TWO PLAYERS · TWO CONTROLS":"PRACTICE · YOU AND A BOT";font.pixelSize:11;font.letterSpacing:0.6;color:"#65766a"}
        Button {anchors.right:parent.right;anchors.rightMargin:16;y:16;width:90;height:43;label:menu?"Exit":"Menu";onActivated:window.back()}
    }
    Rectangle {
        id:field
        x:16;y:84;width:parent.width-32;height:parent.height-196;radius:18;color:game.slug==="light-cycles"?"#172e37":"#e0e9dc"
        Loader {
            id:board;anchors.fill:parent;anchors.margins:10
            source:"qrc:/boards/"+game.slug+".qml"
            onLoaded:item.sceneData=Qt.binding(function(){return window.sceneData})
        }
        Rectangle {
            visible:game.phase==="play"&&window.sceneData.tick<60
            anchors.centerIn:parent;width:150;height:70;radius:18;color:"#eef3e6"
            Text {anchors.centerIn:parent;text:Math.ceil((60-window.sceneData.tick)/30);font.pixelSize:36;font.bold:true;color:"#34564a"}
        }
    }
    Rectangle {
        x:16;anchors.bottom:parent.bottom;anchors.bottomMargin:12;width:parent.width-32;height:92;radius:16;color:"#fcf9f1"
        Text {x:14;y:8;text:game.couch?(puzzle?(secondary?"MINT · WASD + F / G":"MINT · WASD + F"):"MINT · W A S D / PAD 1"):(puzzle?(secondary?"YOU · ARROWS + ENTER / SHIFT":"YOU · ARROWS + ENTER"):"YOU · ARROWS / PAD 1");font.pixelSize:11;color:"#54745e";font.bold:true}
        Text {anchors.right:parent.right;anchors.rightMargin:14;y:8;text:game.couch?(puzzle?(secondary?"CORAL · ARROWS + ENTER / SHIFT":"CORAL · ARROWS + ENTER"):"CORAL · ARROWS / PAD 2"):game.online?"FRIEND · "+(game.seat===0?"CORAL":"MINT"):"CORAL · BOT";font.pixelSize:11;color:"#9c6958";font.bold:true}
        Row {
            x:8;y:30;spacing:puzzle?4:6
            Repeater {
                model:game.slug==="pong"?[0,2]:[3,0,2,1]
                Button {
                    required property int modelData
                    objectName:"control0-"+modelData
                    width:game.slug==="pong"?68:puzzle&&window.width<800?36:48;height:48;label:["↑","→","↓","←"][modelData]
                    enabled:!window.modal
                    onHeld:function(down){game.control(0,down?modelData:-1)}
                }
            }
            Button {objectName:"action0-0";visible:puzzle;width:58;height:48;label:game.primaryAction;enabled:!window.modal;onActivated:game.action(0,0)}
            Button {objectName:"action0-1";visible:secondary;width:58;height:48;label:game.secondaryAction;enabled:!window.modal;onActivated:game.action(0,1)}
        }
        Row {
            visible:game.couch;anchors.right:parent.right;anchors.rightMargin:8;y:30;spacing:puzzle?4:6
            Repeater {
                model:game.slug==="pong"?[0,2]:[3,0,2,1]
                Button {
                    required property int modelData
                    objectName:"control1-"+modelData
                    width:game.slug==="pong"?68:puzzle&&window.width<800?36:48;height:48;label:["↑","→","↓","←"][modelData];tint:"#eed0bd"
                    enabled:!window.modal
                    onHeld:function(down){game.control(1,down?modelData:-1)}
                }
            }
            Button {objectName:"action1-0";visible:puzzle;width:58;height:48;label:game.primaryAction;tint:"#eed0bd";enabled:!window.modal;onActivated:game.action(1,0)}
            Button {objectName:"action1-1";visible:secondary;width:58;height:48;label:game.secondaryAction;tint:"#eed0bd";enabled:!window.modal;onActivated:game.action(1,1)}
        }
        Text {visible:!game.couch;anchors.right:parent.right;anchors.rightMargin:18;y:37;text:puzzle?"PAD: A · "+game.primaryAction+(secondary?" / X · "+game.secondaryAction:""):game.slug==="pong"?"FIRST TO 5":game.slug==="snake-arena"?"GROW · TURN · SURVIVE":"TURN · TRAP · SURVIVE";font.pixelSize:12;font.bold:true;color:"#697b6a"}
    }
    Rectangle {
        visible:window.modal;x:field.x;y:field.y;width:field.width;height:field.height;radius:18;color:"#88354a43"
        MouseArea {anchors.fill:parent}
        Rectangle {
            anchors.centerIn:parent;width:Math.min(parent.width-24,570);height:Math.min(parent.height-12,370);radius:20;color:"#fcf8ed";border.color:"#d4dcc9"
            Text {
                x:20;y:14;width:parent.width-40;horizontalAlignment:Text.AlignHCenter;font.pixelSize:25;font.bold:true;color:"#2f5143"
                text:asking?"Leave this match?":menu?game.subtitle:waiting?"Meet in GameHub Lobby":game.phase==="paused"?"Take a moment":game.result
                wrapMode:Text.WordWrap
            }
            Text {
                x:24;y:menu?60:65;width:parent.width-48;height:parent.height-(menu?158:130);horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap;font.pixelSize:14;color:"#5d7162"
                text:asking?(game.online?"This round ends. Your TrainerOS Lobby stays open.":"This round ends. You can start a fresh match."):menu?(game.status.indexOf("Play offline")===0?game.instructions:game.status):waiting?game.status:game.phase==="paused"?"Resume when both players are ready.":game.voted?"Rematch requested. Waiting for your friend…":game.online?"Both players choose Play again for a fresh match.":"Play again for a fresh match."
            }
            Column {
                visible:menu;anchors.bottom:parent.bottom;anchors.bottomMargin:12;anchors.horizontalCenter:parent.horizontalCenter;spacing:6
                Row {
                    spacing:8
                    Button {objectName:"practiceButton";width:210;height:42;highlighted:selected===0;label:"Practice with bot";onActivated:{selected=0;window.primary()}}
                    Button {objectName:"couchButton";width:210;height:42;highlighted:selected===1;label:"Two on this device";tint:"#eed0bd";onActivated:{selected=1;window.primary()}}
                }
                Button {objectName:"onlineButton";anchors.horizontalCenter:parent.horizontalCenter;width:260;height:42;highlighted:selected===2;label:"Play with a friend";onActivated:{selected=2;window.primary()}}
            }
            Row {
                visible:!menu;anchors.bottom:parent.bottom;anchors.bottomMargin:14;anchors.horizontalCenter:parent.horizontalCenter;spacing:10
                Button {objectName:"primaryButton";width:210;height:44;highlighted:true;label:asking?"Leave match":waiting?"Open Lobby":game.phase==="paused"?"Resume":game.voted?"Rematch requested":"Play again";enabled:asking||!game.voted||game.phase!=="result";onActivated:window.primary()}
                Button {visible:asking;width:140;height:44;label:"Keep playing";tint:"#eed0bd";onActivated:window.back()}
            }
        }
    }
}
