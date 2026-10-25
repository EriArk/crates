// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

Rectangle {
    id:stage
    property var sceneData: game.scene
    property bool closeAim: false
    property bool overview: false
    property string overviewKey: "Tab"
    signal overviewRequested()
    readonly property bool flying: game.phase === "flight"
    readonly property bool impact: flying && sceneData.impactAge >= 0 && sceneData.hit
    readonly property real impactSeconds: impact ? sceneData.impactAge * 0.024 : 0
    readonly property real shotSeconds: flying ? sceneData.flightFrame * 0.024 : 10
    readonly property real aimScale: Math.min(width/600, (height-96)/200)
    readonly property real fullScale: Math.min((width-24)/960, (height-108)/(400-(flying?sceneData.arcTop:-20)))
    readonly property real targetScale: closeAim ? aimScale : impact ? aimScale*0.9 : fullScale
    property real cameraScale: targetScale
    property real cameraX: closeAim ? width*(sceneData.turn===0?0.22:0.78)-(sceneData.turn===0?120:840)*targetScale
                                   : impact ? width/2-sceneData.impactX*targetScale : (width-960*targetScale)/2
    property real cameraY: closeAim ? height*0.78-(sceneData.turn===0?sceneData.y0:sceneData.y1)*targetScale
                                   : impact ? height*0.72-sceneData.impactY*targetScale : height-12-400*targetScale
    property real tankY0: sceneData.y0
    property real tankY1: sceneData.y1
    Behavior on cameraScale {NumberAnimation {duration:360;easing.type:Easing.InOutCubic}}
    Behavior on cameraX {NumberAnimation {duration:360;easing.type:Easing.InOutCubic}}
    Behavior on cameraY {NumberAnimation {duration:360;easing.type:Easing.InOutCubic}}
    Behavior on tankY0 {NumberAnimation {duration:220;easing.type:Easing.OutCubic}}
    Behavior on tankY1 {NumberAnimation {duration:220;easing.type:Easing.OutCubic}}
    function screenX(x) { return cameraX+x*cameraScale }
    function screenY(y) { return cameraY+y*cameraScale }
    function repaint() {if(canvas)canvas.requestPaint();if(mini)mini.requestPaint()}
    onCameraScaleChanged:repaint()
    onCameraXChanged:repaint()
    onCameraYChanged:repaint()
    onTankY0Changed:repaint()
    onTankY1Changed:repaint()
    onSceneDataChanged:repaint()
    onCloseAimChanged:repaint()
    Connections {target:game;function onChanged(){stage.repaint()}}
    radius:0;color:"#c9ded7";clip:true

    Canvas {
        id:canvas;objectName:"boardCanvas";anchors.fill:parent
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            var s=stage.sceneData;if(!s.terrain)return
            var c=getContext("2d");c.reset()
            var sky=c.createLinearGradient(0,0,0,height);sky.addColorStop(0,"#bcdad9");sky.addColorStop(1,"#f2e8c4")
            c.fillStyle=sky;c.fillRect(0,0,width,height)
            // Distant scenery follows the camera more gently than the playable ground.
            c.save();c.translate(width*0.1+stage.cameraX*0.2,height*0.18)
            c.fillStyle="#fff0bd";c.beginPath();c.arc(width*0.65,20,34,0,Math.PI*2);c.fill()
            c.fillStyle="#a9c7bd";c.beginPath();c.moveTo(-width,height)
            for(var m=-3;m<12;m++)c.lineTo(m*180,(m%2===0?80:190))
            c.lineTo(width*3,height);c.fill();c.restore()
            c.save();c.translate(stage.cameraX,stage.cameraY);c.scale(stage.cameraScale,stage.cameraScale)
            c.fillStyle="#b7c995";c.beginPath();c.moveTo(-960,900);c.lineTo(-960,230)
            for(var h=-3;h<12;h++)c.quadraticCurveTo(h*180+90,175+(h%3)*25,h*180+180,265)
            c.lineTo(2400,900);c.fill()
            c.beginPath();c.moveTo(-960,900);c.lineTo(-960,s.terrain[0]);c.lineTo(0,s.terrain[0])
            for(var i=0;i<s.terrain.length;i++)c.lineTo(i*5,s.terrain[i])
            c.lineTo(1920,s.terrain[s.terrain.length-1]);c.lineTo(1920,900);c.closePath()
            var earth=c.createLinearGradient(0,220,0,500);earth.addColorStop(0,"#b69a70");earth.addColorStop(1,"#8b755b")
            c.fillStyle=earth;c.fill();c.save();c.clip()
            c.fillStyle="#c9ac7b";for(i=-40;i<240;i++){var rx=i*13,ry=300+(i*i%113);c.fillRect(rx,ry,3+(i%3+3)%3,2)}c.restore()
            c.beginPath();c.moveTo(-960,s.terrain[0]);c.lineTo(0,s.terrain[0]);for(i=1;i<s.terrain.length;i++)c.lineTo(i*5,s.terrain[i]);c.lineTo(1920,s.terrain[s.terrain.length-1])
            c.strokeStyle="#537650";c.lineWidth=8;c.lineJoin="round";c.stroke();c.strokeStyle="#92ad68";c.lineWidth=3;c.stroke()
            for(i=0;i<2;i++){
                var tx=i===0?120:840,ty=i===0?stage.tankY0:stage.tankY1
                var active=game.canFire&&s.turn===i,shooting=stage.flying&&s.shooter===i
                var a=(shooting?s.shotAngle:active?game.angle:45)*Math.PI/180,dir=i===0?1:-1
                var kick=shooting&&stage.shotSeconds<0.45?Math.sin(Math.min(1,stage.shotSeconds/0.45)*Math.PI)*6:0
                var hurt=stage.impact&&(i===0?s.damage0:s.damage1)>0
                c.save();c.translate(tx,ty);c.scale(1,0.25);c.fillStyle="rgba(60,55,38,0.28)";c.beginPath();c.arc(0,4,36,0,Math.PI*2);c.fill();c.restore()
                c.save();c.translate(tx-dir*kick*0.3,ty);c.scale(1.65,1.65)
                c.lineCap="round";c.strokeStyle="#2c4c42";c.lineWidth=9;c.beginPath();c.moveTo(-dir*kick*Math.cos(a),-15+kick*Math.sin(a));c.lineTo(dir*(26-kick)*Math.cos(a),-15-(26-kick)*Math.sin(a));c.stroke()
                c.strokeStyle=i===0?"#8cd4b2":"#eba793";c.lineWidth=3;c.stroke()
                c.fillStyle="#2d4840";c.fillRect(-19,-10,38,10)
                c.fillStyle=hurt&&s.impactAge%8<4?"#fff3cc":i===0?"#77c9a5":"#e69b87";c.fillRect(-16,-18,32,13)
                c.beginPath();c.arc(0,-18,9,Math.PI,Math.PI*2);c.fill()
                c.fillStyle="rgba(255,255,255,0.25)";c.fillRect(-14,-17,27,3)
                c.fillStyle="#dce5bd";for(var t=-12;t<=12;t+=8){c.beginPath();c.arc(t,-4,3,0,Math.PI*2);c.fill()}
                c.restore()
                if(active&&stage.closeAim){
                    var mx=tx+dir*43*Math.cos(a),my=ty-25-43*Math.sin(a)
                    c.strokeStyle="#fdf8d7";c.lineWidth=2;c.setLineDash([4,5]);c.beginPath();c.moveTo(mx,my);c.lineTo(mx+dir*65*Math.cos(a),my-65*Math.sin(a));c.stroke();c.setLineDash([])
                    c.strokeStyle="#365f4c";c.lineWidth=2;c.beginPath();c.arc(tx,ty-25,62,dir===1?-a:Math.PI,dir===1?0:Math.PI+a);c.stroke()
                }
            }
            // Muzzle flash and smoke use the received shot angle, including peer shots.
            if(stage.flying&&stage.shotSeconds<1.1){
                var shooter=s.shooter,sx=shooter===0?120:840,sd=shooter===0?1:-1,sa=s.shotAngle*Math.PI/180
                var muzzleX=sx+sd*43*Math.cos(sa),muzzleY=s.muzzleY-25-43*Math.sin(sa),time=stage.shotSeconds
                if(time<0.16){c.fillStyle="#fff7c9";c.beginPath();for(var f=0;f<12;f++){var fa=f*Math.PI/6,fr=f%2?8:23;c.lineTo(muzzleX+Math.cos(fa)*fr,muzzleY+Math.sin(fa)*fr)}c.closePath();c.fill()}
                for(var puff=0;puff<6;puff++){c.globalAlpha=Math.max(0,0.34-time*0.28);c.fillStyle="#e8e7cf";c.beginPath();c.arc(muzzleX+sd*(puff*3+time*14),muzzleY-time*(20+puff*3),5+puff+time*9,0,Math.PI*2);c.fill()}c.globalAlpha=1
            }
            c.fillStyle="#fff9db";c.globalAlpha=0.55
            for(i=0;i<s.trail.length;i+=2){c.beginPath();c.arc(s.trail[i].x,s.trail[i].y,Math.max(2,1.2/stage.cameraScale),0,Math.PI*2);c.fill()}c.globalAlpha=1
            if(stage.flying&&s.impactAge<0){
                // Keep the projectile readable even when a high arc needs a wide camera.
                var shellRadius=Math.max(6,4/stage.cameraScale)
                c.fillStyle="rgba(255,233,168,0.35)";c.beginPath();c.arc(s.shellX,s.shellY,shellRadius*1.9,0,Math.PI*2);c.fill()
                c.fillStyle="#f6ca78";c.beginPath();c.arc(s.shellX,s.shellY,shellRadius,0,Math.PI*2);c.fill()
            }
            if(stage.impact){
                var ex=s.impactX,ey=s.impactY,age=stage.impactSeconds
                c.globalAlpha=Math.max(0,1-age*2);c.fillStyle="#fff2c2";c.beginPath();c.arc(ex,ey,10+age*80,0,Math.PI*2);c.fill()
                c.strokeStyle="#e4a259";c.lineWidth=4;c.beginPath();c.arc(ex,ey,14+age*120,0,Math.PI*2);c.stroke()
                for(var n=0;n<26;n++){var direction=n*2.39996,speed=35+(n%7)*16,dx=Math.cos(direction)*speed*age,dy=-Math.abs(Math.sin(direction))*speed*age+80*age*age
                    c.globalAlpha=Math.max(0,1-age*0.95);c.fillStyle=n%3?"#9f7e55":"#f4d38d";c.save();c.translate(ex+dx,ey+dy);c.rotate(n+age*4);c.fillRect(-3,-3,4+n%4,4+n%3);c.restore()}
                for(n=0;n<7;n++){c.globalAlpha=Math.max(0,0.42-age*0.38);c.fillStyle=n%2?"#d5c5a3":"#b5ad96";c.beginPath();c.arc(ex+(n-3)*(5+age*10),ey-age*35-(n%3)*5,8+age*18,0,Math.PI*2);c.fill()}c.globalAlpha=1
            }
            c.restore()
        }
    }
    Repeater {
        model:2
        Rectangle {
            required property int index
            x:12;y:12+index*60;width:160;height:52;radius:26;color:"#de203d36"
            border.width:game.canFire&&stage.sceneData.turn===index?2:0;border.color:index===0?"#8eddb4":"#f4aa89"
            AvatarPortrait {x:6;y:6;width:40;height:40;descriptor:index===(game.online?game.seat:0)?game.avatars.local:game.online?game.avatars.peer:({})}
            Text {objectName:"health"+index;x:52;y:7;text:(index===0?"MINT":"CORAL")+"  "+(index===0?stage.sceneData.hp0:stage.sceneData.hp1);font.pixelSize:16;font.bold:true;color:"#eff4e7"}
            Rectangle {x:52;y:34;width:94;height:6;radius:3;color:"#567269"
                Rectangle {width:parent.width*(index===0?stage.sceneData.hp0:stage.sceneData.hp1)/100;height:6;radius:3;color:index===0?"#8eddb4":"#f4aa89";Behavior on width {NumberAnimation {duration:260}}}
            }
        }
    }
    Rectangle {
        id:map;visible:game.canFire;width:Math.min(220,stage.width*0.32);height:68;anchors.horizontalCenter:parent.horizontalCenter;y:10;radius:10;color:"#eef8f4e8"
        Canvas {id:mini;x:8;y:6;width:parent.width-16;height:40
            onWidthChanged:requestPaint();onHeightChanged:requestPaint()
            onPaint:{var s=stage.sceneData;if(!s.terrain)return;var c=getContext("2d");c.reset();c.scale(width/960,height/180);c.translate(0,-200)
                c.fillStyle="#b4bf8b";c.beginPath();c.moveTo(0,400);for(var i=0;i<s.terrain.length;i++)c.lineTo(i*5,s.terrain[i]);c.lineTo(960,400);c.fill()
                c.strokeStyle="#779272";c.lineWidth=9;c.stroke()
                for(i=0;i<2;i++){c.fillStyle=i===0?"#3d8c67":"#bd6c58";c.fillRect((i===0?120:840)-20,(i===0?s.y0:s.y1)-35,40,35)}
                c.strokeStyle="#fefcef";c.lineWidth=6;c.strokeRect(Math.max(0,-stage.cameraX/stage.cameraScale),202,Math.min(960,stage.width/stage.cameraScale),170)
            }
        }
        Text {anchors.horizontalCenter:parent.horizontalCenter;y:47;text:(stage.overview?"Aim":"Whole field")+" · "+stage.overviewKey;font.pixelSize:12;font.bold:true;color:"#3e5e4c"}
        TapHandler {onTapped:stage.overviewRequested()}
    }
    Rectangle {
        id:aimPanel;objectName:"aimPanel";visible:stage.closeAim
        property real tankX:stage.screenX(stage.sceneData.turn===0?120:840)
        x:Math.max(12,Math.min(stage.width-width-12,tankX+(stage.sceneData.turn===0?78:-258)))
        y:Math.max(88,Math.min(stage.height-height-12,stage.screenY(stage.sceneData.turn===0?stage.tankY0:stage.tankY1)-158))
        width:180;height:100;radius:14;color:"#f2f8f4e8";border.color:"#c3d3b7"
        Text {x:14;y:9;text:"ANGLE";font.pixelSize:12;font.bold:true;color:"#66816a"}
        Text {objectName:"aimAngle";anchors.right:parent.right;anchors.rightMargin:14;y:5;text:game.angle+"°";font.pixelSize:27;font.bold:true;color:"#315947"}
        Text {x:14;y:46;text:"POWER";font.pixelSize:12;font.bold:true;color:"#66816a"}
        Text {anchors.right:parent.right;anchors.rightMargin:14;y:41;text:game.power;font.pixelSize:24;font.bold:true;color:"#315947"}
        Rectangle {x:14;y:79;width:152;height:8;radius:4;color:"#d8dfc8";Rectangle{width:parent.width*game.power/100;height:8;radius:4;color:"#d7a465";Behavior on width{NumberAnimation{duration:90}}}}
    }
    Rectangle {
        visible:stage.overview&&game.canFire
        anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:10
        width:overviewValues.width+28;height:32;radius:10;color:"#f2f8f4e8"
        Text {id:overviewValues;anchors.centerIn:parent;text:"ANGLE "+game.angle+"°     POWER "+game.power;font.pixelSize:14;font.bold:true;color:"#315947"}
    }
    Repeater {
        model:2
        Text {
            required property int index
            property int damage:index===0?stage.sceneData.damage0:stage.sceneData.damage1
            visible:stage.impact&&damage>0;objectName:"damage"+index
            x:Math.max(12,Math.min(stage.width-width-12,stage.screenX(index===0?120:840)-width/2))
            y:Math.max(84,stage.screenY((index===0?stage.tankY0:stage.tankY1)-62)-stage.impactSeconds*30)
            text:"−"+damage;font.pixelSize:30;font.bold:true;color:"#a84f3b";style:Text.Outline;styleColor:"#fff6de"
            opacity:Math.min(1,Math.max(0,(1.05-stage.impactSeconds)*3))
        }
    }
}
