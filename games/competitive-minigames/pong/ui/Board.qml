// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "../ui"
Item {
    id:board
    property var sceneData: ({})
    property var tail: []
    property real ballX: sceneData.x === undefined?480:sceneData.x
    property real ballY: sceneData.y === undefined?270:sceneData.y
    Behavior on ballX {NumberAnimation {duration:game.online?60:30}}
    Behavior on ballY {NumberAnimation {duration:game.online?60:30}}
    property real dx:0
    property real dy:0
    property var previous: ({})
    onSceneDataChanged:{
        var s=sceneData,old=previous
        if(old.tick!==undefined && s.tick>old.tick) {
    if(s.s0!==old.s0||s.s1!==old.s1)fx.burst(s.s0!==old.s0?0.92:0.08,0.5,"#fff4ca",36)
    else if(((s.x-old.x)*dx<0||(s.y-old.y)*dy<0)&&s.serve===0)fx.burst(s.x/960,s.y/540,"#fff4ca",12)
}
        dx=s.x-old.x;dy=s.y-old.y;previous=s;canvas.requestPaint()
    }
    onBallXChanged:{var t=tail.slice(-9);t.push({x:ballX,y:ballY});tail=t;canvas.requestPaint()}
    onBallYChanged:canvas.requestPaint()
    Canvas {
        id:canvas;anchors.centerIn:parent;width:Math.min(parent.width,parent.height*960/540);height:width*540/960
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            if(board.sceneData.tick===undefined)return
            var s=board.sceneData,c=getContext("2d");c.reset();c.scale(width/960,height/540)
            c.fillStyle="#315f52";c.fillRect(0,0,960,540)
            c.strokeStyle="#6d9180";c.lineWidth=2;c.strokeRect(18,18,924,504)
            c.fillStyle="#749c87";for(var y=28;y<520;y+=34)c.fillRect(478,y,4,18)
            c.fillStyle="#a7e2bd";c.fillRect(26,s.p0-49,14,98)
            c.fillStyle="#f3b899";c.fillRect(920,s.p1-49,14,98)
            for(var t=0;t<board.tail.length;t++){c.globalAlpha=t/board.tail.length*0.3;c.fillStyle="#fff4d2";c.beginPath();c.arc(board.tail[t].x,board.tail[t].y,4+t/2,0,Math.PI*2);c.fill()}c.globalAlpha=1;
            c.shadowColor="#fff4d2";c.shadowBlur=16;c.fillStyle="#fff4d2";c.beginPath();c.arc(board.ballX,board.ballY,9,0,Math.PI*2);c.fill()
            c.shadowBlur=0;c.shadowColor="transparent";c.textAlign="center";c.font="bold 48px \""+Qt.application.font.family+"\"";c.fillStyle="#a7e2bd";c.fillText(s.s0,390,85);c.fillStyle="#f3b899";c.fillText(s.s1,570,85)
            c.font="22px \""+Qt.application.font.family+"\"";c.fillStyle="#c7dcc8";c.fillText("FIRST TO FIVE",480,508)
            if(s.serve>0&&s.tick>=60){c.font="bold 24px \""+Qt.application.font.family+"\"";c.fillText("SERVE",480,340)}
        }
    }
    ImpactFx { id:fx;anchors.fill:canvas }
}
