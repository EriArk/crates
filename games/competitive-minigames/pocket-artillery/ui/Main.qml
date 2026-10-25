// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window

Window {
    id: window
    width: 960; height: 540; minimumWidth: 640; minimumHeight: 440
    visible: true; title: "Pocket Artillery"; color: "#152b33"
    onActiveChanged:if(active)inputRouter.forceActiveFocus()
    property bool touchControls: true
    property real cardScale:1
    readonly property real uiScale:height/540
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
    function padButton(player, action) { if(action >= 2) window.back(); else if(action === 0) window.primary(); else if(action === 1) window.toggleOverview() }
    function padLost(player, unused) { if(!menu) asking=true }
    property bool wideView: false
    function toggleOverview() { if(game.canFire && !asking) wideView=!wideView }
    property bool asking: false
    property int selected: 0
    property var sceneData: game.scene
    property bool menu: game.phase === "menu"
    property bool waiting: game.phase === "waiting"
    property bool overlay: menu || waiting || game.phase === "handoff" || game.phase === "result" || asking
    function back() { if (asking) asking = false; else if (menu) Qt.quit(); else asking = true }
    function primary() {
        if (asking) { game.leave(); asking = false }
        else if (menu) { if (selected === 0) game.local(); else Qt.quit() }
        else if (waiting) game.leave()
        else if (game.phase === "handoff") game.acceptTurn()
        else if (game.phase === "result") game.rematch()
        else game.fire()
    }
    Item {
        id:uiStage;objectName:"gameStage"
        width:window.width/window.uiScale;height:540;scale:window.uiScale;transformOrigin:Item.TopLeft
    Item {
        id:inputRouter;anchors.fill: parent; focus: true
        Component.onCompleted:forceActiveFocus()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Tab) { if(!event.isAutoRepeat) window.toggleOverview(); event.accepted=true }
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
        property color tint: "#203d46"
        signal activated()
        radius: 12; color: enabled ? (touch.pressed ? Qt.darker(tint,1.1) : tint) : "#e5e1d7"
        border.width: highlighted ? 3 : 1; border.color: highlighted ? "#345b50" : "#c7cfc0"
        opacity: enabled ? 1 : 0.55
        Text { anchors.centerIn: parent; text: parent.label; color: "#eff4e7"; font.pixelSize: 19; font.bold: true }
        MouseArea { id: touch; anchors.fill: parent; onClicked: parent.activated() }
    }
    Battlefield {
        id: battlefield; objectName: "battlefield"
        anchors.fill:parent
        closeAim: game.canFire && !window.asking && !window.wideView
        overview: window.wideView
        overviewKey: window.padCount > 0 ? window.secondaryGlyph : "Tab"
        onOverviewRequested: window.toggleOverview()
    }
    Connections { target: game; function onChanged() { if (!game.canFire) window.wideView=false } }
    Row {
        z:5;anchors.right:parent.right;anchors.rightMargin:12;y:10;spacing:8
        Button {width:66;height:42;label:"Touch";visible:window.overlay;highlighted:touchControls;onActivated:touchControls=!touchControls}
        Button {width:44;height:42;radius:21;label:menu?"×":"Ⅱ";onActivated:window.back()}
    }
    // Aim controls float over the ground, disappear during flight, and never resize it.
    Row {
        visible:touchControls&&game.canFire&&!overlay;x:18;anchors.bottom:parent.bottom;anchors.bottomMargin:18;spacing:8
        Button {width:48;height:48;label:"←";onActivated:game.aim(-1)}
        Button {width:48;height:48;label:"→";onActivated:game.aim(1)}
        Button {width:48;height:48;label:"−";onActivated:game.charge(-1)}
        Button {width:48;height:48;label:"+";onActivated:game.charge(1)}
    }
    Button {
        objectName:"fireButton";visible:game.canFire&&!overlay
        anchors.right:parent.right;anchors.rightMargin:18;anchors.bottom:parent.bottom;anchors.bottomMargin:18
        width:touchControls?88:126;height:touchControls?72:48;radius:touchControls?36:24
        label:touchControls?"FIRE":(padCount?primaryGlyph:"↵")+"  FIRE";tint:"#785443";onActivated:game.fire()
    }
    Rectangle {
        visible: overlay; anchors.fill:parent; color: "#c0152b33"
        MouseArea { anchors.fill: parent } // No click-through into the battlefield.
        Rectangle {
            width: Math.min(parent.width-48,640); height:400; radius: 20; anchors.centerIn: parent; color: "#203d46"; border.color: "#4e7a80"
            Text { x:20; y:16; width:parent.width-40; horizontalAlignment:Text.AlignHCenter; text: asking?"Leave this duel?":menu?"A little friendly fire":game.message; wrapMode:Text.WordWrap; font.pixelSize:30; font.bold:true; color:"#eff4e7" }
            Text {
                x:24; y:72; width:parent.width-48; height:parent.height-124; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter; wrapMode:Text.WordWrap; color:"#eff4e7"; font.pixelSize:20
                text: asking?"This round will end. Your TrainerOS Lobby stays open.":menu?"Arc a shell over the hills. Carve a crater.\nLast tank standing wins.\n\n"+game.connection:waiting?game.connection:game.phase==="handoff"?"Left / right: angle · Up / down: power\nConfirm: fire · Back: menu\nHold a direction to adjust. Touch controls are optional.":game.voted?"Rematch requested. Waiting for your friend…":game.online?"Another round starts when both players agree.":"Try a new landscape. The starting player alternates."
            }
            Row {
                anchors.bottom:parent.bottom; anchors.bottomMargin:14; anchors.horizontalCenter:parent.horizontalCenter; spacing:10
                Button { objectName:"primaryButton"; width:menu?Math.min(210,(window.width-100)/2):210; height:52; highlighted:!menu||selected===0; label:asking?"Leave duel":menu?"Play on one device":waiting?"Cancel":game.phase==="handoff"?"Ready to aim":game.voted?"Rematch requested":"Play again"; enabled:!(!asking&&game.phase==="result"&&game.voted); onActivated:{if(menu)selected=0;window.primary()} }
                Button { visible:menu||asking; width:menu?Math.min(210,(window.width-100)/2):140; height:52; highlighted:menu&&selected===1; label:asking?"Keep playing":"Exit"; tint:"#efcfb9"; onActivated:{if(asking)asking=false;else{selected=1;Qt.quit()}} }
            }
        }
    }
    }
}
