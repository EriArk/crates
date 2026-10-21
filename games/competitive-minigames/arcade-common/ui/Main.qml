// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960; height: 640; minimumWidth: 640; minimumHeight: 480
    visible: true; title: game.title; color: "#f4f0e6"
    property bool touchControls: true
    property int padCount: 0
    property string primaryGlyph: "A"
    property string secondaryGlyph: "X"
    property string backGlyph: "B"
    function padDirection(player, direction) {
        if(!game.couch && padCount===1)player=0
        if (direction < 0) { game.control(player, -1); return }
        if (menu && (player === 0 || padCount === 1)) selected = (selected + (direction === 0 || direction === 3 ? 2 : 1)) % 3
        else if (!modal) game.control(player, direction)
    }
    function padRepeat(player, direction) { if(menu) padDirection(player, direction) }
    function padActionRepeat(player, action) { if(!game.couch && padCount===1)player=0;if(!modal && game.slug==="tanks") game.action(player,action) }
    function padButton(player, action) {
        if(!game.couch && padCount===1)player=0
        if (action >= 2) { window.back(); return }
        if (modal) { if(action === 0 && (player === 0 || padCount === 1)) window.primary() }
        else game.action(player, action)
    }
    function padLost(player, unused) { game.neutral(); game.pause(true) }
    property var heldKeys: [[],[]]
    function keyDirection(player, direction, down) {
        var keys=heldKeys[player].filter(function(d){return d!==direction})
        if(down) keys.push(direction)
        heldKeys[player]=keys;game.control(player,keys.length?keys[keys.length-1]:-1)
    }
    onModalChanged: { heldKeys=[[],[]];game.neutral() }
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
            if(d>=0){window.keyDirection(game.couch?1:0,d,true);event.accepted=true;return}
            d=wasd.indexOf(event.key)
            if(d>=0){window.keyDirection(0,d,true);event.accepted=true}
        }
        Keys.onReleased: function(event) {
            if(event.isAutoRepeat)return
            if([Qt.Key_Up,Qt.Key_Right,Qt.Key_Down,Qt.Key_Left].indexOf(event.key)>=0){window.keyDirection(game.couch?1:0,[Qt.Key_Up,Qt.Key_Right,Qt.Key_Down,Qt.Key_Left].indexOf(event.key),false);event.accepted=true}
            if([Qt.Key_W,Qt.Key_D,Qt.Key_S,Qt.Key_A].indexOf(event.key)>=0){window.keyDirection(0,[Qt.Key_W,Qt.Key_D,Qt.Key_S,Qt.Key_A].indexOf(event.key),false);event.accepted=true}
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
        width:parent.width;height:58;color:"#fcf9f1"
        Text {x:16;y:6;text:game.title;font.pixelSize:22;font.bold:true;color:"#2e4c40"}
        Text {x:17;y:34;text:game.online?"FRIEND MATCH · YOU ARE "+(game.seat===0?"MINT":"CORAL"):game.couch?"TWO PLAYERS · TWO CONTROLS":"PRACTICE · YOU AND A BOT";font.pixelSize:11;font.letterSpacing:0.6;color:"#65766a"}
        Button {anchors.right:parent.right;anchors.rightMargin:12;y:8;width:76;height:40;label:menu?"Exit":"Menu";onActivated:window.back()}
    }
    Rectangle {
        id:field
        objectName:"playfield";x:8;y:64;width:parent.width-16;height:parent.height-y-(touchControls?108:36);radius:18;color:game.slug==="light-cycles"?"#172e37":"#e0e9dc"
        Loader {
            id:board;anchors.fill:parent;anchors.margins:4
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
        visible:touchControls;x:8;anchors.bottom:parent.bottom;anchors.bottomMargin:8;width:parent.width-16;height:92;radius:16;color:"#fcf9f1"
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
    Button { anchors.right:parent.right;anchors.rightMargin:96;y:8;width:74;height:40;label:touchControls?"Hide pad":"Touch";onActivated:{game.neutral();touchControls=!touchControls} }
    Text { visible:!touchControls;anchors.bottom:parent.bottom;anchors.bottomMargin:9;anchors.horizontalCenter:parent.horizontalCenter
        text:padCount>0?"D-pad / stick"+(puzzle?"   "+primaryGlyph+" "+game.primaryAction+(secondary?"   "+secondaryGlyph+" "+game.secondaryAction:""):"")+"   "+backGlyph+" / Start Menu":game.couch?"P1 WASD + F / G     P2 Arrows + Enter / Shift     Esc Menu":"Arrows / WASD"+(puzzle?"   Enter "+game.primaryAction+(secondary?"   Shift "+game.secondaryAction:""):"")+"   Esc Menu"
        color:"#4a6657";font.pixelSize:window.width<800?13:16;font.bold:true }
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
