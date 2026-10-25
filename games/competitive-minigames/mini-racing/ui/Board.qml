// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "../ui"
Item {
    id:board;property var sceneData: ({})
    property var previous: ({})
    onSceneDataChanged:{
        var s=sceneData,old=previous
        if(old.players&&s.tick>old.tick)for(var p=0;p<2;p++){var v=s.players[p],x=(p*480+20+(2.5+v.lane*4)*15)/960;if(v.crashes>old.players[p].crashes)fx.burst(x,0.79,"#34432c",28);if(v.boost>old.players[p].boost)fx.burst(x,0.88,"#34432c",18)}
        previous=s;canvas.requestPaint()
    }
    Canvas {
        id:canvas;objectName:"boardCanvas";anchors.centerIn:parent;width:960;height:480
        scale:Math.min(parent.width/width,parent.height/height)
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            var s=board.sceneData;if(!s.players)return
            var c=getContext("2d");c.reset();c.scale(width/960,height/480)
            c.fillStyle="#adb991";c.fillRect(0,0,960,480)
            c.textAlign="center";c.fillStyle="#34432c";c.font="bold 19px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\""
            c.fillText(Math.max(0,120-Math.floor(Math.max(0,s.tick-60)/30))+"s",480,25)
            var carCells=[[1,0],[0,1],[1,1],[2,1],[1,2],[0,3],[2,3]]
            for(var p=0;p<2;p++){
                var v=s.players[p],r=s.players[1-p],ox=p*480+20,oy=64,z=15
                function cell(x,y,style){
                    if(y<0||y>=26)return
                    var px=ox+x*z,py=oy+y*z;c.strokeStyle=style===0?"#94a27e":"#34432c";c.lineWidth=1
                    c.strokeRect(px+1,py+1,z-2,z-2)
                    if(style===1){c.fillStyle="#34432c";c.fillRect(px+3,py+3,z-6,z-6)}
                }
                for(var y=0;y<26;y++)for(var x=0;x<22;x++)cell(x,y,0)
                for(var e=0;e<26;e++)if((e+Math.floor(v.distance/6))%4<2){cell(0,e,1);cell(21,e,1)}
                function car(lane,row,style,label){
                    for(var n=0;n<carCells.length;n++)cell(1+lane*4+carCells[n][0],row+carCells[n][1],style)
                    if(label&&row>1&&row<26){c.font="bold 19px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillStyle="#34432c";c.fillText(label,ox+(2.5+lane*4)*z,oy+(row-0.2)*z)}
                }
                for(var g=0;g<s.course.length;g++){
                    var row=20-Math.round((120+g*90-v.distance)/6)
                    if(row<-3||row>25)continue
                    for(var lane=0;lane<5;lane++)if(s.course[g]&(1<<lane))car(lane,row,2,"")
                }
                // The second car is the same opponent on the shared course, not a ghost replay.
                if(!r.passable||s.tick%6<3)car(r.lane,20-Math.round((r.distance-v.distance)/6),p===0?2:1,"P"+(2-p))
                if(!v.passable||s.tick%6<3)car(v.lane,20,p===0?1:2,"P"+(p+1))
                c.fillStyle="#34432c";c.font="bold 19px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillText("P"+(p+1)+(p===0?" MINT":" CORAL"),ox+165,23)
                c.font="19px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillText(Math.min(2000,v.distance)+" / 2000",ox+165,43)
                c.textAlign="center";c.font="bold 22px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillText("BOOST",ox+397,190)
                c.font="bold 30px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillText(v.boost?"ON":"OFF",ox+397,225)
                c.font="18px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillText("UNLIMITED",ox+397,252)
                c.font="bold 22px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\"";c.fillText("LIVES",ox+397,310)
                for(var life=0;life<3;life++){c.strokeRect(ox+360+life*28,328,21,21);if(life<v.lives)c.fillRect(ox+364+life*28,332,13,13)}
                c.textAlign="center";c.font="bold 19px \""+(Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono")+"\""
                c.fillText(v.crash?"RECOVERING":v.boost?"BOOST!":"PASS YOUR RIVAL",ox+165,477)
            }
        }
    }
    ImpactFx { id:fx;brick:true;anchors.centerIn:parent;width:canvas.width;height:canvas.height;scale:canvas.scale }
}
