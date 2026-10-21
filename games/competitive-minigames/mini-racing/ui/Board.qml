// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Item {
    id:board;property var sceneData: ({})
    onSceneDataChanged:canvas.requestPaint()
    Canvas {
        id:canvas;anchors.centerIn:parent;width:Math.min(parent.width,parent.height*1.8);height:width/1.8
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            var s=board.sceneData;if(!s.players)return
            var c=getContext("2d");c.reset();c.scale(width/720,height/400)
            c.fillStyle="#adb991";c.fillRect(0,0,720,400)
            c.textAlign="center";c.fillStyle="#34432c";c.font="bold 19px monospace"
            c.fillText("BRICK RACING",360,24);c.font="14px monospace";c.fillText(Math.max(0,120-Math.floor(Math.max(0,s.tick-60)/30))+"s",360,45)
            var carCells=[[1,0],[0,1],[1,1],[2,1],[1,2],[0,3],[2,3]]
            for(var p=0;p<2;p++){
                var v=s.players[p],r=s.players[1-p],ox=p*360+84,oy=55,z=11
                function cell(x,y,style){
                    if(y<0||y>=28)return
                    var px=ox+x*z,py=oy+y*z;c.strokeStyle=style===0?"#94a27e":"#34432c";c.lineWidth=1
                    c.strokeRect(px+1,py+1,z-2,z-2)
                    if(style===1){c.fillStyle="#34432c";c.fillRect(px+3,py+3,z-6,z-6)}
                }
                for(var y=0;y<28;y++)for(var x=0;x<14;x++)cell(x,y,0)
                for(var e=0;e<28;e++)if((e+Math.floor(v.distance/6))%4<2){cell(0,e,1);cell(13,e,1)}
                function car(lane,row,style,label){
                    for(var n=0;n<carCells.length;n++)cell(1+lane*4+carCells[n][0],row+carCells[n][1],style)
                    if(label&&row>1&&row<28){c.font="bold 10px monospace";c.fillStyle="#34432c";c.fillText(label,ox+(2.5+lane*4)*z,oy+(row-0.2)*z)}
                }
                for(var g=0;g<s.course.length;g++){
                    var row=22-Math.round((120+g*90-v.distance)/6)
                    if(row<-3||row>27)continue
                    for(var lane=0;lane<3;lane++)if(s.course[g]&(1<<lane))car(lane,row,2,"")
                }
                // The second car is the same opponent on the shared course, not a ghost replay.
                if(!r.passable||s.tick%6<3)car(r.lane,22-Math.round((r.distance-v.distance)/6),p===0?2:1,"P"+(2-p))
                if(!v.passable||s.tick%6<3)car(v.lane,22,p===0?1:2,"P"+(p+1))
                c.fillStyle="#34432c";c.font="bold 18px monospace";c.fillText("P"+(p+1)+(p===0?" MINT":" CORAL"),ox+77,23)
                c.font="14px monospace";c.fillText(Math.min(2000,v.distance)+" / 2000",ox+77,43)
                c.textAlign="left";c.font="bold 12px monospace";c.fillText("BOOST",ox+166,280)
                c.strokeStyle="#34432c";c.strokeRect(ox+166,287,65,12);c.fillRect(ox+169,290,59*(1-v.cooldown/210),6)
                c.font="12px monospace";c.fillText("HITS "+v.crashes,ox+166,323)
                c.textAlign="center";c.font="bold 14px monospace"
                c.fillText(v.crash?"RECOVERING":v.boost?"BOOST!":v.draft?"SLIPSTREAM":"PASS YOUR RIVAL",ox+77,387)
            }
        }
    }
}
