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
            var colours=["#223e45","#7fc8cf","#eac76d","#bca2d6","#90c39b","#e09b88","#86a9d3","#dfb77e"]
            c.textAlign="center";c.font="bold 20px sans-serif"
            c.fillStyle="#416351";c.fillText("MINT  "+s.s0+" / 12",180,21)
            c.fillStyle="#996451";c.fillText("CORAL  "+s.s1+" / 12",540,21)
            c.font="15px sans-serif";c.fillStyle="#617567";c.fillText(Math.max(0,180-Math.floor(Math.max(0,s.tick-60)/30))+"s",360,22)
            for(var p=0;p<2;p++){
                var v=s.players[p],ox=p*360+60,oy=36,size=21
                c.fillStyle="#223e45";c.fillRect(ox-2,oy-2,214,340)
                function tile(index,colour,ghost){
                    var x=ox+(index%10)*size,y=oy+Math.floor(index/10)*size
                    if(ghost){c.strokeStyle=colour;c.lineWidth=1.5;c.strokeRect(x+3,y+3,size-6,size-6)}
                    else{c.fillStyle=colour;c.fillRect(x+1,y+1,size-2,size-2);c.fillStyle="rgba(255,255,255,0.2)";c.fillRect(x+3,y+3,size-6,3)}
                }
                for(var i=0;i<160;i++)if(v.cells[i])tile(i,colours[v.cells[i]],false)
                for(var g=0;g<4;g++)tile(v.ghost[g],"#b4c9b3",true)
                for(var a=0;a<4;a++)tile(v.active[a],colours[v.type+1],false)
                c.fillStyle="#627866";c.font="bold 14px sans-serif";c.fillText("NEXT",ox+251,56)
                var shapes=[[[0,1],[1,1],[2,1],[3,1]],[[1,0],[2,0],[1,1],[2,1]],[[1,0],[0,1],[1,1],[2,1]],[[1,0],[2,0],[0,1],[1,1]],[[0,0],[1,0],[1,1],[2,1]],[[0,0],[0,1],[1,1],[2,1]],[[2,0],[0,1],[1,1],[2,1]]]
                c.fillStyle=colours[v.next+1];for(var n=0;n<4;n++){var point=shapes[v.next][n];c.fillRect(ox+225+point[0]*13,70+point[1]*13,12,12)}
                c.fillStyle=p===0?"#416351":"#996451";c.font="15px sans-serif";c.fillText(v.lost?"STACK FULL":"CLEAR LINES TO RACE",ox+105,393)
            }
        }
    }
}
