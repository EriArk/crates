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
            var c=getContext("2d");c.reset();c.scale(width/720,height/400);c.textAlign="center"
            c.font="bold 20px sans-serif";c.fillStyle="#416351";c.fillText("MINT  "+s.s0+" / 600",180,23);c.fillStyle="#996451";c.fillText("CORAL  "+s.s1+" / 600",540,23)
            c.font="15px sans-serif";c.fillStyle="#617567";c.fillText(Math.max(0,180-Math.floor(Math.max(0,s.tick-60)/30))+"s",360,23)
            var colours=["#263f45","#80bfa3","#e6b16c","#a9a1d1","#df968a","#89918a"]
            for(var p=0;p<2;p++){
                var v=s.players[p],ox=p*360+87,oy=36,size=27
                c.fillStyle="#263f45";c.fillRect(ox-3,oy-3,168,330)
                for(var i=0;i<72;i++)if(v.cells[i]){
                    var val=v.cells[i],x=ox+i%6*size,y=oy+Math.floor(i/6)*size
                    c.fillStyle=v.flash.indexOf(i)>=0?"#fff1bb":colours[val];c.fillRect(x+1,y+1,25,25)
                    // A distinct mark for each colour also makes matches legible without colour.
                    c.strokeStyle="#364f4d";c.fillStyle="#364f4d";c.lineWidth=2;c.beginPath()
                    if(val===1){c.arc(x+13.5,y+13.5,5,0,Math.PI*2);c.stroke()}
                    if(val===2){c.moveTo(x+13,y+7);c.lineTo(x+20,y+19);c.lineTo(x+7,y+19);c.closePath();c.stroke()}
                    if(val===3)c.strokeRect(x+9,y+9,9,9)
                    if(val===4){c.moveTo(x+13,y+6);c.lineTo(x+21,y+13);c.lineTo(x+13,y+21);c.lineTo(x+6,y+13);c.closePath();c.stroke()}
                    if(val===5){c.moveTo(x+8,y+8);c.lineTo(x+19,y+19);c.moveTo(x+19,y+8);c.lineTo(x+8,y+19);c.stroke()}
                }
                c.strokeStyle="#fff5cc";c.lineWidth=3;c.strokeRect(ox+v.cursor%6*size,oy+Math.floor(v.cursor/6)*size,54,27)
                c.fillStyle="#a4b99b";c.fillRect(ox,368,162,4);c.fillStyle="#567f69";c.fillRect(ox,368,162*v.raise/240,4)
                c.fillStyle=p===0?"#416351":"#996451";c.font="bold 14px sans-serif";c.fillText(v.lost?"STACK FULL":v.chain>0?"CHAIN ×"+v.chain:"SWAP · MATCH · CASCADE",ox+81,391)
                if(v.incoming){c.fillStyle="#9f6654";c.fillText("+"+v.incoming,ox+196,80);c.font="13px sans-serif";c.fillText("ROWS",ox+196,94)}
            }
        }
    }
}
