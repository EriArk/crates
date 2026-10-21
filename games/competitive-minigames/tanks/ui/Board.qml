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
            c.fillStyle="#adb991";c.fillRect(0,0,720,400);c.fillStyle="#34432c";c.textAlign="center"
            c.font="bold 19px monospace";c.fillText("BRICK TANKS",360,24)
            c.font="14px monospace";c.fillText(Math.max(0,120-Math.floor(Math.max(0,s.tick-60)/30))+"s",360,47)
            var ox=135,oy=53,z=18
            function cell(x,y,style){
                var px=ox+x*z,py=oy+y*z;c.lineWidth=1;c.strokeStyle=style===0?"#94a27e":"#34432c";c.strokeRect(px+1,py+1,z-2,z-2)
                if(style===1){c.fillStyle="#34432c";c.fillRect(px+3,py+3,z-6,z-6)}
            }
            for(var y=0;y<19;y++)for(var x=0;x<25;x++){
                var value=s.cells[y*25+x];cell(x,y,value?2:0)
                if(value===1){c.strokeStyle="#34432c";c.beginPath();c.moveTo(ox+x*z+2,oy+y*z+9);c.lineTo(ox+x*z+16,oy+y*z+9);c.moveTo(ox+x*z+9,oy+y*z+2);c.lineTo(ox+x*z+9,oy+y*z+9);c.stroke()}
                if(value===2){c.fillStyle="#34432c";c.fillRect(ox+x*z+4,oy+y*z+4,10,10)}
            }
            for(var p=0;p<2;p++){
                var v=s.players[p],shape=[[-1,-1],[-1,0],[-1,1],[1,-1],[1,0],[1,1],[0,-1],[0,0]]
                for(var i=0;i<shape.length;i++){
                    var dx=shape[i][0],dy=shape[i][1]
                    for(var r=0;r<v.face;r++){var old=dx;dx=-dy;dy=old}
                    cell(v.x+dx,v.y+dy,p===0?1:2)
                }
                c.strokeStyle="#34432c";c.lineWidth=2
                if(v.shield&&s.tick%8<4)c.strokeRect(ox+(v.x-1)*z-2,oy+(v.y-1)*z-2,z*3+4,z*3+4)
                var hx=p===0?65:655;c.fillStyle="#34432c";c.font="bold 20px monospace";c.fillText("P"+(p+1),hx,90)
                c.font="14px monospace";c.fillText(p===0?"MINT":"CORAL",hx,112);c.font="bold 24px monospace";c.fillText((p===0?s.s0:s.s1)+" / 3",hx,155)
                c.font="12px monospace";c.fillText(v.shield?"SHIELD":v.cooldown?"RELOAD":"READY",hx,191)
                // A fixed silhouette key distinguishes players on the monochrome screen.
                c.strokeStyle="#34432c";c.lineWidth=2;c.strokeRect(hx-14,212,28,28);if(p===0)c.fillRect(hx-9,217,18,18)
                c.font="11px monospace";c.fillText(p===0?"SOLID":"OUTLINE",hx,263)
            }
            for(var b=0;b<s.bullets.length;b++){var shot=s.bullets[b];c.fillStyle="#34432c";c.fillRect(ox+shot.x*z+6,oy+shot.y*z+6,6,6)}
        }
    }
}
