// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "../ui"
Item {
    id:board
    objectName:"tanksBoard"
    property var sceneData: ({})
    readonly property int views:game.couch?2:1
    readonly property int localSeat:game.online?game.seat:0
    property var previous: ({})
    function camera(p) {
        var t=sceneData.players[p],w=960/views,z=24
        return {x:Math.max(0,Math.min(sceneData.width-w/z,t.x+0.5-w/z/2)),y:Math.max(0,Math.min(sceneData.height-540/z,t.y+0.5-540/z/2))}
    }
    function burstAt(x,y,count) {
        for(var pane=0;pane<views;pane++){
            var cam=camera(game.couch?pane:localSeat),sx=(x+0.5-cam.x)*24,sy=(y+0.5-cam.y)*24
            if(sx>0&&sx<960/views&&sy>0&&sy<540)fx.burst((pane*960/views+sx)/960,sy/540,"#34432c",count)
        }
    }
    onSceneDataChanged:{
        var s=sceneData,old=previous
        if(old.players&&s.players&&s.tick>old.tick){
            for(var p=0;p<s.players.length;p++){var v=s.players[p],before=old.players[p];if(!before)continue;if(v.cooldown>before.cooldown)burstAt(v.x,v.y,7);if(v.shield>before.shield)burstAt(before.x,before.y,24)}
            for(var i=0;i<s.cells.length;i++)if(old.cells[i]===1&&s.cells[i]===0)burstAt(i%s.width,Math.floor(i/s.width),10)
        }
        previous=s;canvas.requestPaint()
    }
    Canvas {
        id:canvas;objectName:"boardCanvas";anchors.centerIn:parent;width:960;height:540
        scale:Math.min(parent.width/width,parent.height/height)
        onPaint:{
            var s=board.sceneData;if(!s.players)return
            var c=getContext("2d");c.reset();c.fillStyle="#adb991";c.fillRect(0,0,width,height)
            var z=24,w=960/board.views,face=Qt.platform.os==="windows"?"Consolas":"DejaVu Sans Mono"
            for(var pane=0;pane<board.views;pane++){
                var own=game.couch?pane:board.localSeat,cam=board.camera(own),ox=pane*w-cam.x*z,oy=-cam.y*z
                c.save();c.beginPath();c.rect(pane*w,0,w,540);c.clip()
                function cell(x,y,style){var px=ox+x*z,py=oy+y*z;c.lineWidth=1;c.strokeStyle=style===0?"#94a27e":"#34432c";c.strokeRect(px+1,py+1,z-2,z-2);if(style===1){c.fillStyle="#34432c";c.fillRect(px+4,py+4,z-8,z-8)}}
                for(var y=Math.floor(cam.y);y<Math.min(s.height,Math.ceil(cam.y+540/z));y++)for(var x=Math.floor(cam.x);x<Math.min(s.width,Math.ceil(cam.x+w/z));x++){
                    var tile=s.cells[y*s.width+x],px=ox+x*z,py=oy+y*z
                    cell(x,y,tile===1||tile===2?2:0);c.strokeStyle="#34432c";c.fillStyle="#34432c"
                    if(tile===1){c.beginPath();c.moveTo(px+2,py+12);c.lineTo(px+22,py+12);c.moveTo(px+12,py+2);c.lineTo(px+12,py+12);c.stroke()}
                    if(tile===2){c.fillRect(px+4,py+4,16,16);c.clearRect(px+10,py+10,4,4)}
                    if(tile===3){c.beginPath();for(var wave=6;wave<=18;wave+=6){c.moveTo(px+3,py+wave);c.lineTo(px+9,py+wave+2);c.lineTo(px+15,py+wave);c.lineTo(px+21,py+wave+2)}c.stroke()}
                    if(tile===4){for(var leaf=0;leaf<5;leaf++)c.fillRect(px+4+(leaf*7)%16,py+4+(leaf*11)%16,4,4)}
                }
                for(var p=0;p<s.players.length;p++){
                    var v=s.players[p];if(v.x<cam.x-2||v.x>cam.x+w/z+2||v.y<cam.y-2||v.y>cam.y+540/z+2)continue
                    // Only the centre muzzle projects beyond the two tracks.
                    var shape=[[0,-1],[-1,0],[0,0],[1,0],[-1,1],[1,1]]
                    for(var n=0;n<shape.length;n++){var dx=shape[n][0],dy=shape[n][1];for(var r=0;r<v.face;r++){var old=dx;dx=-dy;dy=old}cell(v.x+dx,v.y+dy,p===own?1:2)}
                    c.strokeStyle="#34432c";c.lineWidth=2
                    if(v.shield&&s.tick%8<4)c.strokeRect(ox+(v.x-1)*z-2,oy+(v.y-1)*z-2,z*3+4,z*3+4)
                    c.font="bold 16px \""+face+"\"";c.textAlign="center";c.fillStyle="#34432c";c.fillText(p===own?"YOU":"P"+(p+1),ox+(v.x+0.5)*z,oy+(v.y-1)*z-8)
                }
                for(var b=0;b<s.bullets.length;b++){var shot=s.bullets[b];c.fillStyle="#34432c";c.fillRect(ox+shot[0]*z+8,oy+shot[1]*z+8,8,8)}
                // An isolated score stamp; the world continues behind every HUD item.
                c.fillStyle="#bac69d";c.fillRect(pane*w+12,12,196,50);c.strokeStyle="#34432c";c.strokeRect(pane*w+12,12,196,50)
                c.fillStyle="#34432c";c.textAlign="left";c.font="bold 18px \""+face+"\"";c.fillText("P"+(own+1)+"  "+s.players[own].score+" / 3",pane*w+62,34)
                c.font="14px \""+face+"\"";c.fillText(s.players[own].shield?"SHIELD":s.players[own].cooldown?"RELOAD":"READY",pane*w+62,53)
                c.restore()
            }
            if(board.views===2){c.fillStyle="#34432c";c.fillRect(478,0,4,540)}
            c.fillStyle="#bac69d";c.fillRect(442,498,76,30);c.fillStyle="#34432c";c.font="bold 18px \""+face+"\"";c.textAlign="center";c.fillText(Math.max(0,120-Math.floor(Math.max(0,s.tick-60)/30))+"s",480,519)
        }
    }
    Repeater {
        model:board.views
        AvatarPortrait {
            required property int index
            property int owner:game.couch?index:board.localSeat
            x:(parent.width-canvas.width*canvas.scale)/2+(index*960/board.views+18)*canvas.scale
            y:(parent.height-canvas.height*canvas.scale)/2+18*canvas.scale
            width:36*canvas.scale;height:width;brickStyle:true
            descriptor:owner===(game.online?game.seat:0)?game.avatars.local:game.online?game.avatars.peer:({})
        }
    }
    ImpactFx {id:fx;brick:true;anchors.centerIn:parent;width:canvas.width;height:canvas.height;scale:canvas.scale}
}
