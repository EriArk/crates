// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "../ui"
Item {
    id:board;property var sceneData: ({})
    property var previous: ({})
    onSceneDataChanged:{
        var s=sceneData,old=previous
        if(old.tick!==undefined&&s.tick>old.tick){for(var p=0;p<2;p++){var head=p===0?s.a[0]:s.b[0];if((p===0?s.s0:s.s1)!==(p===0?old.s0:old.s1))fx.burst((head%24+0.5)/24,(Math.floor(head/24)+0.5)/17,"#efb55c",20)}if(s.winner>=0&&old.winner<0){fx.burst((s.a[0]%24+0.5)/24,(Math.floor(s.a[0]/24)+0.5)/17,"#83deb2",28);fx.burst((s.b[0]%24+0.5)/24,(Math.floor(s.b[0]/24)+0.5)/17,"#f5ac94",28)}}
        previous=s;canvas.requestPaint()
    }
    Canvas {
        id:canvas;objectName:"boardCanvas";anchors.centerIn:parent;width:600;height:425
        scale:Math.min(parent.width/width,parent.height/height)
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            if(board.sceneData.tick===undefined)return
            var s=board.sceneData,c=getContext("2d");c.reset();c.scale(width/600,height/425)
            c.fillStyle="#edf0d8";c.fillRect(0,0,600,425)
            c.fillStyle="#dde6c7";for(var y=0;y<16;y++)for(var x=0;x<24;x++)if((x+y)%2===0)c.fillRect(x*25,y*25,25,25)
            if(s.food>=0){var fx=(s.food%24)*25+12.5,fy=Math.floor(s.food/24)*25+12.5;c.fillStyle="#dc9264";c.beginPath();c.arc(fx,fy,8,0,Math.PI*2);c.fill();c.strokeStyle="#66864e";c.lineWidth=3;c.beginPath();c.moveTo(fx,fy-6);c.lineTo(fx+3,fy-12);c.stroke()}
            for(var p=0;p<2;p++){
                var snake=p===0?s.a:s.b
                for(var i=snake.length-1;i>=0;i--){var sx=(snake[i]%24)*25,sy=Math.floor(snake[i]/24)*25;c.fillStyle=p===0?(i===0?"#34745b":"#72b68b"):(i===0?"#ab6350":"#e0a182");c.fillRect(sx+2,sy+2,21,21)}
                var h=snake[0],hx=(h%24)*25+12.5,hy=Math.floor(h/24)*25+12.5,d=p===0?s.d0:s.d1
                c.fillStyle="#fff8dc"
                for(var e=-1;e<=1;e+=2){c.beginPath();c.arc(hx+(d===1?6:d===3?-6:e*4),hy+(d===0?-6:d===2?6:e*4),2.5,0,Math.PI*2);c.fill()}
            }
            c.font="bold 19px \""+Qt.application.font.family+"\"";c.fillStyle="#3b654f";c.textAlign="left";c.fillText("MINT  "+s.s0+" FRUIT",34,420);c.textAlign="right";c.fillStyle="#9b6652";c.fillText("CORAL  "+s.s1+" FRUIT",566,420)
            c.textAlign="center";c.fillStyle="#6d7f57";c.fillText(Math.max(0,120-Math.floor(s.tick/30))+"s",300,420)
        }
    }
    ImpactFx { id:fx;anchors.centerIn:parent;width:canvas.width;height:canvas.height;scale:canvas.scale }
}
