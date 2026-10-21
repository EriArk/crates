// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
Item {
    id:board;property var sceneData: ({})
    onSceneDataChanged:canvas.requestPaint()
    Canvas {
        id:canvas;anchors.centerIn:parent;width:Math.min(parent.width,parent.height*28/19);height:width*19/28
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            if(board.sceneData.tick===undefined)return
            var s=board.sceneData,c=getContext("2d");c.reset();c.scale(width/700,height/475)
            c.fillStyle="#172e37";c.fillRect(0,0,700,475)
            c.strokeStyle="#28444b";c.lineWidth=1
            for(var x=0;x<=700;x+=25){c.beginPath();c.moveTo(x,0);c.lineTo(x,450);c.stroke()}
            for(var y=0;y<=450;y+=25){c.beginPath();c.moveTo(0,y);c.lineTo(700,y);c.stroke()}
            for(var i=0;i<s.cells.length;i++)if(s.cells[i]){c.fillStyle=s.cells[i]===1?"#70cda6":"#e8a188";c.fillRect((i%28)*25+4,Math.floor(i/28)*25+4,17,17)}
            for(var p=0;p<2;p++){
                var h=p===0?s.h0:s.h1,hx=(h%28)*25+12.5,hy=Math.floor(h/28)*25+12.5,d=p===0?s.d0:s.d1
                c.save();c.translate(hx,hy);c.rotate(d*Math.PI/2);c.fillStyle="#fff4ce";c.beginPath();c.moveTo(0,-10);c.lineTo(8,7);c.lineTo(-8,7);c.closePath();c.fill();c.restore()
            }
            c.font="bold 19px sans-serif";c.fillStyle="#91debb";c.textAlign="left";c.fillText("MINT  "+s.s0+" TILES",8,471);c.textAlign="right";c.fillStyle="#f1bca5";c.fillText("CORAL  "+s.s1+" TILES",692,471)
            c.textAlign="center";c.fillStyle="#c2d5c9";c.fillText("LAST RIDER WINS",350,471)
        }
    }
}
