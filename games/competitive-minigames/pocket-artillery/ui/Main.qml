// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960; height: 600; minimumWidth: 640; minimumHeight: 440
    visible: true; title: "Pocket Artillery"; color: "#f5f0e4"
    property bool touchControls: true
    property int padCount: 0
    property string primaryGlyph: "A"
    property string secondaryGlyph: "X"
    property string backGlyph: "B"
    function padDirection(player, direction) {
        if (direction < 0) return
        if (menu) selected = 1-selected
        else if (!overlay) {
            if(direction === 1 || direction === 3) game.aim(direction === 3 ? -1 : 1)
            else game.charge(direction === 2 ? -1 : 1)
        }
    }
    function padRepeat(player, direction) { padDirection(player, direction) }
    function padActionRepeat(player, action) { }
    function padButton(player, action) { if(action >= 2) window.back(); else if(action === 0) window.primary() }
    function padLost(player, unused) { if(!menu) asking=true }
    property bool asking: false
    property int selected: 0
    property var sceneData: game.scene
    property bool menu: game.phase === "menu"
    property bool waiting: game.phase === "waiting"
    property bool overlay: menu || waiting || game.phase === "handoff" || game.phase === "result" || asking
    function back() { if (asking) asking = false; else if (menu) Qt.quit(); else asking = true }
    function primary() {
        if (asking) { game.leave(); asking = false }
        else if (menu) { if (selected === 0) game.local(); else game.join() }
        else if (waiting) game.lobby()
        else if (game.phase === "handoff") game.acceptTurn()
        else if (game.phase === "result") game.rematch()
        else game.fire()
    }
    Item {
        anchors.fill: parent; focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { if (!event.isAutoRepeat) window.back(); event.accepted = true }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (!event.isAutoRepeat) window.primary(); event.accepted = true
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                if (menu) selected = 1-selected
                else if (!overlay) game.aim(event.key === Qt.Key_Left ? -1 : 1)
                event.accepted = true
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                if (menu) selected = 1-selected
                else if (!overlay) game.charge(event.key === Qt.Key_Down ? -1 : 1)
                event.accepted = true
            }
        }
    }
    component Button: Rectangle {
        property string label
        property bool highlighted: false
        property color tint: "#e2eadc"
        signal activated()
        radius: 12; color: enabled ? (touch.pressed ? Qt.darker(tint,1.1) : tint) : "#e5e1d7"
        border.width: highlighted ? 3 : 1; border.color: highlighted ? "#345b50" : "#c7cfc0"
        opacity: enabled ? 1 : 0.55
        Text { anchors.centerIn: parent; text: parent.label; color: "#243d36"; font.pixelSize: 15; font.bold: true }
        MouseArea { id: touch; anchors.fill: parent; onClicked: parent.activated() }
    }
    Rectangle {
        x: 0; y: 0; width: parent.width; height: 58; color: "#faf7ef"
        Text { x: 16; y: 7; text: "POCKET ARTILLERY"; font.pixelSize: width < 700 ? 17 : 19; font.bold: true; color: "#294a40" }
        Text { x: 16; y: 34; text: game.online ? "FRIEND DUEL  ·  YOU ARE " + (game.seat === 0 ? "MINT" : "CORAL") : "TWO PLAYERS  ·  ONE DEVICE"; font.pixelSize: 11; font.letterSpacing: 1; color: "#64776b" }
        Button { anchors.right: parent.right; anchors.rightMargin: 12; y: 8; width: 76; height: 40; label: menu ? "Exit" : "Menu"; onActivated: window.back() }
    }
    Rectangle {
        id: battlefield
        x: 8; y: 64; width: parent.width-16; height: parent.height-y-(touchControls?108:62)
        radius: 18; color: "#dce9e2"; clip: true
        Canvas {
            id: canvas; anchors.centerIn:parent;width:parent.width;height:parent.height
            property real skyTop:game.phase==="flight"?window.sceneData.arcTop:-20
            Behavior on skyTop { NumberAnimation {duration:220} }
            onSkyTopChanged:requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c=getContext("2d"); c.reset(); var scale=Math.min(width/960,height/(400-skyTop));c.translate((width-960*scale)/2,height-400*scale);c.scale(scale,scale)
                var sky=c.createLinearGradient(0,0,0,400);sky.addColorStop(0,"#c8dedc");sky.addColorStop(1,"#f3ebcd")
                c.fillStyle=sky;c.fillRect(0,-600,960,1000)
                c.fillStyle="#fcf1c5";c.beginPath();c.arc(748,83,37,0,Math.PI*2);c.fill()
                c.fillStyle="#b8cec0";c.beginPath();c.moveTo(0,280);c.lineTo(0,224);c.lineTo(170,132);c.lineTo(310,250);c.lineTo(515,128);c.lineTo(733,262);c.lineTo(900,165);c.lineTo(960,210);c.lineTo(960,400);c.lineTo(0,400);c.fill()
                c.fillStyle="#cbd5b5";c.beginPath();c.moveTo(0,400);c.lineTo(0,270);c.quadraticCurveTo(230,180,470,280);c.quadraticCurveTo(690,190,960,270);c.lineTo(960,400);c.fill()
                c.beginPath();c.moveTo(0,400)
                for(var i=0;i<window.sceneData.terrain.length;i++)c.lineTo(i*5,window.sceneData.terrain[i])
                c.lineTo(960,400);c.closePath();c.fillStyle="#a78c69";c.fill()
                c.beginPath();for(i=0;i<window.sceneData.terrain.length;i++){if(i===0)c.moveTo(0,window.sceneData.terrain[i]);else c.lineTo(i*5,window.sceneData.terrain[i])}
                c.strokeStyle="#637d50";c.lineWidth=7;c.lineJoin="round";c.stroke()
                for(i=0;i<2;i++){
                    var tx=i===0?120:840,ty=i===0?window.sceneData.y0:window.sceneData.y1
                    c.save();c.translate(tx,ty);c.scale(1.65,1.65);c.translate(-tx,-ty)
                    var active=window.sceneData.turn===i&&!overlay&&game.phase!=="flight"
                    var a=(active?game.angle:45)*Math.PI/180, direction=i===0?1:-1
                    if(active){c.beginPath();c.arc(tx,ty-7,29,0,Math.PI*2);c.strokeStyle="#ffffff";c.lineWidth=2;c.stroke()}
                    c.strokeStyle="#314c42";c.lineWidth=7;c.lineCap="round";c.beginPath();c.moveTo(tx,ty-15);c.lineTo(tx+direction*26*Math.cos(a),ty-15-26*Math.sin(a));c.stroke()
                    c.fillStyle="#314c42";c.fillRect(tx-19,ty-10,38,10)
                    c.fillStyle=i===0?"#8ad5b4":"#efac99";c.fillRect(tx-16,ty-18,32,13)
                    c.beginPath();c.arc(tx,ty-18,9,Math.PI,Math.PI*2);c.fill()
                    c.fillStyle="#e4e7ca";for(var t=-12;t<=12;t+=8){c.beginPath();c.arc(tx+t,ty-4,3,0,Math.PI*2);c.fill()}
                    c.restore()
                }
                c.fillStyle="#fff9e3";c.globalAlpha=0.65
                for(i=0;i<window.sceneData.trail.length;i+=3){c.beginPath();c.arc(window.sceneData.trail[i].x,window.sceneData.trail[i].y,2,0,Math.PI*2);c.fill()}
                c.globalAlpha=1
                if(game.phase==="flight"&&window.sceneData.impactAge<0){c.shadowColor="#ffe5a2";c.shadowBlur=18;c.fillStyle="#e4814b";c.beginPath();c.arc(window.sceneData.shellX,window.sceneData.shellY,7,0,Math.PI*2);c.fill();c.shadowBlur=0}
                var age=window.sceneData.impactAge
                if(age>=0&&window.sceneData.hit){
                    var ex=window.sceneData.impactX,ey=window.sceneData.impactY,progress=age/24
                    c.globalAlpha=1-progress;c.fillStyle="#fff1c2";c.beginPath();c.arc(ex,ey,8+progress*46,0,Math.PI*2);c.fill()
                    c.strokeStyle="#dc8b48";c.lineWidth=5;c.beginPath();c.arc(ex,ey,12+progress*65,0,Math.PI*2);c.stroke()
                    for(var n=0;n<22;n++){var direction=n*2.39996,dist=progress*(28+n*3);c.fillStyle=n%2?"#b8754d":"#ffd48c";c.fillRect(ex+Math.cos(direction)*dist,ey+Math.sin(direction)*dist+progress*progress*45,6,6)}c.globalAlpha=1
                }
            }
        }
        Row {
            anchors.top: parent.top; anchors.topMargin: 12; anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    width: Math.min(160,battlefield.width/3); height: 46; radius: 12; color: "#eff4e9"
                    Text { objectName: "health"+index; x: 12; y: 7; text: (index===0?"MINT":"CORAL")+"  "+(index===0?window.sceneData.hp0:window.sceneData.hp1); font.bold:true; font.pixelSize:12; color:"#344c41" }
                    Rectangle { x:12; y:29; width:parent.width-24; height:6; radius:3; color:"#d3dccd"
                        Rectangle { width:parent.width*(index===0?window.sceneData.hp0:window.sceneData.hp1)/100; height:6; radius:3; color:index===0?"#61b890":"#df8f7a" }
                    }
                }
            }
        }
    }
    Connections { target: game; function onChanged() { canvas.requestPaint() } }
    onOverlayChanged: canvas.requestPaint()
    Rectangle {
        visible: touchControls; x: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; width: parent.width-16; height: 90; radius: 16; color: "#faf7ef"
        Text { x: 14; y: 8; text: game.message; font.pixelSize: 14; font.bold: true; color: "#385346" }
        Row {
            x: 12; y: 34; spacing: 6
            Button { width: 40; height: 44; label: "−"; enabled: game.canFire&&!asking; onActivated: game.aim(-1) }
            Text { width: window.width < 720 ? 76 : 106; height: 44; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "Angle "+game.angle+"°"; font.pixelSize: 14; color: "#344b40" }
            Button { width: 40; height: 44; label: "+"; enabled: game.canFire&&!asking; onActivated: game.aim(1) }
            Item { width: window.width<720?0:12; height: 44 }
            Button { width: 40; height: 44; label: "−"; enabled: game.canFire&&!asking; onActivated: game.charge(-1) }
            Text { width: window.width < 720 ? 76 : 106; height: 44; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: "Power "+game.power; font.pixelSize: 14; color: "#344b40" }
            Button { width: 40; height: 44; label: "+"; enabled: game.canFire&&!asking; onActivated: game.charge(1) }
        }
        Button { objectName: "fireButton"; anchors.right: parent.right; anchors.rightMargin: 12; y: 34; width: window.width<720?130:170; height: 44; label: "FIRE  ↵"; tint: "#edb59b"; enabled: game.canFire&&!asking; onActivated: game.fire() }
    }
    Button { anchors.right:parent.right;anchors.rightMargin:96;y:8;width:74;height:40;label:touchControls?"Hide pad":"Touch";onActivated:touchControls=!touchControls }
    Column { visible:!touchControls;anchors.bottom:parent.bottom;anchors.bottomMargin:8;anchors.horizontalCenter:parent.horizontalCenter;spacing:4
        Text { anchors.horizontalCenter:parent.horizontalCenter;text:"ANGLE "+game.angle+"°     POWER "+game.power+"     "+game.message;color:"#314f42";font.pixelSize:window.width<800?14:18;font.bold:true }
        Text { anchors.horizontalCenter:parent.horizontalCenter;text:padCount>0?"Stick / D-pad: aim and power     "+primaryGlyph+": fire     "+backGlyph+" / Start: menu":"Left / right: angle     Up / down: power     Enter: fire     Esc: menu";color:"#597060";font.pixelSize:13 }
    }
    Rectangle {
        visible: overlay; x: 8; y: 64; width: parent.width-16; height: parent.height-y-(touchControls?108:62); radius: 18; color: "#77405145"
        MouseArea { anchors.fill: parent } // No click-through into the battlefield.
        Rectangle {
            width: Math.min(parent.width-28,540); height: Math.min(parent.height-16,270); radius: 20; anchors.centerIn: parent; color: "#faf7ee"; border.color: "#d6dcc9"
            Text { x:20; y:16; width:parent.width-40; horizontalAlignment:Text.AlignHCenter; text: asking?"Leave this duel?":menu?"A little friendly fire":game.message; wrapMode:Text.WordWrap; font.pixelSize:window.height<500?22:27; font.bold:true; color:"#2e5041" }
            Text {
                x:24; y:window.height<500?50:63; width:parent.width-48; height:parent.height-124; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter; wrapMode:Text.WordWrap; color:"#5b6e60"; font.pixelSize:14
                text: asking?"This round will end. Your TrainerOS Lobby stays open.":menu?"Arc a shell over the hills. Carve a crater.\nLast tank standing wins.\n\n"+game.connection:waiting?game.connection:game.phase==="handoff"?"Left / right: angle · Up / down: power\nConfirm: fire · Back: menu\nHold a direction to adjust. Touch controls are optional.":game.voted?"Rematch requested. Waiting for your friend…":game.online?"Another round starts when both players agree.":"Try a new landscape. The starting player alternates."
            }
            Row {
                anchors.bottom:parent.bottom; anchors.bottomMargin:14; anchors.horizontalCenter:parent.horizontalCenter; spacing:10
                Button { objectName:"primaryButton"; width:menu?Math.min(210,(window.width-100)/2):210; height:44; highlighted:!menu||selected===0; label:asking?"Leave duel":menu?"Play on one device":waiting?"Open Lobby":game.phase==="handoff"?"Ready to aim":game.voted?"Rematch requested":"Play again"; enabled:!(!asking&&game.phase==="result"&&game.voted); onActivated:{if(menu)selected=0;window.primary()} }
                Button { visible:menu||asking; width:menu?Math.min(210,(window.width-100)/2):140; height:44; highlighted:menu&&selected===1; label:asking?"Keep playing":"Play with a friend"; tint:"#efcfb9"; onActivated:{if(asking)asking=false;else{selected=1;game.join()}} }
            }
        }
    }
}
