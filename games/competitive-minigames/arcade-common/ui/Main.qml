// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960; height: 540; minimumWidth: 640; minimumHeight: 480
    visible: true; title: game.title; color: brick?"#adb991":"#152b33"
    onActiveChanged:if(active)inputRouter.forceActiveFocus()
    property bool touchControls: true
    readonly property bool brick:game.slug==="mini-racing"||game.slug==="tanks"
    readonly property color ink:brick?"#34432c":"#eff4e7"
    readonly property color panel:brick?"#bac69d":"#203d46"
    readonly property string face:brick?(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono"):Qt.application.font.family
    readonly property real uiScale:height/540
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
        else if (menu) { if(selected===2)Qt.quit(); else game.local(selected===1) }
        else if (waiting) game.leave()
        else if (game.phase === "paused") game.pause(false)
        else if (game.phase === "result") game.rematch()
    }
    Item {
        id:stage;objectName:"gameStage"
        width:window.width/window.uiScale;height:540;scale:window.uiScale;transformOrigin:Item.TopLeft
    Item {
        id:inputRouter;anchors.fill: parent; focus: true
        Component.onCompleted:forceActiveFocus()
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
        property bool highlighted:false
        property color tint:window.panel
        signal activated()
        signal held(bool down)
        radius:brick?0:10;color:touch.pressed?Qt.lighter(tint,1.25):tint
        border.width:highlighted?3:1;border.color:highlighted?(brick?ink:"#a5e3bd"):(brick?ink:"#48717a")
        opacity:enabled?1:0.45
        Text {anchors.centerIn:parent;text:parent.label;color:ink;font.family:face;font.pixelSize:parent.width<65?20:18;font.bold:true}
        TapHandler {id:touch;onPressedChanged:parent.held(pressed);onTapped:parent.activated()}
    }
    Rectangle {
        id:field;objectName:"playfield"
        anchors.fill:parent
        radius:0;color:brick?"#adb991":game.slug==="light-cycles"?"#172e37":"#e0e9dc"
        border.width:0
        Loader {
            id:board;anchors.fill:parent
            source:"qrc:/boards/"+game.slug+".qml"
            onLoaded:item.sceneData=Qt.binding(function(){return window.sceneData})
        }
        Rectangle {
            visible:game.phase==="play"&&window.sceneData.tick<60
            anchors.centerIn:parent;width:96;height:96;radius:brick?0:48;color:panel;border.width:3;border.color:ink
            Text {anchors.centerIn:parent;text:Math.ceil((60-window.sceneData.tick)/30);font.family:face;font.pixelSize:54;font.bold:true;color:ink}
        }
    }
    // Floating controls do not reserve any part of the playfield.
    Row {
        z:5;anchors.right:parent.right;anchors.rightMargin:10;y:8;spacing:6
        Button {objectName:"touchToggle";width:58;height:40;label:"TOUCH";highlighted:touchControls;visible:window.modal;onActivated:{game.neutral();touchControls=!touchControls}}
        Button {objectName:"pauseButton";width:44;height:40;radius:brick?0:20;label:menu?"×":"Ⅱ";onActivated:window.back()}
    }
    // Portraits occupy each game's existing score area, not a shell header.
    Repeater {
        model:2
        PlayerCard {
            required property int index
            readonly property var sizes:({"pong":[960,540],"snake-arena":[600,425],"light-cycles":[700,475],"falling-blocks":[720,400],"minesweeper-race":[760,400],"chain-reaction":[720,400],"mini-racing":[960,480],"tanks":[960,540]})
            readonly property var raster:sizes[game.slug]
            readonly property real zoom:Math.min(stage.width/raster[0],stage.height/raster[1])
            readonly property bool trail:game.slug==="snake-arena"||game.slug==="light-cycles"
            readonly property var position:game.slug==="pong"?[index?602:320,24]:game.slug==="mini-racing"?[382+index*480,78]:game.slug==="minesweeper-race"?[index?420:12,0]:game.slug==="chain-reaction"?[24+index*360,46]:[10+index*360,128]
            visible:!window.modal&&game.slug!=="tanks"
            compact:true;brickStyle:window.brick;width:trail?24:36;height:width
            scale:zoom;transformOrigin:Item.TopLeft
            x:(stage.width-raster[0]*zoom)/2+(trail?(index?raster[0]-26:2):position[0])*zoom
            y:(stage.height-raster[1]*zoom)/2+(trail?raster[1]-25:position[1])*zoom
            property bool own:index===(game.online?game.seat:0)
            descriptor:own?game.avatars.local:game.online?game.avatars.peer:({})
            accent:index===0?"#8eddb4":"#f4aa89"
            current:game.slug==="chain-reaction"&&window.sceneData.turn===index
        }
    }
    Item {
        visible:touchControls&&!window.modal;x:12;anchors.bottom:parent.bottom;anchors.bottomMargin:12;width:parent.width-24;height:58;opacity:0.78
        Repeater {
            model:game.couch?2:1
            Item {
                required property int index
                x:index===0?0:parent.width-width;width:game.couch?(parent.width-16)/2:parent.width;height:58
                Row {
                    y:0;spacing:5
                    Repeater {
                        model:game.slug==="pong"?[0,2]:[3,0,2,1]
                        Button {
                            required property int modelData
                            objectName:"control"+index+"-"+modelData
                            width:stage.width<800?40:48;height:50;label:["↑","→","↓","←"][modelData]
                            enabled:!window.modal
                            onHeld:function(down){game.control(index,down?modelData:-1)}
                        }
                    }
                    Button {objectName:"action"+index+"-0";visible:puzzle;width:72;height:50;label:game.primaryAction;enabled:!window.modal;onActivated:game.action(index,0)}
                    Button {objectName:"action"+index+"-1";visible:secondary;width:72;height:50;label:game.secondaryAction;enabled:!window.modal;onActivated:game.action(index,1)}
                }
            }
        }
    }
    Rectangle {
        visible:window.modal;anchors.fill:parent;color:brick?"#b3adb991":"#c0152b33"
        MouseArea {anchors.fill:parent}
        Rectangle {
            anchors.centerIn:parent;width:Math.min(parent.width-48,660);height:458;radius:brick?0:20;color:panel;border.width:brick?4:2;border.color:brick?ink:"#4e7a80"
            Text {
                x:24;y:24;width:parent.width-48;horizontalAlignment:Text.AlignHCenter;font.family:face;font.pixelSize:32;font.bold:true;color:ink;wrapMode:Text.WordWrap
                text:asking?"LEAVE MATCH?":menu?game.title.toUpperCase():waiting?"CONNECTING":game.phase==="paused"?"PAUSED":game.result.toUpperCase()
            }
            Row {
                anchors.horizontalCenter:parent.horizontalCenter;y:70;spacing:12
                Repeater {model:game.slug==="tanks"&&game.online?1:2;PlayerCard {
                    required property int index
                    width:132;height:44;brickStyle:window.brick
                    property bool own:game.slug==="tanks"&&game.online||index===(game.online?game.seat:0)
                    descriptor:own?game.avatars.local:game.online?game.avatars.peer:({})
                    label:own?"YOU":game.online?"FRIEND":game.couch?"GUEST":"BOT"
                    detail:game.slug==="tanks"&&game.online?"P"+(game.seat+1)+" / "+window.sceneData.players.length:brick?(index===0?"P1 SOLID":"P2 OUTLINE"):(index===0?"MINT":"CORAL")
                    accent:index===0?"#8eddb4":"#f4aa89"
                }}
            }
            Text {
                x:30;y:119;width:parent.width-60;height:menu?135:150;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap;font.family:face;font.pixelSize:20;color:ink
                text:asking?"This round ends. Your Lobby stays available.":menu?(game.status.indexOf("Play offline")===0?game.instructions:game.status):waiting?game.status:game.phase==="paused"?"Ready for another round?":game.voted?"Waiting for your friend…":game.online?"Both players choose PLAY AGAIN.":"Ready for a rematch?"
            }
            Column {
                visible:menu;anchors.bottom:parent.bottom;anchors.bottomMargin:24;anchors.horizontalCenter:parent.horizontalCenter;spacing:10
                Button {objectName:"practiceButton";width:360;height:48;highlighted:selected===0;label:"PRACTICE WITH BOT";onActivated:{selected=0;window.primary()}}
                Button {objectName:"couchButton";width:360;height:48;highlighted:selected===1;label:"TWO ON THIS DEVICE";onActivated:{selected=1;window.primary()}}
                Button {objectName:"exitButton";width:360;height:48;highlighted:selected===2;label:"EXIT";onActivated:{selected=2;window.primary()}}
            }
            Column {
                visible:!menu;anchors.bottom:parent.bottom;anchors.bottomMargin:24;anchors.horizontalCenter:parent.horizontalCenter;spacing:10
                Button {objectName:"primaryButton";width:360;height:52;highlighted:true;label:asking?"LEAVE MATCH":waiting?"CANCEL":game.phase==="paused"?"RESUME":game.voted?"REQUESTED":"PLAY AGAIN";enabled:asking||!game.voted||game.phase!=="result";onActivated:window.primary()}
                Button {visible:asking;width:360;height:48;label:"KEEP PLAYING";onActivated:window.back()}
            }
        }
    }
    }
}
