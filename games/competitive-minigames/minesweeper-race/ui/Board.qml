// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "../ui"
Item {
    id:board;property var sceneData: ({})
    property var previous: ({})
    onSceneDataChanged:{
        var s=sceneData,old=previous
        if(old.players&&s.tick>old.tick)for(var p=0;p<2;p++){var v=s.players[p],at=v.cursor;if(v.lost&&!old.players[p].lost)fx.burst((p*380+28+(at%9+0.5)*36)/760,(40+(Math.floor(at/9)+0.5)*36)/400,"#da745c",32);else if((p===0?s.s0:s.s1)>(p===0?old.s0:old.s1))fx.burst((p*380+28+(at%9+0.5)*36)/760,(40+(Math.floor(at/9)+0.5)*36)/400,"#8cbfab",12)}
        previous=s;canvas.requestPaint()
    }
    Canvas {
        id:canvas;objectName:"boardCanvas";anchors.centerIn:parent;width:760;height:400
        scale:Math.min(parent.width/width,parent.height/height)
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            var s=board.sceneData;if(!s.players)return
            var c=getContext("2d");c.reset();c.scale(width/760,height/400);c.textAlign="center"
            c.font="bold 20px \""+Qt.application.font.family+"\"";c.fillStyle="#416351";c.fillText("MINT  "+s.s0+" / 69",190,23);c.fillStyle="#996451";c.fillText("CORAL  "+s.s1+" / 69",570,23)
            c.font="19px \""+Qt.application.font.family+"\"";c.fillStyle="#617567";c.fillText(Math.max(0,180-Math.floor(Math.max(0,s.tick-60)/30))+"s",380,23)
            var inks=["#567760","#4f83a0","#4b8a65","#b76d57","#8564a2","#a26768","#498f8b","#695e54","#474d49"]
            for(var p=0;p<2;p++){
                var v=s.players[p],ox=p*380+28,oy=40,size=36
                for(var i=0;i<81;i++){
                    var value=v.cells[i],x=ox+i%9*size,y=oy+Math.floor(i/9)*size
                    c.fillStyle=value<0?(p===0?"#a8c7ad":"#dfb8a3"):"#f4f1df";c.fillRect(x+1,y+1,34,34)
                    if(value===-1){c.fillStyle="rgba(255,255,255,0.25)";c.fillRect(x+3,y+3,30,3)}
                    if(value>0){c.fillStyle=inks[value];c.font="bold 21px \""+Qt.application.font.family+"\"";c.fillText(value,x+18,y+25)}
                    if(value===-2){c.strokeStyle="#4b6255";c.lineWidth=2;c.beginPath();c.moveTo(x+13,y+28);c.lineTo(x+13,y+8);c.stroke();c.fillStyle="#b66e52";c.beginPath();c.moveTo(x+14,y+8);c.lineTo(x+27,y+13);c.lineTo(x+14,y+18);c.fill()}
                    if(value===-3){c.fillStyle="#a9554c";c.beginPath();c.arc(x+18,y+18,9,0,Math.PI*2);c.fill();c.strokeStyle="#f8e4d4";c.lineWidth=2;c.beginPath();c.moveTo(x+14,y+14);c.lineTo(x+22,y+22);c.moveTo(x+22,y+14);c.lineTo(x+14,y+22);c.stroke()}
                }
                var at=v.cursor;c.strokeStyle="#273f39";c.lineWidth=3;c.strokeRect(ox+at%9*size+2,oy+Math.floor(at/9)*size+2,32,32)
                c.fillStyle=p===0?"#416351":"#996451";c.font="19px \""+Qt.application.font.family+"\"";c.fillText(v.lost?"MINE HIT":"FLAGS  "+v.flags+" / 12",ox+162,388)
            }
        }
    }
    ImpactFx { id:fx;anchors.centerIn:parent;width:canvas.width;height:canvas.height;scale:canvas.scale }
}
